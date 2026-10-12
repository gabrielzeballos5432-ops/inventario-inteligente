import 'json_utils.dart';

class Categoria {
  final int id;
  final String nombre;
  final int? padreId;

  Categoria({required this.id, required this.nombre, this.padreId});

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      padreId: json['padre_id'] as int?,
    );
  }
}

class Product {
  final int id;
  final String? sku;
  final String? codigoBarras;
  final String nombre;
  final String? descripcion;
  final int? categoriaId;
  final Categoria? categoria;
  final int? marcaId;
  final int? proveedorId;
  final double precioCompra;
  final double precioVenta;
  final int stockMinimo;
  final bool activo;

  Product({
    required this.id,
    this.sku,
    this.codigoBarras,
    required this.nombre,
    this.descripcion,
    this.categoriaId,
    this.categoria,
    this.marcaId,
    this.proveedorId,
    required this.precioCompra,
    required this.precioVenta,
    required this.stockMinimo,
    required this.activo,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      sku: json['sku'] as String?,
      codigoBarras: json['codigo_barras'] as String?,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      categoriaId: json['categoria_id'] as int?,
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
          : null,
      marcaId: json['marca_id'] as int?,
      proveedorId: json['proveedor_id'] as int?,
      precioCompra: parseDouble(json['precio_compra']),
      precioVenta: parseDouble(json['precio_venta']),
      stockMinimo: json['stock_minimo'] as int? ?? 5,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'sku': sku,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria_id': categoriaId,
      'marca_id': marcaId,
      'proveedor_id': proveedorId,
      'precio_compra': precioCompra,
      'precio_venta': precioVenta,
      'stock_minimo': stockMinimo,
    };
  }

  Map<String, dynamic> toUpdateJson({
    String? nombre,
    String? descripcion,
    int? categoriaId,
    double? precioCompra,
    double? precioVenta,
    int? stockMinimo,
    bool? activo,
  }) {
    return {
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (precioCompra != null) 'precio_compra': precioCompra,
      if (precioVenta != null) 'precio_venta': precioVenta,
      if (stockMinimo != null) 'stock_minimo': stockMinimo,
      if (activo != null) 'activo': activo,
    };
  }
}

class ProductoConStock extends Product {
  final int stockActual;
  final bool stockBajo;

  ProductoConStock({
    required super.id,
    super.sku,
    super.codigoBarras,
    required super.nombre,
    super.descripcion,
    super.categoriaId,
    super.categoria,
    super.marcaId,
    super.proveedorId,
    required super.precioCompra,
    required super.precioVenta,
    required super.stockMinimo,
    required super.activo,
    required this.stockActual,
    required this.stockBajo,
  });

  factory ProductoConStock.fromJson(Map<String, dynamic> json) {
    return ProductoConStock(
      id: json['id'] as int,
      sku: json['sku'] as String?,
      codigoBarras: json['codigo_barras'] as String?,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      categoriaId: json['categoria_id'] as int?,
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
          : null,
      marcaId: json['marca_id'] as int?,
      proveedorId: json['proveedor_id'] as int?,
      precioCompra: parseDouble(json['precio_compra']),
      precioVenta: parseDouble(json['precio_venta']),
      stockMinimo: json['stock_minimo'] as int? ?? 5,
      activo: json['activo'] as bool? ?? true,
      stockActual: json['stock_actual'] as int? ?? 0,
      stockBajo: json['stock_bajo'] as bool? ?? false,
    );
  }
}

class ValorizacionInventario {
  final int productosActivos;
  final int unidadesTotales;
  final int productosStockBajo;
  final double valorizadoCosto;
  final double valorizadoVenta;

  ValorizacionInventario({
    required this.productosActivos,
    required this.unidadesTotales,
    required this.productosStockBajo,
    required this.valorizadoCosto,
    required this.valorizadoVenta,
  });

  factory ValorizacionInventario.fromJson(Map<String, dynamic> json) {
    return ValorizacionInventario(
      productosActivos: json['productos_activos'] as int? ?? 0,
      unidadesTotales: json['unidades_totales'] as int? ?? 0,
      productosStockBajo: json['productos_stock_bajo'] as int? ?? 0,
      valorizadoCosto: parseDouble(json['valorizado_costo']),
      valorizadoVenta: parseDouble(json['valorizado_venta']),
    );
  }
}