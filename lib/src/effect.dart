import "dart:async";

import './action.dart';

abstract class Effect {}

class TakeEffect extends Effect {
  String actionType;
  Completer<dynamic> completer;

  TakeEffect(this.actionType, {this.completer});
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

  Completer<int> completer;

  ForkEffect(this.saga, {this.params, this.completer});
}

class CancelEffect extends Effect {
  int taskId;
  CancelEffect(this.taskId) {}
}

abstract class CallableEffect extends Effect implements Function {
  Future call();
}

typedef Future<T> _FutureFunc<T>(params);

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
