# [WIP][poc] Port of redux-saga to Dart

Redux-saga like process manager for Dart.

This library supports communication pattern between isolates through 'cannel'.

_Note_: This package is still under development, and many of functionality might not be available yet. [Feedback](https://github.com/uehaj/dart-saga/issues) and [Pull Requests](https://github.com/uehaj/dart-saga/pulls) are most welcome!

## Sample code

```dart
import "dart:async";
import 'package:dart_saga/dart_saga.dart';

Iterable<Effect> rootSaga([msg, greeting]) sync* {
  print("rootSaga(${msg}) started greeting: ${greeting}");
  Future<int> saga2handle;
  yield fork(saga2, params: ["start saga2"], getResult: (_) {
    saga2handle = _;
  });

  for (int i = 0; i < 10; i++) {
    yield wait(1);
    if (i == 5) {
      yield cancel(saga2handle);
    }
  }
}

Iterable<Effect> saga2([msg]) sync* {
  print("           saga2(${msg}) started");
  Future<int> saga3handle;
  yield fork(saga3, params: ["start saga3"], getResult: (_) {
    saga3handle = _;
  });

  for (int i = 0; true; i++) {
    print("           saga2");
    yield wait(1);
    print("           put");
    yield put(Action("HOGE", "From saga2"));
    if (i == 3) {
      yield cancel(saga3handle);
    }
  }
}

Iterable<Effect> saga3([msg]) sync* {
  print("                      saga3(${msg}) started");
  while (true) {
    print("                      saga3");
    Future action;
    yield take("HOGE", getResult: (_) async {
      action = _;
    });

    yield asyncCall.func((_) async {
      print("                      taken ${ await action }");
    }, []);
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
Task.start 2
           saga2
                      saga3(start saga3) started
                      saga3
           put
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
           put
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
           put
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
           put
           saga2
                      taken Action(HOGE, From saga2)
                      saga3
Task(taskId=2) terminated: null.
           put
           saga2
Task(taskId=1) terminated: null.
Task(taskId=0) terminated: null.
```
