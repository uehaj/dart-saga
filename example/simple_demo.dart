import "dart:async";
import 'package:dart_saga/dart_saga.dart';

Iterable<Effect> rootSaga([msg]) sync* {
  print("rootSaga(${msg}) started");
  Future<int> saga2handle;
  yield new ForkEffect(saga2, param: "start saga2", callback: (_) {
    saga2handle = _;
  });

  for (int i = 0; i < 5; i++) {
    yield new AsyncCallEffect.func(
        () => new Future.delayed(new Duration(seconds: 1)));
    // yield new WaitEffect(1);
  }
  yield new CancelEffect(saga2handle);
}

Iterable<Effect> saga2([msg]) sync* {
  print("           saga2(${msg}) started");
  Future<int> saga3handle;
  yield new ForkEffect(saga3, param: "start saga3", callback: (_) {
    saga3handle = _;
  });
  int i = 0;
  while (true) {
    print("           saga2");
    yield new WaitEffect(3);
    yield new PutEffect(new Action("HOGE"));
//    if (i++ == 10) {
//      yield new CancelEffect(saga2contextFuture);
//    }
  }
}

Iterable<Effect> saga3([msg]) sync* {
  print("                      saga3(${msg}) started");
  while (true) {
    print("                      saga3");
    yield new TakeEffect(new Action("HOGE"));
  }
}

main() async {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, "start rootSaga");
}
