import 'json_utils.dart';

String nombreCategoriaGasto(String nombre) => switch (nombre) {
  'servicio' => 'Servicio',
  'alquiler' => 'Alquiler',
  'insumo_limpieza' => 'Insumos de limpieza',
  'mantenimiento' => 'Mantenimiento',
  'otro' => 'Otro',
  _ => nombre,
};

class CategoriaGasto {
  const CategoriaGasto({
    required this.id,
    required this.nombre,
    required this.periodicidad,
    required this.tipoImporte,
    required this.activo,
    this.montoHabitual,
  });

  final int id;
  final String nombre;
  final String periodicidad;
  final String tipoImporte;
  final double? montoHabitual;
  final bool activo;

  static const periodos = {
    'sin_periodicidad': 'Sin periodicidad',
    'mensual': 'Mensual',
    'semanal': 'Semanal',
    'anual': 'Anual',
  };

  factory CategoriaGasto.fromJson(Map<String, dynamic> json) => CategoriaGasto(
    id: json['id'] as int,
    nombre: nombreCategoriaGasto(json['nombre'] as String),
    periodicidad: json['periodicidad'] as String,
    tipoImporte: json['tipo_importe'] as String,
    activo: json['activo'] as bool,
    montoHabitual: json['monto_habitual'] == null
        ? null
        : parseDouble(json['monto_habitual']),
  );

  ({DateTime desde, DateTime hasta})? periodoSugerido(DateTime fecha) {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    return switch (periodicidad) {
      'sin_periodicidad' => null,
      'mensual' => (
        desde: DateTime(dia.year, dia.month),
        hasta: DateTime(dia.year, dia.month + 1, 0),
      ),
      'anual' => (desde: DateTime(dia.year), hasta: DateTime(dia.year, 12, 31)),
      'semanal' => (
        desde: DateTime(dia.year, dia.month, dia.day - dia.weekday + 1),
        hasta: DateTime(dia.year, dia.month, dia.day - dia.weekday + 7),
      ),
      _ => throw StateError('Periodicidad de gasto desconocida: $periodicidad'),
    };
  }
}
