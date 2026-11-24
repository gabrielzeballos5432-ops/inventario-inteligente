import 'json_utils.dart';

/// Recuadro de una unidad detectada, en proporcion de la foto (0 a 1) y con
/// el origen arriba a la izquierda. Se dibuja sobre la foto multiplicando por
/// el tamano con que se muestra.
class Caja {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double confianza;

  const Caja({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confianza,
  });

  factory Caja.fromJson(Map<String, dynamic> json) {
    return Caja(
      x1: parseDouble(json['x1']),
      y1: parseDouble(json['y1']),
      x2: parseDouble(json['x2']),
      y2: parseDouble(json['y2']),
      confianza: parseDouble(json['confianza']),
    );
  }
}

class Deteccion {
  final int productoId;
  final String productoNombre;
  final double confianza;
  final int cantidad;

  /// Un recuadro por unidad contada. Vacio si el servidor no los envia.
  final List<Caja> cajas;

  Deteccion({
    required this.productoId,
    required this.productoNombre,
    required this.confianza,
    required this.cantidad,
    this.cajas = const [],
  });

  factory Deteccion.fromJson(Map<String, dynamic> json) {
    return Deteccion(
      productoId: json['producto_id'] as int,
      productoNombre: json['producto_nombre'] as String? ?? '',
      confianza: parseDouble(json['confianza']),
      cantidad: json['cantidad'] as int? ?? 1,
      cajas: [
        for (final c in json['cajas'] as List? ?? const [])
          Caja.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

class ResultadoInferencia {
  final List<Deteccion> detecciones;
  final int totalProductos;
  final int movimientosCreados;

  /// Sesion de camara de la deteccion: la entrada confirmada se registra con
  /// ella, para que quede trazado que salio de esta foto.
  final int? sesionId;

  ResultadoInferencia({
    required this.detecciones,
    required this.totalProductos,
    required this.movimientosCreados,
    this.sesionId,
  });

  factory ResultadoInferencia.fromJson(Map<String, dynamic> json) {
    return ResultadoInferencia(
      detecciones: (json['detecciones'] as List<dynamic>?)
              ?.map(
                  (d) => Deteccion.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      totalProductos: json['total_productos'] as int? ?? 0,
      movimientosCreados: json['movimientos_creados'] as int? ?? 0,
      sesionId: json['sesion_id'] as int?,
    );
  }
}

class Movimiento {
  final int id;
  final int productoId;
  final String? productoNombre;
  final int usuarioId;
  final String? usuarioNombre;
  final String tipo;
  final int cantidad;
  final int stockResultante;
  final String? origen;
  final String? creadoEn;
  final String? sucursalNombre;
  final String? razonNombre;

  /// En un traspaso: la sucursal destino (salida) o de origen (entrada).
  final String? sucursalRelacionadaNombre;

  Movimiento({
    required this.id,
    required this.productoId,
    this.productoNombre,
    required this.usuarioId,
    this.usuarioNombre,
    required this.tipo,
    required this.cantidad,
    required this.stockResultante,
    this.origen,
    this.creadoEn,
    this.sucursalNombre,
    this.razonNombre,
    this.sucursalRelacionadaNombre,
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      id: json['id'] as int,
      productoId: json['producto_id'] as int,
      productoNombre: json['producto_nombre'] as String?,
      usuarioId: json['usuario_id'] as int? ?? 0,
      usuarioNombre: json['usuario_nombre'] as String?,
      tipo: json['tipo'] as String? ?? '',
      cantidad: json['cantidad'] as int? ?? 0,
      stockResultante: json['stock_resultante'] as int? ?? 0,
      origen: json['origen'] as String?,
      creadoEn: json['creado_en'] as String?,
      sucursalNombre: json['sucursal_nombre'] as String?,
      razonNombre: json['razon_nombre'] as String?,
      sucursalRelacionadaNombre: json['sucursal_relacionada_nombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'producto_id': productoId,
      'tipo': tipo,
      'cantidad': cantidad,
      'origen': origen ?? 'manual',
    };
  }
}
