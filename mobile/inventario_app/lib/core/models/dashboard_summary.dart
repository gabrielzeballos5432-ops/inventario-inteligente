import 'product.dart';

class DashboardSummary {
  final int totalProductos;
  final int stockBajo;
  final List<ProductoConStock> productosStockBajo;
  final int totalMovimientos;

  DashboardSummary({
    required this.totalProductos,
    required this.stockBajo,
    required this.productosStockBajo,
    required this.totalMovimientos,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalProductos: json['total_productos'] as int? ?? 0,
      stockBajo: json['stock_bajo'] as int? ?? 0,
      productosStockBajo: (json['productos_stock_bajo'] as List<dynamic>?)
              ?.map((e) =>
                  ProductoConStock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalMovimientos: json['total_movimientos'] as int? ?? 0,
    );
  }
}
