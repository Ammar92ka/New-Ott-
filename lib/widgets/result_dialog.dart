import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../services/ai_provider.dart';
import '../services/economy.dart';
import '../services/settings_service.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import 'effect_chips.dart';

/// حوار نتيجة القرار: النص الرسمي، أثر القرار، تقرير الشهر، وسرد موسع اختياري.
class ResultDialog extends StatefulWidget {
  const ResultDialog({
    super.key,
    required this.report,
    required this.state,
    required this.dateLabel,
    required this.settings,
  });

  final TurnReport report;
  final GameState state;
  final String dateLabel;
  final AiSettings settings;

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> {
  bool _loading = false;
  String? _story;
  String? _error;

  Future<void> _askAi() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = aiProviderById(widget.settings.provider);
      final text = await provider.generate(
        prompt: buildNarrationPrompt(
          dateLabel: widget.dateLabel,
          event: widget.report.event,
          choice: widget.report.choice,
          state: widget.state,
        ),
        apiKey: widget.settings.apiKey,
        model: widget.settings.effectiveModel,
      );
      if (!mounted) return;
      setState(() {
        _story = text;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ غير متوقع أثناء توليد السرد.';
        _loading = false;
      });
    }
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AlertDialog(
      title: const Text('نتيجة القرار'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.choice.result,
              style: const TextStyle(height: 1.7, fontSize: 15),
            ),
            const SizedBox(height: 12),
            EffectChips(effects: r.choice.effects),
            const Divider(height: 28),
            const Text(
              'تقرير الشهر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 6),
            _row('إيراد الشهر بعد التسرب', formatSigned(r.revenue)),
            _row('نفقات الدولة', formatSigned(-r.expenses)),
            if (r.interest >= 0.5)
              _row(
                'فائدة الدين (تضاف للدين)',
                formatSigned(r.interest),
                color: AppColors.bad,
              ),
            if (r.borrowed > 0) ...[
              _row(
                'اقتراض طارئ لتغطية العجز',
                formatSigned(r.borrowed),
                color: AppColors.bad,
              ),
              Text(
                'نفدت الخزينة فاقترضت الدولة من الصيارفة بعمولة ${(EconomyRules.emergencyLoanFee * 100).round()}%، وانخفض رضا السلطان.',
                style: const TextStyle(
                  color: AppColors.bad,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
            if (r.grainUnrest > 0)
              _row(
                'غلاء الحبوب (الاستقرار)',
                formatSigned(-r.grainUnrest),
                color: AppColors.bad,
              ),
            if (r.debtUnrest > 0)
              _row(
                'ثقل الدين (الاستقرار)',
                formatSigned(-r.debtUnrest),
                color: AppColors.bad,
              ),
            _row(
              'إرهاق الحكم (السلطان والاستقرار)',
              formatSigned(-EconomyRules.monthlySultanDrift),
            ),
            if (widget.settings.hasKey) ...[
              const Divider(height: 28),
              if (_story == null && !_loading)
                OutlinedButton.icon(
                  onPressed: _askAi,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _error == null
                        ? 'سرد موسع بالذكاء الاصطناعي'
                        : 'أعد المحاولة',
                  ),
                ),
              if (_loading)
                const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Text('جاري كتابة السرد...'),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.bad,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.bad),
                      ),
                    ),
                  ],
                ),
              ],
              if (_story != null) ...[
                const Text(
                  'سرد موسع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _story!,
                  style: const TextStyle(height: 1.8, fontSize: 15),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(r.ending == null ? 'متابعة' : 'عرض النهاية'),
        ),
      ],
    );
  }
}
