import './dispatcher.dart';

class EffectManager {
  void run(Function rootSaga, [List<dynamic> param = const []]) {
    new EffectDispatcher().run(rootSaga, param);
  }
}
