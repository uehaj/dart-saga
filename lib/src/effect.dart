import "dart:async";
import "dart:isolate";
import './action.dart';

abstract class Effect {}

class TakeEffect extends Effect {
  Action action;
  TakeEffect(this.action);
}

class TakeEveryEffect extends Effect {
  Action action;
  TakeEveryEffect(this.action);
}

class PutEffect extends Effect {
  Action action;
  PutEffect(this.action);
}

typedef Iterable<Effect> Saga(param);

class ForkEffect extends Effect {
  Saga saga;
  Isolate parent;
  Isolate child;
  Object param;
  ForkEffect(this.saga, [this.param]) {
    this.parent = Isolate.current;
  }
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

  Future<T> call() async {
    return await _callEffect();
  }
}
