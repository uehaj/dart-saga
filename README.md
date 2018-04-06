# [WIP][POC] Port of redux-saga to Dart

Redux-saga like process manager for Dart.

*Note*: This package is still under development, and many of functionality might not be available yet. [Feedback](https://github.com/uehaj/dart-saga/issues) and [Pull Requests](https://github.com/uehaj/dart-saga/pulls) are most welcome!

## Sample code

```dart
import "dart:async";
import 'package:dart_saga/dart_saga.dart';

Iterable<Effect> rootSaga([msg]) sync* {
  print("rootSaga(${msg}) started");
  yield new ForkEffect(saga2, "start saga2");
  while (true) {
    print("rootSaga");
    yield new AsyncCallEffect.func(
        () => new Future.delayed(new Duration(seconds: 1)));
  }
}

Iterable<Effect> saga2([msg]) sync* {
  print("           saga2(${msg}) started");
  yield new ForkEffect(saga3, "start saga3");
  while (true) {
    print("           saga2");
    yield new WaitEffect(3);
    yield new PutEffect(new Action("HOGE"));
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
  effectManager.startSaga(rootSaga, "start rootSaga");
}


```

### Demo

```
% pub run example/simple_demo.dart
start isolate context
rootSaga(start rootSaga) started
rootSaga
           saga2(start saga2) started
           saga2
                      saga3(start saga3) started
                      saga3
rootSaga
rootSaga
rootSaga
           saga2
Action(HOGE)
                      saga3
rootSaga
rootSaga
  :
```

