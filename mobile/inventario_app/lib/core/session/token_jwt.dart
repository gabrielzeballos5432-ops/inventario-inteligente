import 'dart:convert';

/// Fecha de vencimiento (`exp`) de un token JWT, o null si no se puede leer.
///
/// No verifica la firma: eso lo hace el backend. Aquí solo interesa saber
/// cuándo vence para no entrar con una sesión muerta ni dejar vencer la de
/// alguien que está trabajando.
DateTime? vencimientoToken(String? token) {
  if (token == null) return null;
  final partes = token.split('.');
  if (partes.length != 3) return null;
  try {
    final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final exp = (jsonDecode(carga) as Map<String, dynamic>)['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// El token ya venció (o vence en los próximos segundos de margen). Un token
/// que no se puede leer se trata como vencido.
bool tokenVencido(String? token, {DateTime? ahora, Duration margen = const Duration(seconds: 30)}) {
  final vence = vencimientoToken(token);
  if (vence == null) return true;
  return !(ahora ?? DateTime.now().toUtc()).add(margen).isBefore(vence);
}
