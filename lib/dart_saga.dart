import "dart:async";

import 'src/effect.dart';
export 'src/manager.dart';
export 'src/action.dart';
export 'src/effect.dart';

class take extends TakeEffect {
  take(actionType, [completer]) : super(actionType, completer);
}

class takeEvery extends TakeEveryEffect {
  takeEvery(actionType, saga) : super(actionType, saga);
}

class takeLatest extends TakeLatestEffect {
  takeLatest(actionType, saga) : super(actionType, saga);
}

class put extends PutEffect {
  put(action) : super(action);
}

class fork extends ForkEffect {
  fork(saga, [params, completer]) : super(saga, params, completer);
}

class cancel extends CancelEffect {
  cancel(taskId) : super(taskId);
}

class call<T> extends CallEffect<T> {
  call.value(Future<T> value) : super.value(value);
  call.func(Future<T> futureFunc(dynamic), [params])
      : super.func(futureFunc, params);
}

class delay<T> extends DelayEffect<T> {
  delay(int sec) : super(sec);
}
