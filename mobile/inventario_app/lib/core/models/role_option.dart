class RoleOption {
  final int id;
  final String nombre;
  final String? descripcion;

  const RoleOption({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
    );
  }
}
