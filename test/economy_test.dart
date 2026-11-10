import 'package:flutter_test/flutter_test.dart';
import 'package:ottoman_empire_1800/services/economy.dart';

void main() {
  group('EconomyRules', () {
    test('الإيراد يرتفع كلما ارتفع الاستقرار', () {
      expect(
        EconomyRules.monthlyRevenue(80),
        greaterThan(EconomyRules.monthlyRevenue(40)),
      );
      expect(EconomyRules.monthlyRevenue(100), closeTo(1275, 0.001));
      expect(EconomyRules.monthlyRevenue(0), closeTo(765, 0.001));
    });

    test('النفقات أكبر من الإيراد حتى عند أعلى استقرار', () {
      // لذلك لا تكفي القرارات الاقتصادية وحدها؛ اللاعب يحتاج تدبيرا مستمرا.
      expect(EconomyRules.monthlyNet(100), closeTo(-175, 0.001));
    });

    test('فائدة الدين شهرية وليست على كل قرار بنسبة ثابتة', () {
      // 15% سنويا = 1.25% شهريا
      expect(EconomyRules.monthlyInterest(1200), closeTo(15, 0.001));
      expect(EconomyRules.monthlyInterest(0), equals(0));
    });

    test('غلاء الحبوب يخصم من الاستقرار على درجات', () {
      expect(EconomyRules.grainUnrest(29.9), equals(0));
      expect(EconomyRules.grainUnrest(30), equals(2));
      expect(EconomyRules.grainUnrest(44.9), equals(2));
      expect(EconomyRules.grainUnrest(45), equals(4));
    });

    test('ثقل الدين يخصم من الاستقرار على درجات', () {
      expect(EconomyRules.debtUnrest(0), equals(0));
      expect(EconomyRules.debtUnrest(3199), equals(0));
      expect(EconomyRules.debtUnrest(3200), equals(1));
      expect(EconomyRules.debtUnrest(6000), equals(2));
    });
  });
}
