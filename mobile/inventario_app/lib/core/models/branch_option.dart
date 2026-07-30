class BranchOption {
  final int id;
  final String nombre;
  final String codigo;

  const BranchOption({
    required this.id,
    required this.nombre,
    required this.codigo,
  });

  factory BranchOption.fromJson(Map<String, dynamic> json) {
    return BranchOption(
      id: json['id'] as int,
      nombre: json['nombre'] as String? ?? '',
      codigo: json['codigo'] as String? ?? '',
    );
  }
}
