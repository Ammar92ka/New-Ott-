import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/data/events.dart';
import 'package:ottoman_empire_1800/models/game_event.dart';

void main() {
  group('بيانات الأحداث', () {
    test('القائمة غير فارغة وطولها يحدد طول الحملة', () {
      expect(gameEvents, isNotEmpty);
    });

    test('المعرفات فريدة', () {
      final ids = gameEvents.map((e) => e.id).toSet();
      expect(ids.length, equals(gameEvents.length));
    });

    test('كل حدث له نص وخياران على الأقل وكل خيار له نتيجة', () {
      for (final e in gameEvents) {
        expect(e.title.trim(), isNotEmpty, reason: e.id);
        expect(e.scene.trim(), isNotEmpty, reason: e.id);
        expect(e.dilemma.trim(), isNotEmpty, reason: e.id);
        expect(e.choices.length, greaterThanOrEqualTo(2), reason: e.id);
        for (final c in e.choices) {
          expect(c.text.trim(), isNotEmpty, reason: e.id);
          expect(c.result.trim(), isNotEmpty, reason: e.id);
        }
      }
    });

    test('آثار القرارات ضمن حدود معقولة', () {
      for (final e in gameEvents) {
        for (final c in e.choices) {
          final fx = c.effects;
          expect(fx.treasury.abs(), lessThanOrEqualTo(3000), reason: e.id);
          expect(fx.debt.abs(), lessThanOrEqualTo(3000), reason: e.id);
          expect(fx.sultan.abs(), lessThanOrEqualTo(15), reason: e.id);
          expect(fx.stability.abs(), lessThanOrEqualTo(15), reason: e.id);
          expect(fx.grain.abs(), lessThanOrEqualTo(15), reason: e.id);
        }
      }
    });
  });

  group('القرارات المهمة', () {
    test('الأثر الكبير يحتاج تأكيدا والصغير لا', () {
      const big = GameChoice(
        text: 'a',
        result: 'b',
        effects: Effects(treasury: -900),
      );
      const small = GameChoice(
        text: 'a',
        result: 'b',
        effects: Effects(treasury: -200, sultan: 3),
      );
      expect(big.isMajor, isTrue);
      expect(small.isMajor, isFalse);
    });
  });
}
