// Implementacion web de la base de datos local (sin SQLite).
// El cache de inventario y la cola de movimientos viven solo en memoria: se
// pierden al recargar la pagina. La cola persistente es de Android y Windows.
class LocalDbService {
  final Map<int, Map<String, dynamic>> _cache = {};
  final Map<String, Map<String, dynamic>> _cola = {};

  Future<void> guardarPendiente(Map<String, dynamic> fila) async {
    _cola[fila['clave'] as String] = Map.of(fila);
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final filas = _cola.values.map(Map<String, dynamic>.of).toList()
      ..sort(
        (a, b) => (a['creado_en'] as String).compareTo(b['creado_en'] as String),
      );
    return filas;
  }

  Future<void> actualizarPendiente(
    String clave, {
    required String estado,
    String? detalle,
  }) async {
    final fila = _cola[clave];
    if (fila == null) return;
    fila['estado'] = estado;
    fila['detalle'] = detalle;
  }

  Future<void> eliminarPendiente(String clave) async {
    _cola.remove(clave);
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
