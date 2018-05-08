import "dart:async";
import './dispatcher.dart';

class EffectManager {
  EffectManager() {
    print("start _isolate context");
  }

  // running on main _isolate
  Future run(Function rootSaga, [List<dynamic> param]) async {
    (await new EffectDispatcher()).run(rootSaga, param);
  }
}
