/// Formatage partagé des montants et des dates affichés dans l'application.
library;

num? parseAmount(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  return num.tryParse(raw.toString());
}

/// `12500` -> `12 500 FCFA`.
String formatPrice(dynamic raw, {String fallback = 'Prix non renseigné'}) {
  final value = parseAmount(raw);
  if (value == null) return fallback;
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer FCFA';
}

/// `2026-10-06T09:30:00Z` -> `06/10/2026`.
String formatDate(dynamic raw, {bool withTime = false}) {
  final date = raw is DateTime
      ? raw.toLocal()
      : DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (date == null) return raw?.toString() ?? '';
  String two(int value) => value.toString().padLeft(2, '0');
  final day = '${two(date.day)}/${two(date.month)}/${date.year}';
  return withTime ? '$day à ${two(date.hour)}:${two(date.minute)}' : day;
}

/// Référence courte lisible d'une commande : `#3F2A9C1B`.
String shortOrderRef(dynamic id) {
  final value = id?.toString() ?? '';
  return '#${(value.length > 8 ? value.substring(0, 8) : value).toUpperCase()}';
}
