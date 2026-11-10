/// قواعد اقتصاد الدولة. كل الأرقام هنا في مكان واحد حتى تسهل مراجعتها واختبارها.
///
/// كل جولة تساوي شهرا واحدا. بعد تنفيذ القرار يحدث التالي بالترتيب:
/// 1) تُضاف فائدة الشهر على الدين (سنويا [annualInterest] مقسومة على 12).
/// 2) تُحسب إيرادات الشهر (تتأثر بالاستقرار) وتُخصم نفقات الدولة الثابتة.
/// 3) إن نزلت الخزينة تحت الصفر تقترض الدولة العجز بعمولة [emergencyLoanFee]
///    وتصبح الخزينة صفرا (وليس رقما ثابتا).
/// 4) غلاء الحبوب وكثرة الدين يخصمان من الاستقرار.
class EconomyRules {
  EconomyRules._();

  /// إيرادات الدولة الشهرية قبل التسرب عند استقرار 100.
  static const double baseRevenue = 1500;

  /// نسبة التسرب بسبب فساد الملتزمين والولاة.
  static const double corruptionLeak = 0.15;

  /// نفقات الدولة الثابتة شهريا (الجيش، القصر، الرواتب).
  static const double baseExpenses = 1450;

  /// الفائدة السنوية على الدين.
  static const double annualInterest = 0.15;

  /// عمولة الصيارفة على الاقتراض الطارئ عند العجز.
  static const double emergencyLoanFee = 0.10;

  /// إذا وصل الدين لهذا الحد تفلس الدولة وتنتهي اللعبة.
  static const double bankruptcyDebt = 8000;

  /// إرهاق الحكم: كل شهر ينقص رضا السلطان والاستقرار قليلا إن لم تنجز شيئا.
  static const int monthlySultanDrift = 2;
  static const int monthlyStabilityDrift = 2;

  /// تنتهي اللعبة إذا نزل رضا السلطان أو الاستقرار إلى هذا الحد أو أقل.
  static const int sultanLossAt = 30;
  static const int stabilityLossAt = 30;

  /// سعر حبوب يسبب هلعا (استقرار -2 شهريا) وسعر يسبب مجاعة (-4).
  static const double grainWarn = 30;
  static const double grainDanger = 45;

  /// إيراد الشهر بعد التسرب. الاستقرار الأعلى يعني جباية أفضل.
  static double monthlyRevenue(int stability) =>
      baseRevenue * (0.6 + 0.4 * stability / 100) * (1 - corruptionLeak);

  /// صافي الشهر قبل الفوائد: الإيراد ناقص النفقات.
  static double monthlyNet(int stability) =>
      monthlyRevenue(stability) - baseExpenses;

  /// فائدة الشهر على دين معين.
  static double monthlyInterest(double debt) => debt * annualInterest / 12;

  /// خصم الاستقرار الشهري بسبب غلاء الحبوب.
  static int grainUnrest(double grainPrice) {
    if (grainPrice >= grainDanger) return 4;
    if (grainPrice >= grainWarn) return 2;
    return 0;
  }

  /// خصم الاستقرار الشهري بسبب ثقل الدين.
  static int debtUnrest(double debt) {
    if (debt >= bankruptcyDebt * 0.75) return 2;
    if (debt >= bankruptcyDebt * 0.4) return 1;
    return 0;
  }
}
