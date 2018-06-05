import 'package:test/test.dart';
import "dart:async";
import "dart:isolate";

import '../lib/src/effect.dart';
import '../lib/src/task.dart';
import '../lib/src/action.dart';

PutEffect pe = new PutEffect(new Action("HOGE"));

_saga1() async* {
  yield pe;
}

StreamController _sc;

void _handleEvent(StreamIterator<dynamic> itr, Task task) async {
  while (await itr.moveNext()) {
    _sc.add(itr.current);
  }
  _sc.close();
}

void main() {
  group('Task', () {
    test('call constructor', () async {
      final task1 = new Task(_saga1, [], null);
      final task2 = new Task(_saga1, [], null);
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

    test('start and cancel', () async {
      int length0 = Task.taskMap.entries.toList().length;
      final task1 = new Task(_saga1, [], null);
      await task1.start();

      expect(Task.taskMap.entries.toList().length, equals(length0 + 1));
      expect(Task.taskMap, contains(task1.taskId));
      expect(task1.isolate, isNot(Isolate.current));
      expect(Isolate.current, isNotNull);
      expect(task1.isolate, isNotNull);

      task1.cancel();
      expect(Task.taskMap.entries.toList().length, equals(length0));

      expect(Task.taskMap, isNot(contains(task1.taskId)));
    });
  });

  test('start and ping', () async {
    final task1 = new Task(_saga1, [], null);
    await task1.start();
    ReceivePort rp = new ReceivePort();
    task1.isolate.ping(rp.sendPort, response: "hello");
    expect(rp, emits("hello"));
    task1.cancel();
  });

  test('handle event', () async {
    _sc = new StreamController();
    expect(
        _sc.stream,
        emitsInOrder([
          emits(equals(pe)),
          emits(new isInstanceOf<CancelEffect>()),
          emitsDone
        ]));
    final task1 = new Task(_saga1, [], _handleEvent);
    await task1.start();
    task1.cancel();
  });
}
