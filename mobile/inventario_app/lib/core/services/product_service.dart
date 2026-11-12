import '../config/api_config.dart';
import '../models/product.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';

class ProductService {
  final ApiClient _apiClient;

  ProductService(this._apiClient);

  Future<List<ProductoConStock>> obtenerInventario() async {
    final json =
        await _apiClient.getJson(ApiConfig.inventario) as List<dynamic>;
    return json
        .map((item) =>
            ProductoConStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> fetchProducts() async {
    final json =
        await _apiClient.getJson(ApiConfig.productos) as List<dynamic>;
    return json
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> buscarProductos({
    String? texto,
    int? categoriaId,
  }) async {
    final query = <String, String>{
      if (texto != null && texto.isNotEmpty) 'texto': texto,
      if (categoriaId != null) 'categoria_id': '$categoriaId',
    };
    final json = await _apiClient.getJson(ApiConfig.productos, query: query)
        as List<dynamic>;
    return json
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductoConStock>> obtenerStockBajo() async {
    final json =
        await _apiClient.getJson(ApiConfig.stockBajo) as List<dynamic>;
    return json
        .map((item) =>
            ProductoConStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createProduct(Map<String, dynamic> payload) async {
    final json = await _apiClient.postJson(ApiConfig.productos, payload);
    return Product.fromJson(json as Map<String, dynamic>);
  }

  Future<void> registrarVenta(Map<String, dynamic> payload) async {
    await _apiClient.postJson(ApiConfig.ventas, payload);
  }

  Future<Product> updateProduct(
      int productId, Map<String, dynamic> payload) async {
    final json =
        await _apiClient.putJson('${ApiConfig.productos}$productId', payload);
    return Product.fromJson(json as Map<String, dynamic>);
  }

  Future<Product> deactivateProduct(int productId) async {
    final json =
        await _apiClient.deleteJson('${ApiConfig.productos}$productId');
    return Product.fromJson(json as Map<String, dynamic>);
  }

  Future<Product> updateStockMinimo(int productId, int stockMinimo) async {
    final json = await _apiClient
        .patchJson('${ApiConfig.productos}$productId/stock-minimo',
            {'stock_minimo': stockMinimo});
    return Product.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Categoria>> fetchCategorias() async {
    final json =
        await _apiClient.getJson('/api/categorias/') as List<dynamic>;
    return json
        .map((item) => Categoria.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Categoria> createCategoria(Map<String, dynamic> payload) async {
    final json = await _apiClient.postJson('/api/categorias/', payload);
    return Categoria.fromJson(json as Map<String, dynamic>);
  }

  /// Renombra una categoria. El backend rechaza el nombre si otra categoria
  /// activa ya lo usa.
  Future<Categoria> actualizarCategoria(int id,
      {String? nombre, int? padreId}) async {
    final payload = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (padreId != null) 'padre_id': padreId,
    };
    final json = await _apiClient.putJson('/api/categorias/$id', payload);
    return Categoria.fromJson(json as Map<String, dynamic>);
  }

  /// Desactiva una categoria. El backend la marca como inactiva en lugar de
  /// borrarla, para no romper los productos que ya la referencian. El nombre
  /// sigue reservado, asi que volver a crearla con el mismo nombre la
  /// reactiva en vez de crear una fila nueva.
  Future<bool> desactivarCategoria(int id) async {
    final json = await _apiClient.deleteJson('/api/categorias/$id');
    return json is Map<String, dynamic> ? (json['activo'] as bool? ?? false) : true;
  }

  Future<Movimiento?> registrarMovimiento({
    required int productoId,
    required String tipo,
    required int cantidad,
    required int razonId,
    String origen = 'manual',
  }) async {
    final json = await _apiClient.postJson(
      ApiConfig.movimiento,
      {
        'producto_id': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
        'origen': origen,
        'razon_movimiento_id': razonId,
      },
    );
    if (json == null) return null;
    return Movimiento.fromJson(json as Map<String, dynamic>);
  }

  /// Registra varios movimientos del mismo tipo en una sola llamada.
  ///
  /// El backend guarda todo o nada: si rechaza una fila responde 400 con el
  /// detalle de cada fila ("Fila 2 (Esmalte Rojo 30): no hay stock
  /// suficiente: disponible 3"), que sube en ApiException.detalle para que el
  /// dialogo lo muestre sin perder el nombre del producto y el numero de fila.
  Future<ResultadoLote> registrarLote({
    required String tipo,
    required List<({int productoId, int cantidad})> items,
    int? razonId,
    int? sucursalDestinoId,
    String origen = 'manual',
    int? sesionId,
  }) async {
    final json = await _apiClient.postJson(
      ApiConfig.movimientoLote,
      {
        'tipo': tipo,
        // Obligatoria en lo manual: el backend la rechaza si falta. Con
        // origen "ia" el backend asigna sola la razon "Deteccion IA".
        if (razonId != null) 'razon_movimiento_id': razonId,
        'origen': origen,
        if (sesionId != null) 'sesion_id': sesionId,
        // Solo en un traspaso ("Salida a sucursal"): el backend registra la
        // entrada en esta sucursal en la misma transaccion.
        if (sucursalDestinoId != null) 'sucursal_destino_id': sucursalDestinoId,
        'items': items
            .map((i) => {'producto_id': i.productoId, 'cantidad': i.cantidad})
            .toList(),
      },
    );
    return ResultadoLote.fromJson(json as Map<String, dynamic>);
  }

  /// Filtro de los reportes: `sucursalId` null = todas las sucursales.
  static Map<String, String> _filtroSucursal(int? sucursalId) =>
      {if (sucursalId != null) 'sucursal_id': '$sucursalId'};

  Future<List<ProductoConStock>> reporteStock({int? sucursalId}) async {
    final json = await _apiClient.getJson(
      ApiConfig.reporteStock,
      query: _filtroSucursal(sucursalId),
    ) as List<dynamic>;
    return json
        .map((item) =>
            ProductoConStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Movimiento>> reporteMovimientos({
    String? fechaDesde,
    String? fechaHasta,
    int? sucursalId,
  }) async {
    final query = <String, String>{
      if (fechaDesde != null) 'fecha_desde': fechaDesde,
      if (fechaHasta != null) 'fecha_hasta': fechaHasta,
      ..._filtroSucursal(sucursalId),
    };
    final json = await _apiClient.getJson(
      ApiConfig.reporteMovimientos,
      query: query,
    ) as List<dynamic>;
    return json
        .map((item) => Movimiento.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<int>> exportarStock({String formato = 'csv', int? sucursalId}) async {
    return _apiClient.getBytes(ApiConfig.exportarStock,
        query: {'formato': formato, ..._filtroSucursal(sucursalId)});
  }

  Future<List<int>> exportarMovimientos({
    String formato = 'csv',
    int? sucursalId,
  }) async {
    return _apiClient.getBytes(ApiConfig.exportarMovimientos,
        query: {'formato': formato, ..._filtroSucursal(sucursalId)});
  }

  Future<ValorizacionInventario> valorizacion({int? sucursalId}) async {
    final json = await _apiClient.getJson(
      ApiConfig.valorizacion,
      query: _filtroSucursal(sucursalId),
    );
    return ValorizacionInventario.fromJson(json as Map<String, dynamic>);
  }
}