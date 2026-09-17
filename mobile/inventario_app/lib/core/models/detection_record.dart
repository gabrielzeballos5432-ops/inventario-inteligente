import 'json_utils.dart';

class Deteccion {
  final int productoId;
  final String productoNombre;
  final double confianza;
  final int cantidad;

  Deteccion({
    required this.productoId,
    required this.productoNombre,
    required this.confianza,
    required this.cantidad,
  });

  factory Deteccion.fromJson(Map<String, dynamic> json) {
    return Deteccion(
      productoId: json['producto_id'] as int,
      productoNombre: json['producto_nombre'] as String? ?? '',
      confianza: parseDouble(json['confianza']),
      cantidad: json['cantidad'] as int? ?? 1,
    );
  }
}

class ResultadoInferencia {
  final List<Deteccion> detecciones;
  final int totalProductos;
  final int movimientosCreados;

  ResultadoInferencia({
    required this.detecciones,
    required this.totalProductos,
    required this.movimientosCreados,
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
