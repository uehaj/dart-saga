import "dart:async";
import 'package:dart_saga/dart_saga.dart';

Iterable<Effect> rootSaga([msg, greeting]) sync* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Future<int> saga2handle;
  yield fork(saga2, params: ["start saga2"], getResult: (_) {
    saga2handle = _;
  });

  for (int i = 0; i < 5; i++) {
    //yield new AsyncCallEffect.func(
    //    () => new Future.delayed(new Duration(seconds: 1)));
    yield wait(1);
  }
  yield cancel(saga2handle);
}

Iterable<Effect> saga2([msg]) sync* {
  print("           saga2(${msg}) started");
  Future<int> saga3handle;
  yield fork(saga3, params: ["start saga3"], getResult: (_) {
    saga3handle = _;
  });
  int i = 0;
  while (true) {
    print("           saga2");
    yield wait(1);
    yield put(Action("HOGE"));
//    if (i++ == 10) {
//      yield new CancelEffect(saga2contextFuture);
//    }
  }
}

Iterable<Effect> saga3([msg]) sync* {
  print("                      saga3(${msg}) started");
  while (true) {
    print("                      saga3");
    Future action;
    yield take(Action("HOGE"), getResult: (_) async {
      action = _;
    });

    yield asyncCall.func((_) async {
      print("abc + ${_}");
    }, ["abc"]);
  }
}

main() {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, ["start rootSaga", "hello"]);
}
