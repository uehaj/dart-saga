import "dart:async";
import "dart:isolate";
import './effect.dart';

typedef Iterable<Effect> Saga(param);

class _SagaContext {
  ReceivePort receiveFromChild;
  SendPort sendToChildPort;

  _SagaContext() {
    this.receiveFromChild = new ReceivePort();
  }

  Future<Isolate> _spawnSaga(Saga saga, [param]) async {
    ReceivePort rp = new ReceivePort();
    rp.listen((x) {
      print("x = ${x}");
    });
    Isolate isolate = await Isolate.spawn(
        _SagaContext._isolateHandler,
        {
          'saga': saga,
          'sendToParentPort': receiveFromChild.sendPort,
          'param': param,
        },
        paused: false,
        onExit: rp.sendPort);
    return isolate;
  }

  // running on parent isolate
  Future<StreamIterator> startSaga(Saga saga, [param]) async {
    this._spawnSaga(saga, param);
    StreamIterator itr = new StreamIterator(receiveFromChild);
    if (await itr.moveNext()) {
      this.sendToChildPort = itr.current;
    }
    return itr;
  }

  // running on child isolate
  static Future<void> _isolateHandler(params) async {
    Saga saga = params['saga'];
    SendPort sendToParentPort = params['sendToParentPort'];
    Object param = params['param'];

    ReceivePort receiveFromParentPort = new ReceivePort();
    StreamIterator receiveFromParent =
        new StreamIterator(receiveFromParentPort);

    // send sendPort to parent isolate for bi-directional communication.
    sendToParentPort.send(receiveFromParentPort.sendPort);

    for (var current in saga(param)) {
      if (current is PutEffect ||
          current is TakeEffect ||
          current is TakeEveryEffect ||
          current is ForkEffect) {
        sendToParentPort.send(current);
        // TODO: if an action is sent between here, it might be lost.
        if (current is TakeEffect) {
          if (await receiveFromParent.moveNext()) {
            var takenAction = receiveFromParent.current;
            print(takenAction);
          }
        }
      } else if (current is CallableEffect) {
        await current.call();
      }
    }
  }
}

class EffectManager {
  Map<String, List<_SagaContext>> waitingActions = new Map();

  EffectManager() {
    print("start isolate context");
  }

  // running on main isolate
  Future startSaga(Saga saga, [param]) async {
    _SagaContext sc = new _SagaContext();
    StreamIterator itr = await sc.startSaga(saga, param);
    while (await itr.moveNext()) {
      Effect effect = itr.current;
      if (effect is PutEffect) {
        if (waitingActions[effect.action.type] != null) {
          for (var waitingSaga in waitingActions[effect.action.type]) {
            waitingSaga.sendToChildPort.send(effect.action);
          }
          waitingActions.remove(effect.action.type);
        }
      } else if (effect is TakeEffect) {
        if (waitingActions[effect.action.type] == null) {
          waitingActions[effect.action.type] = [sc];
        } else {
          waitingActions[effect.action.type].add(sc);
        }
      } else if (effect is TakeEveryEffect) {} else if (effect is ForkEffect) {
        this.startSaga(effect.saga, effect.param);
      }
    }
  }
}
