import "dart:async";

import './effect.dart';
import './task.dart';

class EffectDispatcher {
  Map<String, List<Task>> _waitingTasks = {};

  Future<Task> run(Function saga, List<dynamic> param) async =>
      new Task(saga, this._handleEvent, param)..start();

  void _handleEvent(StreamIterator itr, Task task) async {
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

  void _take(TakeEffect effect, Task task) {
    if (_waitingTasks[effect.action.type] == null) {
      _waitingTasks[effect.action.type] = [task];
    } else {
      _waitingTasks[effect.action.type].add(task);
    }
  }

  void _fork(ForkEffect effect, Task task) async {
    Task newTask = await (this.run(effect.saga, effect.params));
    // send back forked task id to the saga as a result of ForkEffect.
    Task parentTask = Task.taskMap[effect.perentTaskId];
    parentTask.addChildTask(newTask);
    task.send(newTask.taskId);
  }

  void _cancel(CancelEffect effect) {
    Task.taskMap[effect.taskId]?.cancel();
  }
}
