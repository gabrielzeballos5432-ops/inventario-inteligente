class AuthUser {
  final int id;
  final String nombre;
  final String email;
  final String rol;
  final bool activo;

  const AuthUser({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.activo,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rol: json['rol'] as String? ?? 'vendedor',
      activo: json['activo'] as bool? ?? true,
    );
  }

  bool get isAdmin => rol == 'administrador';
}
