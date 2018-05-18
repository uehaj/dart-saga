import "dart:async";
import 'package:dart_saga/dart_saga.dart';

rootSaga([msg, greeting]) async* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Future<int> saga2handle;
  yield fork(saga2, params: ["start saga2"], getResult: (_) {
    saga2handle = _;
  });

  for (int i = 0; i < 10; i++) {
    yield wait(1);
    if (i == 5) {
      yield cancel(await saga2handle);
    }
  }
}

saga2([msg]) async* {
  print("           saga2(${msg}) started");
  Future<int> saga3handle;
  yield fork(saga3, params: ["start saga3"], getResult: (_) {
    saga3handle = _;
  });

  for (int i = 0; true; i++) {
    print("           saga2");
    yield wait(1);
    yield put(Action("HOGE", "From saga2"));
    if (i == 3) {
      yield cancel(saga3handle);
    }
  }
}

saga3([msg]) async* {
  print("                      saga3(${msg}) started");
  while (true) {
    print("                      saga3");
    Future takenAction;
    yield take("HOGE", getResult: (_) async {
      takenAction = _;
    });
    print("                      taken ${await takenAction}");
  }
}

main() {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, ["start rootSaga", "hello"]);
}
