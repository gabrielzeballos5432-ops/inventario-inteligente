/// Local físico del salón. El catálogo de productos es único; el stock, las
/// ventas, las compras y los movimientos van por sucursal.
class Sucursal {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool activo;

  /// Es la sucursal predeterminada de Configuración (con la que arranca cada
  /// sesión y en la que opera siempre el vendedor).
  final bool predeterminada;

  const Sucursal({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    this.activo = true,
    this.predeterminada = false,
  });

  factory Sucursal.fromJson(Map<String, dynamic> json) => Sucursal(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    direccion: json['direccion'] as String?,
    telefono: json['telefono'] as String?,
    activo: json['activo'] as bool? ?? true,
    predeterminada: json['predeterminada'] as bool? ?? false,
  );
}

/// Motivo de un movimiento de inventario. Las de `sistema` las asigna el
/// backend (venta, compra, anulación, stock inicial, IA, traspaso) y no se
/// ofrecen en el formulario manual.
class RazonMovimiento {
  final int id;
  final String nombre;
  final String tipoMovimiento;
  final bool sistema;

  /// Envía la mercadería a otra sucursal ("Salida a sucursal"): el formulario
  /// pide la sucursal destino y el backend registra la entrada allí.
  final bool requiereSucursalDestino;
  final bool activo;

  const RazonMovimiento({
    required this.id,
    required this.nombre,
    required this.tipoMovimiento,
    this.sistema = false,
    this.requiereSucursalDestino = false,
    this.activo = true,
  });

  factory RazonMovimiento.fromJson(Map<String, dynamic> json) =>
      RazonMovimiento(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        tipoMovimiento: json['tipo_movimiento'] as String,
        sistema: json['sistema'] as bool? ?? false,
        requiereSucursalDestino:
            json['requiere_sucursal_destino'] as bool? ?? false,
        activo: json['activo'] as bool? ?? true,
      );
}
