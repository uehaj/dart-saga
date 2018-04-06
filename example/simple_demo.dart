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
