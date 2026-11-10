import 'dart:math' as math;

import '../data/events.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../services/economy.dart';

enum EndingType { deposed, revolt, bankruptcy, famine, survived }

/// نهاية الحملة (خسارة أو نجاة).
class Ending {
  final EndingType type;
  final String title;
  final String description;

  const Ending(this.type, this.title, this.description);

  bool get isVictory => type == EndingType.survived;
}

/// ملخص ما حدث في الجولة: يعرضه حوار النتيجة.
class TurnReport {
  final GameEvent event;
  final GameChoice choice;
  final double revenue;
  final double expenses;
  final double interest;
  final double borrowed;
  final int grainUnrest;
  final int debtUnrest;
  final Ending? ending;

  const TurnReport({
    required this.event,
    required this.choice,
    required this.revenue,
    required this.expenses,
    required this.interest,
    required this.borrowed,
    required this.grainUnrest,
    required this.debtUnrest,
    required this.ending,
  });

  double get monthlyNet => revenue - expenses;
}

/// قواعد اللعبة بلا أي اعتماد على الواجهة، لذلك يسهل اختبارها.
class GameEngine {
  final List<GameEvent> events;

  GameEngine([List<GameEvent>? events]) : events = events ?? gameEvents;

  static const List<String> _months = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  /// تاريخ الجولة، مثلا "كانون الثاني 1800". الجولة 0 هي يناير 1800.
  static String dateLabel(int turn) {
    final t = turn < 0 ? 0 : turn;
    return '${_months[t % 12]} ${1800 + t ~/ 12}';
  }

  int get totalTurns => events.length;

  /// الحدث الحالي، أو null إذا انتهت الحملة.
  GameEvent? eventFor(GameState s) =>
      s.turn >= 0 && s.turn < events.length ? events[s.turn] : null;

  int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  /// ينفذ الخيار رقم [choiceIndex] ويحدّث [s] في مكانه ثم يعيد تقريرا بما حدث.
  TurnReport applyChoice(GameState s, int choiceIndex) {
    final event = eventFor(s);
    if (event == null) {
      throw StateError('انتهت الحملة ولا يوجد حدث حالي.');
    }
    if (choiceIndex < 0 || choiceIndex >= event.choices.length) {
      throw RangeError.index(choiceIndex, event.choices, 'choiceIndex');
    }
    final choice = event.choices[choiceIndex];
    final fx = choice.effects;

    // 1) أثر القرار نفسه
    s.treasury += fx.treasury;
    s.debt = math.max(0.0, s.debt + fx.debt);
    s.sultan = _clampInt(s.sultan + fx.sultan, 0, 100);
    s.stability = _clampInt(s.stability + fx.stability, 0, 100);
    s.grain = (s.grain + fx.grain).clamp(5.0, 60.0).toDouble();

    // 2) فائدة الدين ثم إيرادات ونفقات الشهر
    final interest = EconomyRules.monthlyInterest(s.debt);
    s.debt += interest;
    final revenue = EconomyRules.monthlyRevenue(s.stability);
    final expenses = EconomyRules.baseExpenses;
    s.treasury += revenue - expenses;

    // 3) عجز الخزينة: اقتراض طارئ بعمولة، والخزينة تصبح صفرا
    var borrowed = 0.0;
    if (s.treasury < 0) {
      final shortfall = -s.treasury;
      borrowed = shortfall * (1 + EconomyRules.emergencyLoanFee);
      s.debt += borrowed;
      s.treasury = 0;
      // انكشاف العجز أمام السلطان
      s.sultan = _clampInt(s.sultan - 2, 0, 100);
    }

    // 4) غلاء الحبوب وثقل الدين يضغطان على الاستقرار
    final grainUnrest = EconomyRules.grainUnrest(s.grain);
    final debtUnrest = EconomyRules.debtUnrest(s.debt);
    s.stability = _clampInt(
      s.stability -
          grainUnrest -
          debtUnrest -
          EconomyRules.monthlyStabilityDrift,
      0,
      100,
    );
    s.sultan = _clampInt(s.sultan - EconomyRules.monthlySultanDrift, 0, 100);

    s.history.add(
      HistoryEntry(turn: s.turn, event: event.title, choice: choice.text),
    );
    s.turn++;

    return TurnReport(
      event: event,
      choice: choice,
      revenue: revenue,
      expenses: expenses,
      interest: interest,
      borrowed: borrowed,
      grainUnrest: grainUnrest,
      debtUnrest: debtUnrest,
      ending: evaluate(s),
    );
  }

  /// يسدد جزءا من الدين من الخزينة بدون إنهاء الجولة. يعيد المبلغ المسدد فعلا.
  double repayDebt(GameState s, double amount) {
    if (amount <= 0) return 0;
    final paid = math.min(amount, math.min(s.debt, s.treasury));
    if (paid <= 0) return 0;
    s.treasury -= paid;
    s.debt -= paid;
    return paid;
  }

  /// هل انتهت الحملة؟ يعيد null إذا ما زالت مستمرة.
  Ending? evaluate(GameState s) {
    if (s.sultan <= EconomyRules.sultanLossAt) {
      return const Ending(
        EndingType.deposed,
        'عزلك السلطان',
        'فقدت ثقة السلطان تماما. صدر الفرمان بعزلك من منصب الصدر الأعظم، وانتهى عهدك في الحكم.',
      );
    }
    if (s.stability <= EconomyRules.stabilityLossAt) {
      return const Ending(
        EndingType.revolt,
        'ثورة في العاصمة',
        'انهار الاستقرار. خرج الناس إلى الشوارع واجتاح الغاضبون الديوان، وسقطت حكومتك.',
      );
    }
    if (s.debt >= EconomyRules.bankruptcyDebt) {
      return const Ending(
        EndingType.bankruptcy,
        'إفلاس الدولة',
        'ثقلت الديون حتى عجزت الدولة عن السداد. استولى الدائنون على موارد الجمارك وانتهت حكومتك.',
      );
    }
    if (s.grain >= 60) {
      return const Ending(
        EndingType.famine,
        'مجاعة وتمرد',
        'بلغ سعر الحبوب حدا لا يطاق. جاع الناس وثاروا، وحملوك مسؤولية المجاعة.',
      );
    }
    if (s.turn >= events.length) {
      return _survivedEnding(s);
    }
    return null;
  }

  Ending _survivedEnding(GameState s) {
    final net = s.treasury - s.debt;
    final avg = (s.sultan + s.stability) / 2;
    if (avg >= 60 && net >= 2000) {
      return const Ending(
        EndingType.survived,
        'عام ذهبي',
        'أنهيت العام بخزينة قوية وسلطان راض وشعب مستقر. صارت حكومتك مضرب المثل في الباب العالي.',
      );
    }
    if (avg >= 40 && net >= -3000) {
      return const Ending(
        EndingType.survived,
        'عام عصيب ونجوت',
        'مر العام بأزمات كثيرة، لكنك حافظت على منصبك وعلى تماسك الدولة. أمامك عمل كبير في العام القادم.',
      );
    }
    return const Ending(
      EndingType.survived,
      'نجوت بالكاد',
      'بقيت في منصبك لكن الدولة تترنح: ديون ثقيلة وسلطان قلق وشعب متعب. العام القادم سيكون أصعب.',
    );
  }
}
