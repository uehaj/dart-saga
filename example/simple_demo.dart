import "dart:async";
import 'package:dart_saga/dart_saga.dart';

rootSaga([msg, greeting]) async* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Completer<int> saga2handle = new Completer();
  yield fork(saga2, ["start saga2"], saga2handle);

  for (int i = 0; i < 10; i++) {
    yield delay(1000);
    if (i == 5) {
      yield cancel(await saga2handle.future);
    }
  }
}

saga2([msg]) async* {
  print("           saga2(${msg}) started");
  Completer<int> saga3handle;
  yield fork(saga3, ["start saga3"], saga3handle);

  for (int i = 0; true; i++) {
    print("           saga2");
    yield delay(1000);
    yield put(Action("HOGE", "From saga2"));
    if (i == 3) {
      yield cancel(await saga3handle.future);
    }
  }
}

saga3([msg]) async* {
  print("                      saga3(${msg}) started");
  while (true) {
    print("                      saga3");
    Completer takenAction = new Completer();
    yield take("HOGE", takenAction);
    print("                      taken ${await takenAction.future}");
  }
}

main() {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, ["start rootSaga", "hello"]);
}
