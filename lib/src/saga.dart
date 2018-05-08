import "dart:async";
import "dart:isolate";
import './effect.dart';

typedef EffectHandler(StreamIterator itr, _Task task);

class _EffectDispatcher {
  Map<String, List<_Task>> _waitingTasks;

  _EffectDispatcher([waitingTasks]) {
    if (waitingTasks == null) {
      this._waitingTasks = {};
    } else {
      this._waitingTasks = waitingTasks;
    }
  }

  Future<_Task> run(saga, param) async =>
      new _Task(saga, this._handleEvent, param)..start();

  void _handleEvent(StreamIterator itr, _Task task) async {
    // effects which received from child isolate through Port.
    while (await itr.moveNext()) {
      Effect effect = itr.current;

      if (effect is PutEffect) {
        this._put(effect);
      } else if (effect is TakeEffect) {
        this._take(effect, task);
      } else if (effect is TakeEveryEffect) {
        /**/
      } else if (effect is ForkEffect) {
        _Task newTask = await (this.run(effect.saga, effect.param));
        // await task.start();
        // send back forked ask id to saga as a result of ForkEffect.
        task.send(newTask.taskId);
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

  EffectHandler _handleEvent;

  void send(msg) {
    if (this._sendToChildPort != null) {
      this._sendToChildPort.send(msg);
    }
  }

  // still running on parent isolate
  _Task(Saga saga, EffectHandler this._handleEvent, [Object param]) {
    this.taskId = _Task._taskIdSeed++;
    _Task._taskMap[this.taskId] = this;

    this._isolateInvokeMessage = {
      'saga': saga,
      'param': param,
    };
  }

  // still running on parent isolate
  Future<_Task> start() async {
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
    this._handleEvent(itr, this);
    return this;
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

    // directly handle effects from saga.
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
    (await new _EffectDispatcher()).run(rootSaga, param);
  }
}
