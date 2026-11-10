import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/engine/game_engine.dart';
import 'package:ottoman_empire_1800/models/game_event.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';
import 'package:ottoman_empire_1800/services/economy.dart';

GameEvent _event(Effects effects) => GameEvent(
  id: 'test',
  title: 'حدث تجريبي',
  place: 'مكان',
  scene: 'مشهد',
  dilemma: 'معضلة',
  choices: [GameChoice(text: 'خيار', result: 'نتيجة', effects: effects)],
);

void main() {
  group('التاريخ', () {
    test('الجولة 0 هي كانون الثاني 1800 والجولة 12 تبدأ 1801', () {
      expect(GameEngine.dateLabel(0), equals('كانون الثاني 1800'));
      expect(GameEngine.dateLabel(11), equals('كانون الأول 1800'));
      expect(GameEngine.dateLabel(12), equals('كانون الثاني 1801'));
    });
  });

  group('تنفيذ القرار', () {
    test('يطبق الأثر ثم إيراد الشهر ونفقاته ويزيد الجولة', () {
      final engine = GameEngine([
        _event(
          const Effects(treasury: -500, sultan: 5, stability: 3, grain: 1),
        ),
      ]);
      final s = GameState();
      final report = engine.applyChoice(s, 0);

      // الخزينة: 12000 - 500 + (1101.6 - 1450)
      expect(s.treasury, closeTo(11151.6, 0.01));
      expect(s.sultan, equals(68)); // 65 + 5 - 2 (إرهاق الشهر)
      expect(s.stability, equals(64)); // 63 + 3 - 2
      expect(s.grain, equals(13));
      expect(s.turn, equals(1));
      expect(s.history.length, equals(1));
      expect(report.revenue, closeTo(1101.6, 0.01));
      expect(report.expenses, equals(EconomyRules.baseExpenses));
    });

    test('فائدة الدين تحسب شهريا', () {
      final engine = GameEngine([_event(const Effects())]);
      final s = GameState(debt: 1200);
      final report = engine.applyChoice(s, 0);
      expect(report.interest, closeTo(15, 0.001));
      expect(s.debt, closeTo(1215, 0.001));
    });

    test('عجز الخزينة يتحول إلى دين بعمولة والخزينة تصبح صفرا', () {
      final engine = GameEngine([_event(const Effects())]);
      final s = GameState(treasury: 100);
      final report = engine.applyChoice(s, 0);
      expect(s.treasury, equals(0));
      expect(report.borrowed, greaterThan(0));
      expect(s.debt, closeTo(report.borrowed, 0.001));
      // العجز: 100 + (1086.3 - 1450) = -263.7، والدين = 263.7 × 1.10
      expect(report.borrowed, closeTo(290.07, 0.01));
    });

    test('الدين لا يصير سالبا', () {
      final engine = GameEngine([_event(const Effects(debt: -5000))]);
      final s = GameState(debt: 100);
      engine.applyChoice(s, 0);
      expect(s.debt, greaterThanOrEqualTo(0));
    });

    test('بعد نهاية الحملة لا يوجد حدث ويرمي خطأ عند التنفيذ', () {
      final engine = GameEngine();
      final s = GameState(turn: engine.totalTurns);
      expect(engine.eventFor(s), isNull);
      expect(() => engine.applyChoice(s, 0), throwsStateError);
    });

    test('رقم خيار غير صالح يرمي خطأ', () {
      final engine = GameEngine();
      final s = GameState();
      expect(() => engine.applyChoice(s, 9), throwsRangeError);
      expect(() => engine.applyChoice(s, -1), throwsRangeError);
    });

    test('لعب عشوائي لا يخرج المؤشرات عن حدودها أبدا', () {
      final engine = GameEngine();
      final rnd = Random(42);
      for (var run = 0; run < 300; run++) {
        final s = GameState();
        while (true) {
          final event = engine.eventFor(s);
          if (event == null) break;
          final report = engine.applyChoice(
            s,
            rnd.nextInt(event.choices.length),
          );
          expect(s.treasury, greaterThanOrEqualTo(0));
          expect(s.debt, greaterThanOrEqualTo(0));
          expect(s.sultan, inInclusiveRange(0, 100));
          expect(s.stability, inInclusiveRange(0, 100));
          expect(s.grain, inInclusiveRange(5, 60));
          if (report.ending != null) break;
        }
      }
    });
  });

  group('الدين الطارئ والتسديد', () {
    final engine = GameEngine();

    test('تسديد جزء من الدين من الخزينة', () {
      final s = GameState(treasury: 1000, debt: 600);
      final paid = engine.repayDebt(s, 400);
      expect(paid, equals(400));
      expect(s.treasury, equals(600));
      expect(s.debt, equals(200));
    });

    test('لا يسدد أكثر من الدين ولا أكثر من الخزينة', () {
      final a = GameState(treasury: 1000, debt: 600);
      expect(engine.repayDebt(a, 800), equals(600));
      expect(a.debt, equals(0));
      expect(a.treasury, equals(400));

      final b = GameState(treasury: 200, debt: 600);
      expect(engine.repayDebt(b, 500), equals(200));
      expect(b.treasury, equals(0));
      expect(b.debt, equals(400));
    });

    test('مبلغ صفر أو سالب لا يغير شيئا', () {
      final s = GameState(treasury: 1000, debt: 600);
      expect(engine.repayDebt(s, 0), equals(0));
      expect(engine.repayDebt(s, -50), equals(0));
      expect(s.treasury, equals(1000));
      expect(s.debt, equals(600));
    });
  });

  group('شروط النهاية', () {
    final engine = GameEngine();

    test('حملة جارية بدون نهاية', () {
      expect(engine.evaluate(GameState()), isNull);
    });

    test('عزل السلطان', () {
      final e = engine.evaluate(GameState(sultan: 30));
      expect(e!.type, equals(EndingType.deposed));
      expect(e.isVictory, isFalse);
    });

    test('ثورة عند انهيار الاستقرار', () {
      final e = engine.evaluate(GameState(stability: 30));
      expect(e!.type, equals(EndingType.revolt));
    });

    test('إفلاس عند بلوغ حد الدين', () {
      final e = engine.evaluate(GameState(debt: 8000));
      expect(e!.type, equals(EndingType.bankruptcy));
    });

    test('مجاعة عند بلوغ أقصى سعر للحبوب', () {
      final e = engine.evaluate(GameState(grain: 60));
      expect(e!.type, equals(EndingType.famine));
    });

    test('النجاة في نهاية الحملة بثلاث درجات', () {
      final n = engine.totalTurns;

      final gold = engine.evaluate(
        GameState(turn: n, sultan: 80, stability: 80, treasury: 5000),
      );
      expect(gold!.isVictory, isTrue);
      expect(gold.title, equals('عام ذهبي'));

      final hard = engine.evaluate(
        GameState(turn: n, sultan: 50, stability: 50, treasury: 1000),
      );
      expect(hard!.isVictory, isTrue);
      expect(hard.title, equals('عام عصيب ونجوت'));

      final barely = engine.evaluate(
        GameState(turn: n, sultan: 35, stability: 35, treasury: 0, debt: 6000),
      );
      expect(barely!.isVictory, isTrue);
      expect(barely.title, equals('نجوت بالكاد'));
    });

    test('الخسارة لها أولوية على النجاة', () {
      final e = engine.evaluate(
        GameState(turn: engine.totalTurns, sultan: 20, stability: 80),
      );
      expect(e!.type, equals(EndingType.deposed));
    });
  });

  group('توازن الحملة', () {
    test('توجد طريقة لعب تنهي الحملة بنجاح', () {
      final engine = GameEngine();
      expect(_canWin(engine, GameState()), isTrue);
    });

    test('اللعب العشوائي ينجح أحيانا ويفشل أحيانا', () {
      final engine = GameEngine();
      final rnd = Random(7);
      var wins = 0;
      const runs = 500;
      for (var i = 0; i < runs; i++) {
        final s = GameState();
        Ending? end;
        while (end == null) {
          final event = engine.eventFor(s)!;
          end = engine.applyChoice(s, rnd.nextInt(event.choices.length)).ending;
        }
        if (end.isVictory) wins++;
      }
      // ليست سهلة جدا ولا مستحيلة.
      expect(wins, greaterThan(runs * 0.3));
      expect(wins, lessThan(runs * 0.98));
    });
  });
}

/// يبحث بعمق عن أي تسلسل قرارات ينتهي بنجاة.
bool _canWin(GameEngine engine, GameState s) {
  final event = engine.eventFor(s);
  if (event == null) return engine.evaluate(s)?.isVictory ?? false;
  for (var i = 0; i < event.choices.length; i++) {
    final next = GameState(
      treasury: s.treasury,
      debt: s.debt,
      sultan: s.sultan,
      stability: s.stability,
      grain: s.grain,
      turn: s.turn,
    );
    final report = engine.applyChoice(next, i);
    final end = report.ending;
    if (end != null) {
      if (end.isVictory) return true;
      continue;
    }
    if (_canWin(engine, next)) return true;
  }
  return false;
}
