/// Proveedor de un producto.
///
/// Catalogo opcional, igual que la marca. A diferencia de la marca, el
/// proveedor tiene datos de contacto: nombre, persona de contacto, telefono y
/// correo.
class Proveedor {
  final int id;
  final String nombre;
  final String? contacto;
  final String? telefono;
  final String? email;
  final bool activo;

  const Proveedor({
    required this.id,
    required this.nombre,
    this.contacto,
    this.telefono,
    this.email,
    this.activo = true,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) => Proveedor(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        contacto: json['contacto'] as String?,
        telefono: json['telefono'] as String?,
        email: json['email'] as String?,
        activo: json['activo'] as bool? ?? true,
      );

  /// Datos de contacto en una sola linea para la lista del dialogo de
  /// gestion. El backend normaliza los campos vacios a null, asi que se
  /// filtran en lugar de confiar en que no vengan Strings vacios.
  String get lineaContacto {
    final partes = <String>[
      if (contacto != null && contacto!.isNotEmpty) contacto!,
      if (telefono != null && telefono!.isNotEmpty) telefono!,
      if (email != null && email!.isNotEmpty) email!,
    ];
    return partes.join(' · ');
  }
}