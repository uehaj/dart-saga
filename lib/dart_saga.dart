import "dart:async";

import 'src/effect.dart';
export 'src/manager.dart';
export 'src/action.dart';
export 'src/effect.dart';

/*
typedef TakeEffect take;
typedef TakeEveryEffect takeEvery;
typedef PutEffect put;
typedef ForkEffect fork;
typedef CancelEffect cancel;
typedef AsyncCallEffect<T> asynCall;
typedef WaitEffect<T> wait;
*/

class take extends TakeEffect {
  take(actionType, {completer}) : super(actionType, completer: completer);
}

class takeEvery extends TakeEveryEffect {
  takeEvery(action) : super(action);
}

class put extends PutEffect {
  put(action) : super(action);
}

class fork extends ForkEffect {
  fork(saga, {params, completer})
      : super(saga, params: params, completer: completer);
}

class cancel extends CancelEffect {
  cancel(taskIdFuture) : super(taskIdFuture);
}

class call<T> extends CallEffect<T> {
  call.value(Future<T> value) : super.value(value);
  call.func(Future<T> futureFunc(dynamic), [params])
      : super.func(futureFunc, params);
}

class delay<T> extends DelayEffect<T> {
  delay(int sec) : super(sec);
}
