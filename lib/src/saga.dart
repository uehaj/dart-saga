import "dart:async";
import "dart:isolate";
import './effect.dart';

class _EffectDispatcher {
  Map<String, List<_Task>> _waitingTasks;

  _Task _task;

  // running on parent isolate
  _EffectDispatcher(Saga saga, param, [waitingTasks]) {
    if (waitingTasks != null) {
      this._waitingTasks = waitingTasks;
    } else {
      this._waitingTasks = {};
    }

    // running on parent isolate
    this._task = new _Task(saga, param)..start().then(this._handleEvent);
  }

  void _handleEvent(StreamIterator itr) async {
    // effects which yielded from the saga (child isolate)
    while (await itr.moveNext()) {
      Effect effect = itr.current;

      if (effect is PutEffect) {
        this._put(effect);
      } else if (effect is TakeEffect) {
        this._take(effect, this._task);
      } else if (effect is TakeEveryEffect) {
        /**/
      } else if (effect is ForkEffect) {
        _EffectDispatcher tmp = new _EffectDispatcher(
            effect.saga, effect.param, this._waitingTasks);
        this._task.send(tmp._task.taskId);
      } else if (effect is CancelEffect) {
        _Task._taskMap[effect.taskId]?.cancel();
      }
    }
  }

  // running on parent isolate
  void _put(PutEffect effect) {
    if (_waitingTasks[effect.action.type] != null) {
      for (var waitingSaga in _waitingTasks[effect.action.type]) {
        waitingSaga.send(effect.action);
      }
      _waitingTasks.remove(effect.action.type);
    }
  }

  // running on parent isolate
  void _take(TakeEffect effect, _Task task) {
    if (_waitingTasks[effect.action.type] == null) {
      _waitingTasks[effect.action.type] = [task];
    } else {
      _waitingTasks[effect.action.type].add(task);
    }
  }
}

class _Task {
  static int _taskIdSeed = 0;

  int taskId;

  static Map<int, _Task> _taskMap = {};

  Isolate _isolate;

  List<_Task> _childTasks = [];

  Map<String, Object> _isolateInvokeMessage;

  SendPort _sendToChildPort;

  void send(msg) {
    this._sendToChildPort.send(msg);
  }

  // still running on parent isolate
  _Task(Saga saga, [Object param]) {
    this.taskId = _Task._taskIdSeed++;
    _Task._taskMap[this.taskId] = this;

    this._isolateInvokeMessage = {
      'saga': saga,
      'param': param,
    };
  }

  // still running on parent isolate
  Future<StreamIterator> start() async {
    ReceivePort onExitPort = new ReceivePort();
    onExitPort.listen((x) {
      print("onExitCheck: ${x}");
    });

    ReceivePort fromChild = new ReceivePort();
    _isolateInvokeMessage['sendToParentPort'] = fromChild.sendPort;
    this._isolate = await Isolate.spawn(
        _Task._isolateHandler, this._isolateInvokeMessage,
        paused: false, onExit: onExitPort.sendPort)
      ..errors.listen((error) {
        print(error);
      });
    StreamIterator itr = new StreamIterator(fromChild);
    if (await itr.moveNext()) {
      this._sendToChildPort = itr.current;
    } else {
      throw new Exception("Illegal stream state.");
    }
    return itr;
  }

  // now running on child isolate
  static Future<void> _isolateHandler(Map<String, Object> params) async {
    Saga saga = params['saga'];
    SendPort sendToParentPort = params['sendToParentPort'];
    Object param = params['param'];

    ReceivePort fromParent = new ReceivePort();
    StreamIterator receiveFromParent = new StreamIterator(fromParent);

    // send sendPort to parent isolate for bi-directional communication.
    sendToParentPort.send(fromParent.sendPort);

    // directly handle saga (Stream of Effect).
    for (var effect in saga(param)) {
      if (effect is PutEffect || effect is TakeEveryEffect) {
        sendToParentPort.send(effect);
      }
      if (effect is ForkEffect) {
        sendToParentPort.send(effect);
        if (await receiveFromParent.moveNext()) {
          var taskId = receiveFromParent.current;
          effect.completer.complete(taskId);
        }
      } else if (effect is TakeEffect) {
        sendToParentPort.send(effect);
        if (await receiveFromParent.moveNext()) {
          var takenAction = receiveFromParent.current;
          effect.completer.complete(takenAction);
        }
      } else if (effect is CallableEffect) {
        await effect.call();
      } else if (effect is CancelEffect) {
        effect.taskId = await effect.taskIdFuture;
        effect.taskIdFuture = null;
        sendToParentPort.send(effect);
      }
    }
  }

  // still running on parent isolate
  void cancel() {
    for (_Task child in _childTasks) {
      child.cancel();
    }
    _Task._taskMap.remove(this.taskId);
    this._isolate.kill();
  }
}

class EffectManager {
  EffectManager() {
    print("start _isolate context");
  }

  // running on main _isolate
  Future run(Saga rootSaga, [Object param]) async {
    await new _EffectDispatcher(rootSaga, param);
  }
}
