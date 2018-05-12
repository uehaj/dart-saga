import "dart:async";
import "dart:isolate";

import './effect.dart';

typedef EffectHandler(StreamIterator itr, Task task);

class _IsolateInvokeMessage {
  Function saga;
  Object sagaParam;
  SendPort sendToParentPort;
  int taskId;
  _IsolateInvokeMessage(
      this.saga, this.sagaParam, this.sendToParentPort, this.taskId);
}

class Task {
  static int _taskIdSeed = 0;

  int taskId;

  static Map<int, Task> taskMap = {};

  Isolate _isolate;

  List<Task> _childTasks = [];

  void addChildTask(Task task) {
    _childTasks.add(task);
  }

  SendPort _sendToChildPort;

  EffectHandler _handleEvent;

  Function _saga;

  List<dynamic> _sagaParam;

  void send(dynamic msg) {
    if (this._sendToChildPort != null) {
      this._sendToChildPort.send(msg);
    }
  }

  // still running on parent isolate
  Task(this._saga, this._handleEvent, [this._sagaParam]) {
    this.taskId = Task._taskIdSeed++;
    Task.taskMap[this.taskId] = this;
  }

  // still running on parent isolate
  Future<Task> start() async {
    print("Task.start ${this.taskId}");
    ReceivePort onExitPort = new ReceivePort();
    ReceivePort onErrorPort = new ReceivePort();
    ReceivePort fromChild = new ReceivePort();

    onExitPort.listen((msg) {
      fromChild.close();
      print("Task(taskId=${this.taskId}) terminated: ${msg}.");
      if (Task.taskMap[this.taskId] != null) {
        Task.taskMap.remove(this.taskId);
      }
      onExitPort.close();
      onErrorPort.close();
    });

    onErrorPort.listen((error) {
      print("Task(taskId=${this.taskId}) error: ${error}.");
    });

    StreamIterator itr = new StreamIterator(fromChild);

    _IsolateInvokeMessage isolateInvokeMessage = new _IsolateInvokeMessage(
        this._saga, this._sagaParam, fromChild.sendPort, this.taskId);

    this._isolate = await Isolate.spawn(
        Task._isolateHandler, isolateInvokeMessage,
        paused: false,
        onExit: onExitPort.sendPort,
        onError: onErrorPort.sendPort);

    if (await itr.moveNext()) {
      this._sendToChildPort = itr.current;
    } else {
      throw new Exception("Illegal stream state.");
    }

    return this.._handleEvent(itr, this);
  }

  // now running on child isolate
  static Future<void> _isolateHandler(_IsolateInvokeMessage params) async {
    SendPort sendToParentPort = params.sendToParentPort;
    ReceivePort fromParent = new ReceivePort();
    StreamIterator receiveFromParent = new StreamIterator(fromParent);

    // send sendPort to parent isolate for bi-directional communication.
    sendToParentPort.send(fromParent.sendPort);

    // directly handle effects from saga.
    for (var effect in Function.apply(params.saga, params.sagaParam)) {
      if (effect is PutEffect || effect is TakeEveryEffect) {
        sendToParentPort.send(effect);
      } else if (effect is ForkEffect) {
        effect.perentTaskId = params.taskId;
        await Task._fork(effect, sendToParentPort, receiveFromParent);
      } else if (effect is TakeEffect) {
        await Task._take(effect, sendToParentPort, receiveFromParent);
      } else if (effect is CallableEffect) {
        await effect.call();
      } else if (effect is CancelEffect) {
        await Task._cancel(effect, sendToParentPort);
      }
    }

    fromParent.close();
    await Task._terminate(params.taskId, sendToParentPort);
  }

  static Future<void> _fork(
      ForkEffect effect, sendToParentPort, receiveFromParent) async {
    sendToParentPort.send(effect);
    if (await receiveFromParent.moveNext()) {
      var taskId = receiveFromParent.current;
      effect.completer.complete(taskId);
    }
  }

  static Future<void> _take(
      TakeEffect effect, sendToParentPort, receiveFromParent) async {
    sendToParentPort.send(effect);
    if (await receiveFromParent.moveNext()) {
      var takenAction = receiveFromParent.current;
      effect.completer.complete(takenAction);
    }
  }

  static Future<void> _cancel(CancelEffect effect, sendToParentPort) async {
    // fullfill Future of taskID.
    effect.taskId = await effect.taskIdFuture;
    effect.taskIdFuture = null; // this is needed to avoid serialize error.
    sendToParentPort.send(effect);
  }

  static Future<void> _terminate(int taskId, sendToParentPort) async {
    CancelEffect effect = new CancelEffect(null);
    effect.taskId = taskId;
    sendToParentPort.send(effect);
  }

  // still running on parent isolate
  void cancel() {
    for (Task child in _childTasks) {
      child.cancel();
    }
    Task.taskMap.remove(this.taskId);
    this._isolate.kill();
  }
}
