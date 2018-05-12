import './dispatcher.dart';

class EffectManager {
  EffectManager() {
    print("start _isolate context");
  }

  // running on main _isolate
  void run(Function rootSaga, [List<dynamic> param]) {
    new EffectDispatcher().run(rootSaga, param);
  }
}
