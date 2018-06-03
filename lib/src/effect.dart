import "dart:async";

import './action.dart';

abstract class Effect {}

class TakeEffect extends Effect {
  String actionType;
  Completer<dynamic> completer;

  TakeEffect(this.actionType, [this.completer]);
}

class TakeEveryEffect extends Effect {
  String actionType;
  Function saga;

  TakeEveryEffect(this.actionType, this.saga);
}

class TakeLatestEffect extends Effect {
  Action action;
  TakeLatestEffect(this.action);
}

class PutEffect extends Effect {
  Action action;
  PutEffect(this.action);
  bool operator ==(other) {
    return (other is PutEffect && other.action == this.action);
  }
}

class ForkEffect extends Effect {
  Function saga;
  Object params;
  Completer<int> completer;

  ForkEffect(this.saga, [this.params, this.completer]);
}

class CancelEffect extends Effect {
  int taskId;
  CancelEffect(this.taskId) {}
}

abstract class CallableEffect extends Effect implements Function {
  Future call();
}

typedef Future<T> _FutureFunc<T>(params);

class CallEffect<T> extends CallableEffect {
  _FutureFunc<T> _futureFunc;
  Object _params;
  CallEffect.value(Future<T> value) {
    this._futureFunc = (_) => value;
  }

  CallEffect.func(this._futureFunc, [this._params]);

  @override
  Future<T> call() async {
    return await _futureFunc(this._params);
  }
}

class DelayEffect<T> extends CallableEffect {
  CallEffect _callEffect;

  DelayEffect(int ms) {
    this._callEffect = new CallEffect.value(
        new Future.delayed(new Duration(milliseconds: ms)));
  }

  @override
  Future<T> call() async {
    return await _callEffect();
  }
}
