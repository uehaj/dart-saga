import "dart:async";
import "dart:isolate";

import './effect.dart';

typedef EffectHandler(StreamIterator itr, Task task);

class Task {
  static int _taskIdSeed = 0;

  int taskId;

  static Map<int, Task> taskMap = {};

  Isolate _isolate;

  List<Task> _childTasks = [];

  Map<String, Object> _isolateInvokeMessage;

  SendPort _sendToChildPort;

  EffectHandler _handleEvent;

  void send(dynamic msg) {
    if (this._sendToChildPort != null) {
      this._sendToChildPort.send(msg);
    }
  }

  // still running on parent isolate
  Task(Function saga, EffectHandler this._handleEvent, [List<dynamic> param]) {
    this.taskId = Task._taskIdSeed++;
    Task.taskMap[this.taskId] = this;

    this._isolateInvokeMessage = {
      'saga': saga,
      'param': param,
    };
  }

  // still running on parent isolate
  Future<Task> start() async {
    ReceivePort onExitPort = new ReceivePort();
    onExitPort.listen((x) {
      print("onExitCheck: ${x}");
    });

    ReceivePort fromChild = new ReceivePort();
    _isolateInvokeMessage['sendToParentPort'] = fromChild.sendPort;
    this._isolate = await Isolate.spawn(
        Task._isolateHandler, this._isolateInvokeMessage,
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
    for (Task child in _childTasks) {
      child.cancel();
    }
    Task.taskMap.remove(this.taskId);
    this._isolate.kill();
  }
}
