import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/models/game_state.dart';

void main() {
  group('GameState الحفظ والاستعادة', () {
    test('القيم الابتدائية', () {
      final s = GameState();
      expect(s.treasury, equals(12000));
      expect(s.debt, equals(0));
      expect(s.sultan, equals(65));
      expect(s.stability, equals(63));
      expect(s.turn, equals(0));
      expect(s.history, isEmpty);
    });

    test('تحفظ وتستعاد كاملة بما فيها السجل والجولة', () {
      final s = GameState(
        treasury: 5432.5,
        debt: 1200,
        sultan: 71,
        stability: 48,
        grain: 21.5,
        turn: 4,
        history: [
          const HistoryEntry(turn: 0, event: 'حدث أول', choice: 'خيار أول'),
          const HistoryEntry(turn: 1, event: 'حدث ثان', choice: 'خيار ثان'),
        ],
      );
      final back = GameState.fromJson(s.toJson());
      expect(back.treasury, equals(5432.5));
      expect(back.debt, equals(1200));
      expect(back.sultan, equals(71));
      expect(back.stability, equals(48));
      expect(back.grain, equals(21.5));
      expect(back.turn, equals(4));
      expect(back.history.length, equals(2));
      expect(back.history[1].event, equals('حدث ثان'));
      expect(back.history[1].choice, equals('خيار ثان'));
    });

    test('الحقول الناقصة تأخذ قيما افتراضية', () {
      final s = GameState.fromJson(<String, dynamic>{});
      expect(s.treasury, equals(12000));
      expect(s.sultan, equals(65));
      expect(s.turn, equals(0));
      expect(s.history, isEmpty);
    });

    test('القيم الخارجة عن الحدود تُقص عند الاستعادة', () {
      final s = GameState.fromJson(<String, dynamic>{
        'sultan': 500,
        'stability': -20,
        'debt': -50,
        'grain': 999,
      });
      expect(s.sultan, equals(100));
      expect(s.stability, equals(0));
      expect(s.debt, equals(0));
      expect(s.grain, equals(60));
    });

    test('النسخة مستقلة عن الأصل', () {
      final s = GameState();
      final c = s.copy();
      c.history.add(const HistoryEntry(turn: 0, event: 'x', choice: 'y'));
      c.treasury = 1;
      expect(s.history, isEmpty);
      expect(s.treasury, equals(12000));
    });

    test('كل لعبة جديدة لها سجل خاص بها', () {
      final a = GameState();
      final b = GameState();
      a.history.add(const HistoryEntry(turn: 0, event: 'x', choice: 'y'));
      expect(b.history, isEmpty);
    });
  });
}
