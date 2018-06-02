import "dart:async";

import 'package:test/test.dart';

import '../lib/src/effect.dart';

void saga1() {}

void main() {
  group('TakeEffect', () {
    test('construct TakeEffect', () async {
      Completer completer = new Completer();
      final effect = new TakeEffect("ACT1", completer);
      completer.complete(777);
      expect("ACT1", effect.actionType);
      expect(await effect.completer.future, 777);
    });
  });

  group('ForkEffect', () {
    test('construct ForkEffect', () async {
      Completer completer = new Completer();
      final effect = new ForkEffect(saga1, [1, 2, 3], completer);
      completer.complete(777);
      expect(effect.params, [1, 2, 3]);
      expect(await effect.completer.future, 777);
    });
  });

  group('CallEffect', () {
    test('construct CallEffect.func', () async {
      final func = (p) async {
        expect(p, [1, 2, 3]);
        return 777;
      };
      final effect = new CallEffect.func(func, [1, 2, 3]);
      expect(await effect.call(), 777);
    });

    test('construct CallEffect.value', () async {
      final effect = new CallEffect.value(new Future.value([1, 2, 3]));
      expect(await effect.call(), [1, 2, 3]);
    });
  });

  group('DelayEffect', () {
    test('construct DelayEffect', () async {
      final effect = new DelayEffect(3);
      expect(await effect.call(), null);
    });
  });
}
