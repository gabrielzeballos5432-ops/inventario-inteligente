// Implementacion web de la base de datos local (sin SQLite).
// El cache de inventario vive solo en memoria: en web la sesion siempre esta
// en linea con el backend, por lo que no se pierde nada al recargar la pagina.
class LocalDbService {
  final Map<int, Map<String, dynamic>> _cache = {};

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
