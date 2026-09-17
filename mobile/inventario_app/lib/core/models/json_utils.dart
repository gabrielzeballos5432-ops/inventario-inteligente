/// Convierte a double tolerando que el backend envie numeros o strings.
/// Los campos Decimal de Pydantic se serializan como string ("8.00").
double parseDouble(dynamic raw, [double fallback = 0]) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? fallback;
  return fallback;
}

/// Convierte a int tolerando numeros o strings.
int parseInt(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}
