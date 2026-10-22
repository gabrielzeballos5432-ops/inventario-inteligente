import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String prefsKeyServidor = 'api_base_url';

  static String? _servidorGuardado;

  // Android nativo (emulador): 10.0.2.2 apunta al host.
  // Escritorio y web: localhost. Puerto 8000.
  static String get _valorPorDefecto => _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000');

  /// URL base del backend. El valor guardado desde "Configurar servidor"
  /// tiene prioridad sobre el valor compilado (permite cambiar la IP del
  /// PC sin volver a compilar la app).
  static String get baseUrl => _servidorGuardado ?? _valorPorDefecto;

  /// Debe llamarse una sola vez en main() antes de runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _servidorGuardado = prefs.getString(prefsKeyServidor);
  }

  /// Guarda la URL del backend (o la limpia si [url] viene vacia).
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final limpia = url.trim();
    if (limpia.isEmpty) {
      _servidorGuardado = null;
      await prefs.remove(prefsKeyServidor);
    } else {
      final normalizada = normalizar(limpia);
      _servidorGuardado = normalizada;
      await prefs.setString(prefsKeyServidor, normalizada);
    }
  }

  /// Agrega el esquema si falta y elimina la barra final.
  static String normalizar(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static const String login = '/api/auth/login';
  static const String inventario = '/api/inventario/';
  static const String historial = '/api/inventario/historial';
  static const String stockBajo = '/api/inventario/stock-bajo';
  static const String inferencia = '/api/inference/';
  static const String productos = '/api/productos/';
  static const String movimiento = '/api/inventario/movimiento';

  /// Varios movimientos del mismo tipo en una sola llamada (recepcion de
  /// mercaderia). El backend guarda todo o nada: si una fila falla no guarda
  /// ninguna y responde 400 con el rechazo de cada fila.
  static const String movimientoLote = '/api/inventario/movimientos/lote';
  static const String reporteStock = '/api/reportes/stock';
  static const String reporteMovimientos = '/api/reportes/movimientos';
  static const String exportarStock = '/api/reportes/exportar-stock';
  static const String exportarMovimientos = '/api/reportes/exportar-movimientos';
  static const String valorizacion = '/api/reportes/valorizacion';
  static const String salud = '/api/health';
}
