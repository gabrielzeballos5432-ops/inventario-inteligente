class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String login = '/api/auth/login';
  static const String inventario = '/api/inventario/';
  static const String historial = '/api/inventario/historial';
  static const String stockBajo = '/api/inventario/stock-bajo';
  static const String inferencia = '/api/inference/';
  static const String productos = '/api/productos/';
  static const String movimiento = '/api/inventario/movimiento';
}
