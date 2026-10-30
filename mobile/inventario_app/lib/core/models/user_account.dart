class UserAccount {
  final int id;
  final String nombre;
  final String email;
  final int rolId;
  final String rolNombre;
  final bool activo;
  final String? createdAt;

  const UserAccount({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rolId,
    required this.rolNombre,
    required this.activo,
    this.createdAt,
  });

  String get nombreCompleto => nombre;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rolId: json['rol_id'] as int? ?? 0,
      rolNombre: json['rol_nombre'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
    );
  }
}
