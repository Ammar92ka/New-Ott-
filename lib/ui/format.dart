/// عزل الأرقام عن اتجاه النص حتى تظهر علامة السالب في مكانها الصحيح.
String ltr(String s) => '\u2066$s\u2069';

/// رقم بفواصل الآلاف، مثل 12,000.
String formatNumber(num v) {
  final r = v.round();
  final digits = r.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return ltr(r < 0 ? '-$buf' : buf.toString());
}

/// رقم بإشارة صريحة، مثل +800 أو -1,200.
String formatSigned(num v) {
  final r = v.round();
  if (r == 0) return ltr('0');
  final digits = formatNumber(r.abs())
      .replaceAll('\u2066', '')
      .replaceAll('\u2069', '');
  return ltr(r > 0 ? '+$digits' : '-$digits');
}
