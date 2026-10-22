/// Marca comercial de un producto.
///
/// Catalogo opcional: un producto puede no tener marca asignada, asi que
/// `Producto.marcaId` es nullable y la app manda `null` en ese caso (nunca
/// una cadena vacia, para no romper el indice unico del backend).
class Marca {
  final int id;
  final String nombre;
  final bool activo;

  const Marca({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  factory Marca.fromJson(Map<String, dynamic> json) => Marca(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        activo: json['activo'] as bool? ?? true,
      );
}