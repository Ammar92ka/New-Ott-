/// أثر قرار واحد على مؤشرات الدولة.
///
/// القيم الموجبة تزيد المؤشر والسالبة تنقصه. في [grain] القيمة الموجبة
/// تعني ارتفاع سعر الحبوب (وهذا سيئ للدولة).
class Effects {
  final double treasury;
  final double debt;
  final int sultan;
  final int stability;
  final double grain;

  const Effects({
    this.treasury = 0,
    this.debt = 0,
    this.sultan = 0,
    this.stability = 0,
    this.grain = 0,
  });
}

/// خيار واحد من خيارات الحدث.
class GameChoice {
  final String text;
  final String result;
  final Effects effects;

  const GameChoice({
    required this.text,
    required this.result,
    required this.effects,
  });

  /// قرار مهم يحتاج تأكيدا قبل التنفيذ (كلفة كبيرة أو أثر كبير).
  bool get isMajor =>
      effects.treasury <= -800 ||
      effects.debt >= 1000 ||
      effects.sultan.abs() >= 7 ||
      effects.stability.abs() >= 6;
}

/// حدث واحد في الحملة، له ثلاثة خيارات عادة.
class GameEvent {
  final String id;
  final String title;
  final String place;
  final String scene;
  final String dilemma;
  final List<GameChoice> choices;

  const GameEvent({
    required this.id,
    required this.title,
    required this.place,
    required this.scene,
    required this.dilemma,
    required this.choices,
  });
}
