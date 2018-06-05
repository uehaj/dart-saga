import "dart:async";

import './effect.dart';

Stream takeLatestHelperSaga(actionType, saga) async* {
  int currentTaskId = null;
  while (true) {
    Completer completer = new Completer();
    yield TakeEffect(actionType, completer);
    var takenAction = await completer.future;
    Completer<int> taskIdFuture = new Completer();
    yield ForkEffect(saga, [takenAction.payload], taskIdFuture);
    if (currentTaskId != null) {
      yield CancelEffect(currentTaskId);
    }
    currentTaskId = await taskIdFuture.future;
  }
}

Stream takeEveryHelperSaga(actionType, saga) async* {
  while (true) {
    Completer completer = new Completer();
    yield TakeEffect(actionType, completer);
    var takenAction = await completer.future;
    yield ForkEffect(saga, [takenAction.payload]);
  }
}
