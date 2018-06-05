import "dart:async";
import "dart:isolate";
import 'package:test/test.dart';
import 'package:dart_saga/dart_saga.dart';

_saga1(sendPort) async* {
  yield new fork(_saga2, [sendPort]);
  yield new delay(1000);
  yield new put(new Action("HOGE", "hello"));
}

_saga2(sendPort) async* {
  Completer<Action> completer = new Completer();
  yield new take("HOGE", completer);
  Action takenAction = await completer.future;
  sendPort.send(takenAction);
}

void main() {
  group('PutTake', () {
    test('call constructor', () async {
      ReceivePort rp = new ReceivePort();
      new EffectManager().run(_saga1, [rp.sendPort]);

      expect(rp, emits(equals(new Action("HOGE", "hello"))));
    });
  });
}
