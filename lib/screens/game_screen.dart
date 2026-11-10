import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../services/economy.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../widgets/effect_chips.dart';
import '../widgets/result_dialog.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/stat_card.dart';
import 'end_screen.dart';

/// شاشة اللعب. تعرض الحالة والحدث والخيارات فقط، وكل القواعد في [GameEngine].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.initial});

  final GameState initial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = GameEngine();
  final SaveService _save = SaveService();
  final SettingsService _settingsService = SettingsService();

  late GameState _state;
  AiSettings _settings = const AiSettings();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _settingsService.load();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _manualSave() async {
    try {
      await _save.saveState(_state);
      if (!mounted) return;
      _snack('تم حفظ اللعبة');
    } catch (_) {
      if (!mounted) return;
      _snack('تعذر حفظ اللعبة');
    }
  }

  Future<void> _openSettings() async {
    final result = await showModalBottomSheet<AiSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      builder: (_) => AiSettingsSheet(initial: _settings),
    );
    if (!mounted) return;
    if (result != null) setState(() => _settings = result);
  }

  Future<bool> _confirm(GameChoice c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد القرار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            EffectChips(effects: c.effects),
            const SizedBox(height: 10),
            const Text(
              'هذا قرار مهم ولا يمكن التراجع عنه بعد تأكيده.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد القرار'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _choose(int index) async {
    if (_busy) return;
    final event = _engine.eventFor(_state);
    if (event == null) return;
    final choice = event.choices[index];

    if (choice.isMajor) {
      final ok = await _confirm(choice);
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    final dateLabel = GameEngine.dateLabel(_state.turn);
    final report = _engine.applyChoice(_state, index);
    final ending = report.ending;

    // حفظ تلقائي بعد كل قرار، وعند النهاية نحذف الحفظ لأن الحملة انتهت
    try {
      if (ending == null) {
        await _save.saveState(_state);
      } else {
        await _save.clear();
      }
    } catch (_) {
      if (mounted) _snack('تعذر الحفظ التلقائي');
    }
    if (!mounted) return;
    setState(() {});

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResultDialog(
        report: report,
        state: _state,
        dateLabel: dateLabel,
        settings: _settings,
      ),
    );
    if (!mounted) return;

    if (ending != null) {
      final restart = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => EndScreen(
            ending: ending,
            state: _state,
            totalTurns: _engine.totalTurns,
          ),
        ),
      );
      if (!mounted) return;
      if (restart == true) {
        setState(() {
          _state = GameState();
          _busy = false;
        });
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    setState(() => _busy = false);
  }

  Future<void> _repay() async {
    final paid = _engine.repayDebt(_state, 1000);
    if (paid <= 0) return;
    setState(() {});
    try {
      await _save.saveState(_state);
    } catch (_) {
      // الحفظ التلقائي سيحاول مرة أخرى بعد القرار التالي
    }
    if (!mounted) return;
    _snack('تم سداد ${formatNumber(paid)} من الدين');
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold),
  );

  Widget _buildStats() {
    final s = _state;
    final net = EconomyRules.monthlyNet(s.stability);
    final cards = <Widget>[
      StatCard(
        icon: Icons.account_balance_wallet,
        label: 'الخزينة',
        value: formatNumber(s.treasury),
      ),
      StatCard(
        icon: Icons.trending_down,
        label: 'الدين',
        value: formatNumber(s.debt),
        hint: 'حد الإفلاس ${formatNumber(EconomyRules.bankruptcyDebt)}',
        warn: s.debt >= EconomyRules.bankruptcyDebt * 0.6,
      ),
      StatCard(
        icon: Icons.workspace_premium,
        label: 'رضا السلطان',
        value: '${s.sultan} / 100',
        progress: s.sultan / 100,
        hint: 'الخسارة عند ${EconomyRules.sultanLossAt} أو أقل',
        warn: s.sultan <= EconomyRules.sultanLossAt + 10,
      ),
      StatCard(
        icon: Icons.balance,
        label: 'الاستقرار',
        value: '${s.stability} / 100',
        progress: s.stability / 100,
        hint: 'الخسارة عند ${EconomyRules.stabilityLossAt} أو أقل',
        warn: s.stability <= EconomyRules.stabilityLossAt + 10,
      ),
      StatCard(
        icon: Icons.grain,
        label: 'سعر الحبوب',
        value: s.grain.toStringAsFixed(1),
        hint: s.grain >= EconomyRules.grainWarn ? 'غلاء يهدد الاستقرار' : null,
        warn: s.grain >= EconomyRules.grainWarn,
      ),
      StatCard(
        icon: Icons.swap_vert,
        label: 'صافي الشهر',
        value: formatSigned(net),
        hint: 'إيراد ناقص نفقات، قبل قرارك',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 3 : 2;
        final w = (c.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }

  Widget _buildRepay() {
    if (_state.debt <= 0) return const SizedBox.shrink();
    final amount = math.min(1000.0, math.min(_state.debt, _state.treasury));
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: (_busy || amount < 1) ? null : _repay,
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            amount < 1
                ? 'لا يوجد مال لسداد الدين'
                : 'سداد ${formatNumber(amount)} من الدين',
          ),
        ),
      ),
    );
  }

  Widget _buildEvent(GameEvent e) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.place, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  e.place,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _label('المشهد'),
          const SizedBox(height: 4),
          Text(e.scene, style: const TextStyle(height: 1.8, fontSize: 16)),
          const SizedBox(height: 14),
          _label('المعضلة'),
          const SizedBox(height: 4),
          Text(e.dilemma, style: const TextStyle(height: 1.8, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildChoice(int i, GameChoice c) {
    const letters = ['أ', 'ب', 'ج', 'د'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _busy ? null : () => _choose(i),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                    child: Text(letters[i % letters.length]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (c.isMajor) ...[
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                size: 14,
                                color: AppColors.gold,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'قرار مهم',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        EffectChips(effects: c.effects),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final items = _state.history.reversed.toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text('سجل القرارات (${items.length})'),
        children: [
          if (items.isEmpty)
            const ListTile(dense: true, title: Text('لا توجد قرارات بعد'))
          else
            for (final h in items)
              ListTile(
                dense: true,
                title: Text(h.choice),
                subtitle: Text('${GameEngine.dateLabel(h.turn)} - ${h.event}'),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _engine.eventFor(_state);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('انتهت الحملة')),
      );
    }
    final total = _engine.totalTurns;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              GameEngine.dateLabel(_state.turn),
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'الجولة ${_state.turn + 1} من $total',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'حفظ اللعبة',
            icon: const Icon(Icons.save_outlined),
            onPressed: _busy ? null : _manualSave,
          ),
          IconButton(
            tooltip: 'الذكاء الاصطناعي',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _busy ? null : _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _state.turn / total,
                minHeight: 6,
                color: AppColors.gold,
                backgroundColor: AppColors.cardBorder,
              ),
            ),
            const SizedBox(height: 12),
            _buildStats(),
            _buildRepay(),
            const SizedBox(height: 16),
            _buildEvent(event),
            const SizedBox(height: 16),
            _label('ما قرارك؟'),
            const SizedBox(height: 8),
            for (var i = 0; i < event.choices.length; i++)
              _buildChoice(i, event.choices[i]),
            const SizedBox(height: 8),
            _buildHistory(),
          ],
        ),
      ),
    );
  }
}
