# [WIP][poc] Port of redux-saga to Dart

Redux-saga like isolate handle library for Dart.

This library supports invoke isolate easilily, and communication pattern between isolates through channel.

Integrated with dart-redux are planned.

_Note_: This package is still under development, and many of functionality might not be available yet. [Feedback](https://github.com/uehaj/dart-saga/issues) and [Pull Requests](https://github.com/uehaj/dart-saga/pulls) are most welcome!

## Sample code

```dart
import "dart:async";
import 'package:dart_saga/dart_saga.dart';

rootSaga([msg, greeting]) async* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Completer<int> saga2handle = new Completer();
  yield fork(saga2, params: ["start saga2"], completer: saga2handle);

  for (int i = 0; i < 10; i++) {
    yield wait(1);
    if (i == 5) {
      yield cancel(await saga2handle.future);
    }
  }
}

saga2([msg]) async* {
  print("           saga2(${msg}) started");
  Completer<int> saga3handle;
  yield fork(saga3, params: ["start saga3"], completer: saga3handle);

  for (int i = 0; true; i++) {
    print("           saga2");
    yield wait(1);
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
    yield take("HOGE", completer: takenAction);
    print("                      taken ${await takenAction.future}");
  }
}

main() {
  var effectManager = new EffectManager();
  effectManager.run(rootSaga, ["start rootSaga", "hello"]);
}
```

### Demo

```
% pub run example/simple_demo.dart
start _isolate context
Task.start 0
rootSaga(start rootSaga) started greeting: hello
Task.start 1
           saga2(start saga2) started
           saga2
Task.start 2
                      saga3(start saga3) started
                      saga3
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
Task(taskId=2) terminated: null.
Task(taskId=1) terminated: null.
Task(taskId=0) terminated: null.
```

# Implemented Redux-Saga's Effects

* [x] take
* [ ] takeMaybe
* [x] put
* [ ] putResolve
* [ ] all
* [ ] race
* [x] call
* [ ] apply
* [ ] cps
* [x] fork
* [ ] spawn
* [ ] join
* [x] cancel
* [ ] select
* [ ] actionChannel
* [ ] cancelled
* [ ] flush
* [ ] getContext
* [ ] setContext,
* [ ] retry
* [ ] takeEvery
* [ ] takeLatest
* [ ] takeLeading
* [ ] throttle
* [x] delay

# Restrictions

Dart's generator/async generator lacks ability to return value from `yield` construts.
In ES2015, `yield` is expression but in Dart its' statement, so we canot value from effect directly.
In this library you have to use completer.
