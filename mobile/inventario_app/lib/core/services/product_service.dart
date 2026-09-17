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

  Future<Movimiento?> registrarMovimiento({
    required int productoId,
    required String tipo,
    required int cantidad,
    String origen = 'manual',
  }) async {
    final json = await _apiClient.postJson(
      ApiConfig.movimiento,
      {
        'producto_id': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
        'origen': origen,
      },
    );
    if (json == null) return null;
    return Movimiento.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ProductoConStock>> reporteStock() async {
    final json =
        await _apiClient.getJson(ApiConfig.reporteStock) as List<dynamic>;
    return json
        .map((item) =>
            ProductoConStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Movimiento>> reporteMovimientos({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final query = <String, String>{
      if (fechaDesde != null) 'fecha_desde': fechaDesde,
      if (fechaHasta != null) 'fecha_hasta': fechaHasta,
    };
    final json = await _apiClient.getJson(
      ApiConfig.reporteMovimientos,
      query: query,
    ) as List<dynamic>;
    return json
        .map((item) => Movimiento.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> exportarStock() async {
    return _apiClient.getRaw(ApiConfig.exportarStock);
  }

  Future<String> exportarMovimientos() async {
    return _apiClient.getRaw(ApiConfig.exportarMovimientos);
  }
}