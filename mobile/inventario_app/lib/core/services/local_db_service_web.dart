// Implementacion web de la base de datos local (sin SQLite).
// La cola de sincronizacion y el cache viven solo en memoria: en web la
// sesion siempre esta en linea con el backend, por lo que no se pierde nada
// relevante al recargar la pagina.
class LocalDbService {
  final List<Map<String, dynamic>> _cola = [];
  final Map<int, Map<String, dynamic>> _cache = {};
  int _siguienteId = 1;

  Future<void> encolarMovimiento(
    int productoId,
    String tipo,
    int cantidad,
  ) async {
    _cola.add({
      'id': _siguienteId++,
      'producto_id': productoId,
      'tipo': tipo,
      'cantidad': cantidad,
      'origen': 'offline',
      'creado_en': DateTime.now().toIso8601String(),
      'sincronizado': 0,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    return _cola.where((m) => m['sincronizado'] == 0).toList();
  }

  Future<void> marcarSincronizado(int id) async {
    for (final item in _cola) {
      if (item['id'] == id) {
        item['sincronizado'] = 1;
      }
    }
  }

  Future<void> cachearInventario(List<Map<String, dynamic>> productos) async {
    _cache.clear();
    for (final p in productos) {
      _cache[p['id'] as int] = {
        'producto_id': p['id'],
        'nombre': p['nombre'],
        'stock_actual': p['stock_actual'],
        'stock_minimo': p['stock_minimo'],
        'precio_venta': p['precio_venta'],
        'stock_bajo': p['stock_bajo'] == true ? 1 : 0,
        'actualizado_en': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCacheInventario() async {
    final items = _cache.values.toList()
      ..sort((a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));
    return items;
  }
}
