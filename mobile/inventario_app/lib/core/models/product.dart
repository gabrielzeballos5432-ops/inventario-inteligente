class Categoria {
  final int id;
  final String nombre;
  final String? descripcion;

  Categoria({required this.id, required this.nombre, this.descripcion});

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }
}

class Product {
  final int id;
  final String? codigoBarras;
  final String nombre;
  final String? descripcion;
  final double precioVenta;
  final double? precioCosto;
  final int? categoriaId;
  final Categoria? categoria;
  final int stockMinimo;
  final bool activo;

  Product({
    required this.id,
    this.codigoBarras,
    required this.nombre,
    this.descripcion,
    required this.precioVenta,
    this.precioCosto,
    this.categoriaId,
    this.categoria,
    required this.stockMinimo,
    required this.activo,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      codigoBarras: json['codigo_barras'] as String?,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precioVenta: (json['precio_venta'] as num?)?.toDouble() ?? 0,
      precioCosto:
          (json['precio_costo'] as num?)?.toDouble(),
      categoriaId: json['categoria_id'] as int?,
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
          : null,
      stockMinimo: json['stock_minimo'] as int? ?? 5,
      activo: json['activo'] as bool? ?? true,
    );
  }
}

class ProductoConStock extends Product {
  final int stockActual;
  final bool stockBajo;

  ProductoConStock({
    required super.id,
    super.codigoBarras,
    required super.nombre,
    super.descripcion,
    required super.precioVenta,
    super.precioCosto,
    super.categoriaId,
    super.categoria,
    required super.stockMinimo,
    required super.activo,
    required this.stockActual,
    required this.stockBajo,
  });

  factory ProductoConStock.fromJson(Map<String, dynamic> json) {
    return ProductoConStock(
      id: json['id'] as int,
      codigoBarras: json['codigo_barras'] as String?,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precioVenta: (json['precio_venta'] as num?)?.toDouble() ?? 0,
      precioCosto:
          (json['precio_costo'] as num?)?.toDouble(),
      categoriaId: json['categoria_id'] as int?,
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
          : null,
      stockMinimo: json['stock_minimo'] as int? ?? 5,
      activo: json['activo'] as bool? ?? true,
      stockActual: json['stock_actual'] as int? ?? 0,
      stockBajo: json['stock_bajo'] as bool? ?? false,
    );
  }
}
