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

  Future<_Task> run(Function saga, List<dynamic> param) async =>
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
        this._fork(effect, task);
      } else if (effect is CancelEffect) {
        this._cancel(effect);
      }
    }
  }

  void _put(PutEffect effect) {
    if (_waitingTasks[effect.action.type] != null) {
      for (var waitingSaga in _waitingTasks[effect.action.type]) {
        waitingSaga.send(effect.action);
      }
      _waitingTasks.remove(effect.action.type);
    }
  }

  void _take(TakeEffect effect, _Task task) {
    if (_waitingTasks[effect.action.type] == null) {
      _waitingTasks[effect.action.type] = [task];
    } else {
      _waitingTasks[effect.action.type].add(task);
    }
  }

  void _fork(ForkEffect effect, _Task task) async {
    _Task newTask = await (this.run(effect.saga, effect.params));
    // send back forked task id to the saga as a result of ForkEffect.
    task.send(newTask.taskId);
  }

  void _cancel(CancelEffect effect) {
    _Task._taskMap[effect.taskId]?.cancel();
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

  void send(dynamic msg) {
    if (this._sendToChildPort != null) {
      this._sendToChildPort.send(msg);
    }
  }

  // still running on parent isolate
  _Task(Function saga, EffectHandler this._handleEvent, [List<dynamic> param]) {
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
    Function saga = params['saga'];
    Object param = params['param'];
    SendPort sendToParentPort = params['sendToParentPort'];

    ReceivePort fromParent = new ReceivePort();
    StreamIterator receiveFromParent = new StreamIterator(fromParent);

    // send sendPort to parent isolate for bi-directional communication.
    sendToParentPort.send(fromParent.sendPort);

    // directly handle effects from saga.
    for (var effect in Function.apply(saga, param)) {
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
  Future run(Function rootSaga, [List<dynamic> param]) async {
    (await new _EffectDispatcher()).run(rootSaga, param);
  }
}
