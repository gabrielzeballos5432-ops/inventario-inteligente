import '../config/api_config.dart';
import '../models/dashboard_summary.dart';
import '../models/product.dart';
import '../network/api_client.dart';

class DashboardService {
  final ApiClient _apiClient;

  DashboardService(this._apiClient);

  Future<DashboardSummary> fetchSummary() async {
    final inventario =
        await _apiClient.getJson(ApiConfig.inventario) as List<dynamic>;
    final productos = inventario
        .map((e) => ProductoConStock.fromJson(e as Map<String, dynamic>))
        .toList();
    final stockBajo = productos.where((p) => p.stockBajo).toList();

    return DashboardSummary(
      totalProductos: productos.length,
      stockBajo: stockBajo.length,
      productosStockBajo: stockBajo,
      totalMovimientos: 0,
    );
  }
}
