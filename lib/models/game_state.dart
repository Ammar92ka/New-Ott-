/// سطر واحد في سجل القرارات.
class HistoryEntry {
  final int turn;
  final String event;
  final String choice;

  const HistoryEntry({
    required this.turn,
    required this.event,
    required this.choice,
  });

  Map<String, dynamic> toJson() => {
    'turn': turn,
    'event': event,
    'choice': choice,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    turn: (json['turn'] as num?)?.toInt() ?? 0,
    event: json['event'] as String? ?? '',
    choice: json['choice'] as String? ?? '',
  );
}

/// حالة اللعبة الكاملة. تُحفظ وتُستعاد كاملة.
class GameState {
  static const int saveVersion = 1;

  double treasury;
  double debt;
  int sultan;
  int stability;
  double grain;

  /// عدد القرارات المتخذة حتى الآن (وهو أيضا رقم الحدث الحالي).
  int turn;
  List<HistoryEntry> history;

  GameState({
    this.treasury = 12000,
    this.debt = 0,
    this.sultan = 65,
    this.stability = 63,
    this.grain = 12,
    this.turn = 0,
    List<HistoryEntry>? history,
  }) : history = history ?? <HistoryEntry>[];

  Map<String, dynamic> toJson() => {
    'version': saveVersion,
    'treasury': treasury,
    'debt': debt,
    'sultan': sultan,
    'stability': stability,
    'grain': grain,
    'turn': turn,
    'history': history.map((h) => h.toJson()).toList(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    double num0(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    int int0(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;

    final rawHistory = json['history'];
    final history = <HistoryEntry>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map) {
          history.add(HistoryEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return GameState(
      treasury: num0('treasury', 12000),
      debt: num0('debt', 0).clamp(0, double.infinity).toDouble(),
      sultan: int0('sultan', 65).clamp(0, 100),
      stability: int0('stability', 63).clamp(0, 100),
      grain: num0('grain', 12).clamp(5, 60).toDouble(),
      turn: int0('turn', 0).clamp(0, 1000),
      history: history,
    );
  }

  GameState copy() => GameState.fromJson(toJson());
}
