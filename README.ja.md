# [WIP] Port of redux-saga to Dart

Dart-SagaはRedux-sagaのDartへの移植版です。

このライブラリは、チャンネルを通じたDartのアイソレート間の協調をサポートします。

単独で動作しますが、今後dart-reduxに組込まれる予定です

_注意_: このパッケージは開発中であり、多くの機能がまだ利用できません。[フィードバック](https://github.com/uehaj/dart-saga/issues)や[プルリクエスト](https://github.com/uehaj/dart-saga/pulls)を歓迎します。

## サンプルコード

```dart
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

# Redux-Sagaのエフェクト実装状況

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

# 仕様上の制約

Dartのジェネレータおよび非同期ジェネレータでは、Dartの言語仕様上yieldが[値を返すことはできません](https://github.com/dart-lang/sdk/issues/32831)(PythonやES2015では可能)。このライブラリではエフェクトのyieldで値を取得するためにCompleterを使用します。

たとえば、

```
  int sagaHandle = yield fork(saga2, []);

```

のように書きたいときでも、本ライブラリでは以下のように記述する必要があります。

```
  Completer<int> sagaHandle = new Completer();
  yield fork(saga2, [], sagaHandle);

```

