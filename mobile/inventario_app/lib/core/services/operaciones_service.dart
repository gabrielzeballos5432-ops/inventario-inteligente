import '../network/api_client.dart';
import '../models/categoria_gasto.dart';

class OperacionesService {
  final ApiClient _api;

  OperacionesService(this._api);

  Future<List<CategoriaGasto>> listarCategoriasGasto({
    bool incluirInactivas = false,
  }) async {
    final respuesta = await _api.getJson(
      '/api/contabilidad/categorias-gasto',
      query: {'incluir_inactivas': '$incluirInactivas'},
    );
    return _listaMapas(respuesta).map(CategoriaGasto.fromJson).toList();
  }

  Future<void> guardarCategoriaGasto({
    int? id,
    required String nombre,
    required String periodicidad,
    required String tipoImporte,
    double? montoHabitual,
    bool activo = true,
  }) async {
    final datos = <String, dynamic>{
      'nombre': nombre.trim(),
      'periodicidad': periodicidad,
      'tipo_importe': tipoImporte,
      'monto_habitual': montoHabitual?.toStringAsFixed(2),
      if (id != null) 'activo': activo,
    };
    const ruta = '/api/contabilidad/categorias-gasto';
    if (id == null) {
      await _api.postJson(ruta, datos);
    } else {
      await _api.putJson('$ruta/$id', datos);
    }
  }

  Future<void> eliminarCategoriaGasto(int id) async {
    await _api.deleteJson('/api/contabilidad/categorias-gasto/$id');
  }

