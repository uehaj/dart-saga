import "dart:async";
import 'package:dart_saga/dart_saga.dart';

Iterable<Effect> rootSaga([msg, greeting]) sync* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Future<int> saga2handle;
  yield new ForkEffect(saga2, params: ["start saga2"], getResult: (_) {
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
  yield new ForkEffect(saga3, params: ["start saga3"], getResult: (_) {
    saga3handle = _;
  });
  int i = 0;
  while (true) {
    print("           saga2");
    yield new WaitEffect(1);
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

main() {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, ["start rootSaga", "hello"]);
  print("=+=+");
}
