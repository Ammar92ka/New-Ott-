import 'package:flutter/material.dart';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../widgets/stat_card.dart';

/// شاشة ختام الحملة. تعيد true عند اختيار "لعبة جديدة" وإلا false أو null.
class EndScreen extends StatelessWidget {
  const EndScreen({
    super.key,
    required this.ending,
    required this.state,
    required this.totalTurns,
  });

  final Ending ending;
  final GameState state;
  final int totalTurns;

  @override
  Widget build(BuildContext context) {
    final win = ending.isVictory;
    final color = win ? AppColors.gold : AppColors.bad;
    final cards = <Widget>[
      StatCard(
        icon: Icons.account_balance_wallet,
        label: 'الخزينة',
        value: formatNumber(state.treasury),
      ),
      StatCard(
        icon: Icons.trending_down,
        label: 'الدين',
        value: formatNumber(state.debt),
      ),
      StatCard(
        icon: Icons.workspace_premium,
        label: 'رضا السلطان',
        value: '${state.sultan} / 100',
        progress: state.sultan / 100,
      ),
      StatCard(
        icon: Icons.balance,
        label: 'الاستقرار',
        value: '${state.stability} / 100',
        progress: state.stability / 100,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('نهاية الحملة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(
              win ? Icons.emoji_events : Icons.warning_amber,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              ending.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              win
                  ? 'أنهيت الأشهر الـ $totalTurns'
                  : 'انتهى حكمك بعد ${state.turn} من $totalTurns أشهر',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text(
              ending.description,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.8, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'ملخص الحملة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards) SizedBox(width: w, child: card),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'قراراتك (${state.history.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 4),
            for (final h in state.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(h.choice),
                subtitle: Text('${GameEngine.dateLabel(h.turn)} - ${h.event}'),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.restart_alt),
              label: const Text('لعبة جديدة'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.home_outlined),
              label: const Text('القائمة الرئيسية'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
