import "dart:async";

import './action.dart';

abstract class Effect {}

typedef void SagaYieldCallback<T>(Future<T> sc);

class TakeEffect extends Effect {
  String actionType;
  Completer<dynamic> completer = new Completer();

  TakeEffect(this.actionType, {SagaYieldCallback<dynamic> getResult}) {
    if (getResult != null) {
      getResult(completer.future);
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
  Function saga;
  Object params;
  int perentTaskId;

  Completer<int> completer = new Completer();

  ForkEffect(this.saga,
      {SagaYieldCallback<int> getResult, Object this.params}) {
    if (getResult != null) {
      getResult(completer.future);
    }
  }
}

class CancelEffect extends Effect {
  Future<int> taskIdFuture;
  int taskId;
  CancelEffect(this.taskIdFuture) {}
}

typedef Future<T> _FutureFunc<T>(params);

abstract class CallableEffect extends Effect implements Function {
  Future call();
}

class AsyncCallEffect<T> extends CallableEffect {
  _FutureFunc<T> _futureFunc;
  Object _params;
  AsyncCallEffect.value(Future<T> value) {
    this._futureFunc = (_) => value;
  }

  AsyncCallEffect.func(this._futureFunc, [this._params]);

  @override
  Future<T> call() async {
    return await _futureFunc(this._params);
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
