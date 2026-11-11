import '../models/sucursal.dart';
import '../network/api_client.dart';

/// Sucursales, sucursal predeterminada y razones de movimiento.
///
/// Igual que en los demás catálogos, nada se borra: sucursales y razones se
/// desactivan (`activo = false`) para no dejar movimientos huérfanos.
class ConfiguracionService {
  final ApiClient _api;

  ConfiguracionService(this._api);

  // ------------------------------------------------------------- sucursales

  Future<List<Sucursal>> fetchSucursales({bool incluirInactivas = false}) async {
    final json = await _api.getJson(
      '/api/sucursales/',
      query: incluirInactivas ? {'incluir_inactivas': 'true'} : null,
    ) as List<dynamic>;
    return json
        .map((item) => Sucursal.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Sucursal> crearSucursal({
    required String nombre,
    String? direccion,
    String? telefono,
  }) async {
    final json = await _api.postJson('/api/sucursales/', {
      'nombre': nombre,
      'direccion': _oVacio(direccion),
      'telefono': _oVacio(telefono),
    });
    return Sucursal.fromJson(json as Map<String, dynamic>);
  }

  Future<Sucursal> actualizarSucursal(
    int id, {
    String? nombre,
    String? direccion,
    String? telefono,
    bool? activo,
  }) async {
    final json = await _api.putJson('/api/sucursales/$id', {
      if (nombre != null) 'nombre': nombre,
      if (direccion != null) 'direccion': _oVacio(direccion),
      if (telefono != null) 'telefono': _oVacio(telefono),
      if (activo != null) 'activo': activo,
    });
    return Sucursal.fromJson(json as Map<String, dynamic>);
  }

  // ----------------------------------------------------------- configuracion

  /// Id de la sucursal predeterminada.
  Future<int> fetchSucursalPredeterminadaId() async {
    final json = await _api.getJson('/api/configuracion/') as Map<String, dynamic>;
    return json['sucursal_predeterminada_id'] as int;
  }

  Future<int> definirSucursalPredeterminada(int sucursalId) async {
    final json = await _api.putJson('/api/configuracion/', {
      'sucursal_predeterminada_id': sucursalId,
    }) as Map<String, dynamic>;
    return json['sucursal_predeterminada_id'] as int;
  }

  // ---------------------------------------------------------------- razones

  /// Razones que se pueden elegir a mano (sin las del sistema).
  Future<List<RazonMovimiento>> fetchRazones({
    String? tipo,
    bool incluirInactivas = false,
  }) async {
    final json = await _api.getJson('/api/razones-movimiento/', query: {
      if (tipo != null) 'tipo': tipo,
      if (incluirInactivas) 'incluir_inactivas': 'true',
    }) as List<dynamic>;
    return json
        .map((item) => RazonMovimiento.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RazonMovimiento> crearRazon({
    required String nombre,
    required String tipoMovimiento,
    bool requiereSucursalDestino = false,
  }) async {
    final json = await _api.postJson('/api/razones-movimiento/', {
      'nombre': nombre,
      'tipo_movimiento': tipoMovimiento,
      'requiere_sucursal_destino': requiereSucursalDestino,
    });
    return RazonMovimiento.fromJson(json as Map<String, dynamic>);
  }

  Future<RazonMovimiento> actualizarRazon(
    int id, {
    String? nombre,
    bool? requiereSucursalDestino,
    bool? activo,
  }) async {
    final json = await _api.putJson('/api/razones-movimiento/$id', {
      if (nombre != null) 'nombre': nombre,
      if (requiereSucursalDestino != null) 'requiere_sucursal_destino': requiereSucursalDestino,
      if (activo != null) 'activo': activo,
    });
    return RazonMovimiento.fromJson(json as Map<String, dynamic>);
  }

  static String? _oVacio(String? valor) {
    final texto = valor?.trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  }
}