  Future<Map<String, dynamic>?> obtenerCajaActual() async {
    final respuesta = await _api.getJson('/api/caja/sesiones/actual');
    return respuesta as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> listarSesionesCaja() async {
    final respuesta = await _api.getJson(
      '/api/caja/sesiones',
      query: const {'limite': '50'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> abrirCaja(double montoInicial) async {
    final respuesta = await _api.postJson('/api/caja/sesiones/abrir', {
      'monto_inicial': montoInicial.toStringAsFixed(2),
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cerrarCaja({
    required double efectivoContado,
    String? observacion,
  }) async {
    final respuesta = await _api.postJson('/api/caja/sesiones/cerrar', {
      'monto_efectivo_contado': efectivoContado.toStringAsFixed(2),
      if (observacion != null && observacion.trim().isNotEmpty)
        'observacion_cierre': observacion.trim(),
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarClientes({String? texto}) async {
    final respuesta = await _api.getJson(
      '/api/clientes/',
      query: {
        if (texto != null && texto.trim().isNotEmpty) 'texto': texto.trim(),
      },
    );
    return _listaMapas(respuesta);
  }

  Future<List<Map<String, dynamic>>> listarMonedas({
    bool incluirInactivas = false,
  }) async {
    final respuesta = await _api.getJson(
      '/api/monedas/',
      query: {'incluir_inactivas': '$incluirInactivas'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> crearMoneda({
    required String codigo,
    required String nombre,
    String? simbolo,
    String? pais,
    required int decimales,
  }) async {
    final respuesta = await _api.postJson('/api/monedas/', {
      'codigo': codigo.trim().toUpperCase(),
      'nombre': nombre.trim(),
      if (simbolo != null && simbolo.trim().isNotEmpty)
        'simbolo': simbolo.trim(),
      if (pais != null && pais.trim().isNotEmpty) 'pais': pais.trim(),
      'decimales': decimales,
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> actualizarEstadoMoneda(
    String codigo,
    bool activa,
  ) async {
    final respuesta = await _api.patchJson(
      '/api/monedas/${codigo.toUpperCase()}/estado',
      {'activa': activa},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> crearCliente({
    required String nombre,
    String? telefono,
    String? email,
  }) async {
    final respuesta = await _api.postJson('/api/clientes/', {
      'nombre': nombre.trim(),
      if (telefono != null && telefono.trim().isNotEmpty)
        'telefono': telefono.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarBonos({int? usuarioId}) async {
    final respuesta = await _api.getJson(
      '/api/contabilidad/bonos',
      query: {if (usuarioId != null) 'usuario_id': '$usuarioId'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> crearBono({
    required int usuarioId,
    int? liquidacionId,
    required String tipo,
    String? descripcion,
    required double monto,
  }) async {
    final respuesta = await _api.postJson('/api/contabilidad/bonos', {
      'usuario_id': usuarioId,
      if (liquidacionId != null) 'liquidacion_sueldo_id': liquidacionId,
      'tipo_bono': tipo,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
      'monto': monto.toStringAsFixed(2),
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> asignarBono(
    int bonoId,
    int liquidacionId,
  ) async {
    final respuesta = await _api.postJson(
      '/api/contabilidad/bonos/$bonoId/asignar/$liquidacionId',
      {},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarGastos({
    String? fechaInicio,
    String? fechaFin,
    String? categoria,
    int limite = 100,
  }) async {
    final respuesta = await _api.getJson(
      '/api/contabilidad/gastos',
      query: {
        if (fechaInicio != null) 'fecha_inicio': fechaInicio,
        if (fechaFin != null) 'fecha_fin': fechaFin,
        if (categoria != null) 'categoria': categoria,
        'limite': '$limite',
      },
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> crearGasto({
    String? categoria,
    int? categoriaGastoId,
    required String concepto,
    required String monedaCodigo,
    required double monto,
    required double tipoCambioExt,
    required double tipoCambioBob,
    int? proveedorId,
    String? numeroDocumento,
    String? periodoDesde,
    String? periodoHasta,
  }) async {
    final respuesta = await _api.postJson('/api/contabilidad/gastos', {
      if (categoria != null) 'categoria': categoria,
      if (categoriaGastoId != null) 'categoria_gasto_id': categoriaGastoId,
      'concepto': concepto.trim(),
      'moneda_codigo': monedaCodigo,
      'monto': monto.toStringAsFixed(4),
      'tipo_cambio_ext': tipoCambioExt.toStringAsFixed(6),
      'tipo_cambio_bob': tipoCambioBob.toStringAsFixed(6),
      if (proveedorId != null) 'proveedor_id': proveedorId,
      if (numeroDocumento != null && numeroDocumento.trim().isNotEmpty)
        'numero_documento': numeroDocumento.trim(),
      if (periodoDesde != null) 'periodo_desde': periodoDesde,
      if (periodoHasta != null) 'periodo_hasta': periodoHasta,
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<void> pagarGastoCombinado({
    required int gastoId,
    required List<Map<String, dynamic>> pagos,
  }) async {
    await _api.postJson('/api/contabilidad/gastos/$gastoId/pagos/mixto', {
      'pagos': pagos,
    });
  }

  Future<Map<String, dynamic>> pagarGasto({
    required int gastoId,
    required double monto,
    required String metodoPago,
    String? referencia,
  }) async {
    final respuesta = await _api
        .postJson('/api/contabilidad/gastos/$gastoId/pagos', {
          'monto': monto.toStringAsFixed(4),
          'metodo_pago': metodoPago,
          if (referencia != null && referencia.trim().isNotEmpty)
            'referencia': referencia.trim(),
        });
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> anularGasto(int gastoId, String motivo) async {
    final respuesta = await _api.postJson(
      '/api/contabilidad/gastos/$gastoId/anular',
      {'motivo': motivo.trim()},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reporteFinanciero({
    required String fechaInicio,
    required String fechaFin,
  }) async {
    final respuesta = await _api.getJson(
      '/api/contabilidad/reporte-financiero',
      query: {'fecha_inicio': fechaInicio, 'fecha_fin': fechaFin},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarVentas() async {
    final respuesta = await _api.getJson(
      '/api/ventas/',
      query: const {'limite': '50'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> anularVenta(int ventaId, String motivo) async {
    final respuesta = await _api.postJson('/api/ventas/$ventaId/anular', {
      'motivo': motivo.trim(),
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarUsuarios() async {
    final respuesta = await _api.getJson('/api/usuarios/');
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> actualizarTarifasVendedor({
    required int usuarioId,
    required String pagoPorHora,
    required String porcentajeComision,
  }) async {
    final respuesta = await _api.putJson('/api/usuarios/$usuarioId', {
      'pago_por_hora': pagoPorHora,
      'porcentaje_comision': porcentajeComision,
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarLiquidaciones({
    int? usuarioId,
  }) async {
    final respuesta = await _api.getJson(
      '/api/sueldos/liquidaciones',
      query: {
        if (usuarioId != null) 'usuario_id': '$usuarioId',
        'limite': '200',
      },
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> marcarEntrada() async {
    final respuesta = await _api.postJson(
      '/api/sueldos/asistencias/entrada',
      {},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> marcarSalida() async {
    final respuesta = await _api.postJson(
      '/api/sueldos/asistencias/salida',
      {},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarAsistencias() async {
    final respuesta = await _api.getJson(
      '/api/sueldos/asistencias',
      query: const {'limite': '200'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> confirmarAsistencia(int id) async {
    final respuesta = await _api.postJson(
      '/api/sueldos/asistencias/$id/confirmar',
      {},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> crearLiquidacion({
    required int usuarioId,
    required String fechaInicio,
    required String fechaFin,
  }) async {
    final respuesta = await _api.postJson('/api/sueldos/liquidaciones', {
      'usuario_id': usuarioId,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
    });
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pagarLiquidacion(int id) async {
    final respuesta = await _api.postJson(
      '/api/sueldos/liquidaciones/$id/pagar',
      {},
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarProveedores() async {
    final respuesta = await _api.getJson('/api/proveedores/');
    return _listaMapas(respuesta);
  }

  Future<List<Map<String, dynamic>>> listarProductos() async {
    final respuesta = await _api.getJson('/api/productos/');
    return _listaMapas(respuesta);
  }

  Future<List<Map<String, dynamic>>> listarCompras() async {
    final respuesta = await _api.getJson(
      '/api/compras/',
      query: const {'limite': '50'},
    );
    return _listaMapas(respuesta);
  }

  Future<Map<String, dynamic>> leerComprobante({
    required List<int> bytes,
    required String nombre,
  }) async {
    final respuesta = await _api.postMultipart(
      '/api/compras/leer-comprobante',
      fieldName: 'imagen',
      fileName: nombre,
      bytes: bytes,
      timeout: const Duration(minutes: 5),
    );
    return respuesta as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> crearCompra(
    Map<String, dynamic> solicitud,
  ) async {
    final respuesta = await _api.postJson('/api/compras/', solicitud);
    return respuesta as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _listaMapas(dynamic respuesta) {
    if (respuesta is! List) {
      throw const FormatException('El servidor devolvió una lista inválida.');
    }
    return respuesta
        .map((fila) => Map<String, dynamic>.from(fila as Map))
        .toList();
  }
}
