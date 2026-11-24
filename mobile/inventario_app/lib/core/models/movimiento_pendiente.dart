import 'dart:convert';

/// Un movimiento por lote que se hizo sin conexion y espera en el telefono
/// hasta que vuelva el servidor (HU-13 / RF-19).
class MovimientoPendiente {
  /// Clave de idempotencia: la misma con la que se intento enviar. Si aquel
  /// envio si llego al servidor (se perdio solo la respuesta), el reenvio no
  /// registra el movimiento dos veces.
  final String clave;
  final String tipo;
  final int razonId;
  final String razonNombre;

  /// Sucursal en la que se hizo el movimiento. Se envia tal cual al
  /// sincronizar, aunque para entonces la sucursal activa sea otra.
  final int? sucursalId;

  /// Quien lo registro: solo esa cuenta lo sincroniza.
  final int usuarioId;
  final List<ItemPendiente> items;
  final DateTime creadoEn;

  /// `pendiente` (espera conexion) o `rechazado` (el servidor no lo acepto).
  final String estado;

  /// Motivo del rechazo, tal como lo explica el servidor.
  final String? detalle;

  const MovimientoPendiente({
    required this.clave,
    required this.tipo,
    required this.razonId,
    required this.razonNombre,
    required this.sucursalId,
    required this.usuarioId,
    required this.items,
    required this.creadoEn,
    this.estado = estadoPendiente,
    this.detalle,
  });

  static const estadoPendiente = 'pendiente';
  static const estadoRechazado = 'rechazado';

  bool get rechazado => estado == estadoRechazado;
  int get unidades => items.fold(0, (total, i) => total + i.cantidad);

  Map<String, dynamic> toMap() => {
    'clave': clave,
    'tipo': tipo,
    'razon_id': razonId,
    'razon_nombre': razonNombre,
    'sucursal_id': sucursalId,
    'usuario_id': usuarioId,
    'items': jsonEncode([for (final i in items) i.toJson()]),
    'creado_en': creadoEn.toIso8601String(),
    'estado': estado,
    'detalle': detalle,
  };

  factory MovimientoPendiente.fromMap(Map<String, dynamic> fila) =>
      MovimientoPendiente(
        clave: fila['clave'] as String,
        tipo: fila['tipo'] as String,
        razonId: fila['razon_id'] as int,
        razonNombre: fila['razon_nombre'] as String? ?? '',
        sucursalId: fila['sucursal_id'] as int?,
        usuarioId: fila['usuario_id'] as int,
        items: [
          for (final i in jsonDecode(fila['items'] as String) as List)
            ItemPendiente.fromJson(i as Map<String, dynamic>),
        ],
        creadoEn: DateTime.parse(fila['creado_en'] as String),
        estado: fila['estado'] as String? ?? estadoPendiente,
        detalle: fila['detalle'] as String?,
      );
}

class ItemPendiente {
  final int productoId;

  /// Nombre al momento de registrar, para mostrar la lista sin conexion.
  final String nombre;
  final int cantidad;

  const ItemPendiente({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
  });

  Map<String, dynamic> toJson() => {
    'producto_id': productoId,
    'nombre': nombre,
    'cantidad': cantidad,
  };

  factory ItemPendiente.fromJson(Map<String, dynamic> json) => ItemPendiente(
    productoId: json['producto_id'] as int,
    nombre: json['nombre'] as String? ?? '',
    cantidad: json['cantidad'] as int,
  );
}
