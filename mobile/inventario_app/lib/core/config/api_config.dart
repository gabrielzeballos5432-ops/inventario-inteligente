import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Android nativo (emulador): 10.0.2.2 apunta al host.
  // Escritorio y web: localhost. Puerto 8001 (8000 lo usa Laravel Herd).
  static final String baseUrl = _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8001'
          : 'http://localhost:8001');

  static const String login = '/api/auth/login';
  static const String inventario = '/api/inventario/';
  static const String historial = '/api/inventario/historial';
  static const String stockBajo = '/api/inventario/stock-bajo';
  static const String inferencia = '/api/inference/';
  static const String productos = '/api/productos/';
  static const String movimiento = '/api/inventario/movimiento';
  static const String reporteStock = '/api/reportes/stock';
  static const String reporteMovimientos = '/api/reportes/movimientos';
  static const String exportarStock = '/api/reportes/exportar-stock';
  static const String exportarMovimientos = '/api/reportes/exportar-movimientos';
}
