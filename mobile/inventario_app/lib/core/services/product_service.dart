import '../config/api_config.dart';
import '../models/product.dart';
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

  Future<List<ProductoConStock>> obtenerStockBajo() async {
    final json =
        await _apiClient.getJson(ApiConfig.stockBajo) as List<dynamic>;
    return json
        .map((item) =>
            ProductoConStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
