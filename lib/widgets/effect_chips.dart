import 'package:flutter/material.dart';

import '../models/game_event.dart';
import '../ui/format.dart';
import '../ui/theme.dart';

/// يعرض أثر القرار على المؤشرات: سهم واسم وقيمة، بلون أخضر للخير وأحمر للضرر.
/// السهم والإشارة يوصلان المعنى حتى بدون الاعتماد على اللون.
class EffectChips extends StatelessWidget {
  const EffectChips({super.key, required this.effects});

  final Effects effects;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    void add(String label, num value, {required bool higherIsBetter}) {
      if (value == 0) return;
      final up = value > 0;
      final good = up == higherIsBetter;
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: good ? AppColors.goodBg : AppColors.badBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: good ? AppColors.good : AppColors.bad,
              ),
              const SizedBox(width: 4),
              Text(
                '$label ${formatSigned(value)}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    add('الخزينة', effects.treasury, higherIsBetter: true);
    add('الدين', effects.debt, higherIsBetter: false);
    add('رضا السلطان', effects.sultan, higherIsBetter: true);
    add('الاستقرار', effects.stability, higherIsBetter: true);
    add('سعر الحبوب', effects.grain, higherIsBetter: false);

    if (chips.isEmpty) {
      return const Text(
        'بلا أثر مباشر',
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
      );
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}
