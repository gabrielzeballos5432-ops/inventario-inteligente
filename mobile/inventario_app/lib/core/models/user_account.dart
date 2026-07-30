class UserAccount {
  final int id;
  final String username;
  final String email;
  final String nombre;
  final String? apellido;
  final String? telefono;
  final int? sucursalId;
  final String? sucursalNombre;
  final int rolId;
  final String rolNombre;
  final bool activo;
  final String? ultimoAcceso;
  final String? createdAt;

  const UserAccount({
    required this.id,
    required this.username,
    required this.email,
    required this.nombre,
    this.apellido,
    this.telefono,
    this.sucursalId,
    this.sucursalNombre,
    required this.rolId,
    required this.rolNombre,
    required this.activo,
    this.ultimoAcceso,
    this.createdAt,
  });

  String get nombreCompleto => '$nombre ${apellido ?? ''}'.trim();

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String?,
      telefono: json['telefono'] as String?,
      sucursalId: json['sucursal_id'] as int?,
      sucursalNombre: json['sucursal_nombre'] as String?,
      rolId: json['rol_id'] as int? ?? 0,
      rolNombre: json['rol_nombre'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      ultimoAcceso: json['ultimo_acceso'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
