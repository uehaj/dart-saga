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
      final task1 = new Task(saga1, [], handleEvent);
      final task2 = new Task(saga1, [], handleEvent);
      expect(task1.taskId, isNot(task2.taskId));
      expect(Task.taskMap, contains(task1.taskId));
      expect(Task.taskMap, contains(task2.taskId));
      expect(Task.taskMap, isNot(contains(9999)));
      task1.cancel();
      expect(Task.taskMap, isNot(contains(task1.taskId)));
      expect(Task.taskMap, contains(task2.taskId));
      task2.cancel();
      expect(Task.taskMap, isNot(contains(task1.taskId)));
      expect(Task.taskMap, isNot(contains(task2.taskId)));
      task1.cancel(); // no effect
      task2.cancel(); // no effect
      expect(Task.taskMap, isNot(contains(task1.taskId)));
      expect(Task.taskMap, isNot(contains(task2.taskId)));
    });

    test('start Task', () async {
      final task1 = new Task(saga1, [], handleEvent)..start();
      // final task2 = task1.;
    });
  });
}
