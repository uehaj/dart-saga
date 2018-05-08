import "dart:async";
import './action.dart';
import './saga.dart';

typedef Iterable<Effect> Saga(param);

abstract class Effect {}

typedef void SagaYieldCallback<T>(Future<T> sc);

class TakeEffect extends Effect {
  Action action;
  Completer<dynamic> completer = new Completer();

  TakeEffect(this.action, {SagaYieldCallback<dynamic> callback}) {
    if (callback != null) {
      callback(completer.future);
    }
  }
}

class TakeEveryEffect extends Effect {
  Action action;
  TakeEveryEffect(this.action);
}

class PutEffect extends Effect {
  Action action;
  PutEffect(this.action);
}

class ForkEffect extends Effect {
  Saga saga;
  Object param;
  Completer<int> completer = new Completer();

  ForkEffect(this.saga, {SagaYieldCallback<int> callback, Object this.param}) {
    if (callback != null) {
      callback(completer.future);
    }
  }
}

class CancelEffect extends Effect {
  Future<int> taskIdFuture;
  int taskId;
  CancelEffect(this.taskIdFuture) {}
}

typedef Future<T> FutureFunc<T>();

abstract class CallableEffect extends Effect implements Function {
  call();
}

class AsyncCallEffect<T> extends CallableEffect {
  FutureFunc<T> _futureFunc;
  AsyncCallEffect.value(Future<T> value) {
    this._futureFunc = () => value;
  }

  AsyncCallEffect.func(this._futureFunc);

  @override
  Future<T> call() async {
    return await _futureFunc();
  }
}

// WaitEffect(nSeconds) is equivarent to:
// new AsyncCallEffect.func(
//        () => new Future.delayed(new Duration(seconds: nSeconds)));
class WaitEffect<T> extends CallableEffect {
  AsyncCallEffect _callEffect;

  WaitEffect(int delay) {
    this._callEffect = new AsyncCallEffect.value(
        new Future.delayed(new Duration(seconds: delay)));
  }

  @override
  Future<T> call() async {
    return await _callEffect();
  }
}
