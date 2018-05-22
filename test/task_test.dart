import 'package:test/test.dart';
import "dart:async";

import '../lib/src/task.dart';

saga1() async* {
  yield null;
}

void main() {
  group('Task', () {
    handleEvent(StreamIterator itr, Task task) {}

    test('construct Task', () async {
      final task1 = new Task(saga1, handleEvent);
      final task2 = new Task(saga1, handleEvent);
      expect(task1.taskId, isNot(task2.taskId));
      expect(Task.taskMap.containsKey(task1.taskId), true);
      expect(Task.taskMap.containsKey(task2.taskId), true);
      expect(Task.taskMap.containsKey(9999), false);
      task1.cancel();
      expect(Task.taskMap.containsKey(task1.taskId), false);
      expect(Task.taskMap.containsKey(task2.taskId), true);
      task2.cancel();
      expect(Task.taskMap.containsKey(task1.taskId), false);
      expect(Task.taskMap.containsKey(task2.taskId), false);
      task1.cancel(); // no effect
      task2.cancel(); // no effect
      expect(Task.taskMap.containsKey(task1.taskId), false);
      expect(Task.taskMap.containsKey(task2.taskId), false);
    });

    test('start Task', () async {
      final task1 = new Task(saga1, handleEvent)..start();
    });
  });
}
