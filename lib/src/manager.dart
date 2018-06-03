import './dispatcher.dart';

class EffectManager {
  // running on main _isolate
  void run(Function rootSaga, [List<dynamic> param]) {
    new EffectDispatcher().run(rootSaga, param);
  }
}
