import "dart:async";
import "dart:isolate";

import './effect.dart';
import './helperSaga.dart' as SagaHelper;

class _IsolateInvokeMessage {
  Function saga;
  Object sagaParam;
  SendPort sendToParentPort;
  int taskId;

  _IsolateInvokeMessage(
      this.saga, this.sagaParam, this.sendToParentPort, this.taskId);
}

typedef void EffectHandler(StreamIterator itr, Task task);

class Task {
  static Map<int, Task> taskMap = {};
  final int taskId;

  static int _taskIdSeed = 0;
  Isolate _isolate;
  Isolate get isolate => _isolate;
  SendPort _sendToChildPort;
  EffectHandler _handleEvent;
  Function _saga;
  List<dynamic> _sagaParam;
  List<Task> _childTasks = [];

  void send(dynamic msg) {
    if (this._sendToChildPort != null) {
      this._sendToChildPort.send(msg);
    }
  }

  void addChildTask(Task task) {
    _childTasks.add(task);
  }

  // still running on parent isolate
  void cancel() {
    for (Task child in _childTasks) {
      child.cancel();
    }
    Task.taskMap.remove(this.taskId);
    this._isolate?.kill();
  }

  // still running on parent isolate
  Task(this._saga, this._sagaParam, this._handleEvent)
      : this.taskId = Task._taskIdSeed++ {
    Task.taskMap[this.taskId] = this;
  }

  // still running on parent isolate
  Future<void> start() async {
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
        paused: true,
        onExit: onExitPort.sendPort,
        onError: onErrorPort.sendPort);

    this._isolate.resume(this._isolate.pauseCapability);

    if (await itr.moveNext()) {
      this._sendToChildPort = itr.current;
    } else {
      throw new Exception("Illegal stream state.");
    }

    if (this._handleEvent != null) {
      this._handleEvent(itr, this);
    }
  }

  static handleError(Future future) => future
    ..catchError((e) {
      print("Async error on child isolate: ${e}");
      print(e.stackTrace);
    });

  // now running on child isolate
  static Future<void> _isolateHandler(_IsolateInvokeMessage params) async {
    SendPort sendToParentPort = params.sendToParentPort;
    ReceivePort fromParent = new ReceivePort();
    StreamIterator receiveFromParent = new StreamIterator(fromParent);

    // send sendPort to parent isolate for bi-directional communication.
    sendToParentPort.send(fromParent.sendPort);

    Stream sagaStream = Function.apply(params.saga, params.sagaParam);

    // directly handle effects from the saga.
    await for (var effect in sagaStream) {
      if (effect is PutEffect) {
        sendToParentPort.send(effect);
      } else if (effect is ForkEffect) {
        await Task.handleError(
            Task._fork(effect, sendToParentPort, receiveFromParent));
      } else if (effect is TakeEffect) {
        await Task.handleError(
            Task._take(effect, sendToParentPort, receiveFromParent));
      } else if (effect is TakeEveryEffect) {
        await Task.handleError(
            Task._takeEvery(effect, sendToParentPort, receiveFromParent));
      } else if (effect is TakeLatestEffect) {
        await Task.handleError(
            Task._takeLatest(effect, sendToParentPort, receiveFromParent));
      } else if (effect is CallableEffect) {
        await Task.handleError(effect.call());
      } else if (effect is CancelEffect) {
        await Task.handleError(Task._cancel(effect, sendToParentPort));
      }
    }
    await fromParent.close();
    await Task._terminate(params.taskId, sendToParentPort);
  }

  static Future<void> _fork(
      ForkEffect effect, sendToParentPort, receiveFromParent) async {
    Completer completer = effect.completer;
    effect.completer = null; // this is needed to avoid serialize error.
    sendToParentPort.send(effect);
    if (await receiveFromParent.moveNext()) {
      var taskId = receiveFromParent.current;
      if (completer != null) {
        completer.complete(taskId);
      }
    }
  }

  static Future<void> _take(
      TakeEffect effect, sendToParentPort, receiveFromParent) async {
    Completer completer = effect.completer;
    effect.completer = null; // this is needed to avoid serialize error.
    sendToParentPort.send(effect);
    if (await receiveFromParent.moveNext()) {
      var takenAction = receiveFromParent.current;
      if (completer != null) {
        completer.complete(takenAction);
      }
    }
  }

  static Future<void> _takeEvery(
      TakeEveryEffect effect, sendToParentPort, receiveFromParent) async {
    ForkEffect forkEffect = new ForkEffect(
        SagaHelper.takeEveryHelperSaga, [effect.actionType, effect.saga]);
    Task._fork(forkEffect, sendToParentPort, receiveFromParent);
  }

  static Future<void> _takeLatest(
      TakeLatestEffect effect, sendToParentPort, receiveFromParent) async {
    ForkEffect forkEffect = new ForkEffect(
        SagaHelper.takeLatestHelperSaga, [effect.actionType, effect.saga]);
    Task._fork(forkEffect, sendToParentPort, receiveFromParent);
  }

  static Future<void> _cancel(CancelEffect effect, sendToParentPort) async {
    sendToParentPort.send(effect);
  }

  static Future<void> _terminate(int taskId, sendToParentPort) async {
    CancelEffect effect = new CancelEffect(null);
    effect.taskId = taskId;
    sendToParentPort.send(effect);
  }
}
