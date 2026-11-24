import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/movimiento_pendiente.dart';
import '../network/api_client.dart';
import '../services/local_db_service.dart';
import '../services/product_service.dart';
import '../session/session_controller.dart';

/// Lo que paso en una sincronizacion, para avisar al usuario (RF-20).
class ResultadoSincronizacion {
  final int enviados;
  final int rechazados;

  const ResultadoSincronizacion({this.enviados = 0, this.rechazados = 0});

  bool get vacio => enviados == 0 && rechazados == 0;

  String get mensaje {
    final partes = <String>[
      if (enviados > 0) '$enviados movimiento(s) pendiente(s) enviado(s)',
      if (rechazados > 0)
        '$rechazados rechazado(s) por el servidor: revisa los pendientes',
    ];
    return '${partes.join('. ')}.';
  }
}

/// Cola de movimientos hechos sin conexion (HU-13 / RF-19).
///
/// Cuando el servidor no responde, el dialogo de movimiento guarda el lote
/// aqui en vez de fallar; al volver la conexion se envian en el orden en que
/// se hicieron. Cada lote viaja con su clave de idempotencia, asi que un
/// envio cuya respuesta se perdio no se registra dos veces.
///
/// Solo entran movimientos manuales de entrada, salida y ajuste. Los
/// traspasos entre sucursales, las ventas y la deteccion por IA necesitan
/// conexion.
///
/// En Android y Windows la cola vive en SQLite y sobrevive a cerrar la app;
/// en web vive en memoria y se pierde al recargar la pagina.
class ColaMovimientosController extends ChangeNotifier {
  ColaMovimientosController(
    this._productService,
    this._localDb, {
    this.alSincronizar,
    int? Function()? usuarioActual,
  }) : _usuarioActual =
           usuarioActual ?? (() => SessionController.instance.user?.id);

  final ProductService _productService;
  final LocalDbService _localDb;

  /// Se llama cuando al menos un movimiento llego al servidor, para recargar
  /// el inventario y el historial.
  final VoidCallback? alSincronizar;
  final int? Function() _usuarioActual;

  List<MovimientoPendiente> _todos = const [];
  bool _sincronizando = false;
  ResultadoSincronizacion? _aviso;

  /// Movimientos de la cuenta que tiene la sesion abierta, en el orden en
  /// que se registraron. Los de otra cuenta esperan a que esa cuenta entre.
  List<MovimientoPendiente> get movimientos {
    final usuario = _usuarioActual();
    return [
      for (final m in _todos)
        if (m.usuarioId == usuario) m,
    ];
  }

  int get pendientes => movimientos.where((m) => !m.rechazado).length;
  int get rechazados => movimientos.where((m) => m.rechazado).length;
  bool get sincronizando => _sincronizando;

  /// Devuelve el resultado de la ultima sincronizacion una sola vez, para
  /// mostrarlo como aviso sin repetirlo en cada reconstruccion.
  ResultadoSincronizacion? tomarAviso() {
    final aviso = _aviso;
    _aviso = null;
    return aviso;
  }

  /// Clave unica por lote. Se genera ANTES del primer intento de envio: si
  /// ese intento falla por la red, el lote se encola con la misma clave.
  static String nuevaClave() {
    final azar = Random.secure();
    final hex = [
      for (var i = 0; i < 12; i++)
        azar.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return 'mov-${DateTime.now().microsecondsSinceEpoch}-$hex';
  }

  Future<void> cargar() async {
    try {
      final filas = await _localDb.obtenerPendientes();
      _todos = [for (final f in filas) MovimientoPendiente.fromMap(f)];
    } catch (e) {
      // Sin base local (por ejemplo en un test) la cola queda vacia.
      debugPrint('cargar cola de movimientos: $e');
      _todos = const [];
    }
    notifyListeners();
  }

  /// Guarda un lote para enviarlo despues. Lanza si no hay sesion.
  Future<void> encolar({
    required String clave,
    required String tipo,
    required int razonId,
    required String razonNombre,
    required int? sucursalId,
    required List<ItemPendiente> items,
  }) async {
    final usuario = _usuarioActual();
    if (usuario == null) {
      throw StateError('No hay sesión para guardar el movimiento pendiente.');
    }
    final pendiente = MovimientoPendiente(
      clave: clave,
      tipo: tipo,
      razonId: razonId,
      razonNombre: razonNombre,
      sucursalId: sucursalId,
      usuarioId: usuario,
      items: items,
      creadoEn: DateTime.now(),
    );
    await _localDb.guardarPendiente(pendiente.toMap());
    _todos = [
      for (final m in _todos)
        if (m.clave != clave) m,
      pendiente,
    ];
    notifyListeners();
  }

  /// Envia los pendientes en orden. Se detiene al primer fallo de red (el
  /// servidor sigue caido): lo que falta queda para el proximo intento.
  ///
  /// Un rechazo del servidor (por ejemplo, ya no hay stock para una salida)
  /// no se reintenta solo: el movimiento queda marcado como rechazado con el
  /// motivo, hasta que el usuario lo descarte.
  Future<ResultadoSincronizacion> sincronizar() async {
    if (_sincronizando) return const ResultadoSincronizacion();
    final porEnviar = movimientos.where((m) => !m.rechazado).toList();
    if (porEnviar.isEmpty) return const ResultadoSincronizacion();

    _sincronizando = true;
    notifyListeners();
    var enviados = 0;
    var rechazados = 0;
    try {
      for (final m in porEnviar) {
        try {
          await _productService.registrarLote(
            tipo: m.tipo,
            razonId: m.razonId,
            claveIdempotencia: m.clave,
            sucursalId: m.sucursalId,
            items: [
              for (final i in m.items)
                (productoId: i.productoId, cantidad: i.cantidad),
            ],
          );
          await _localDb.eliminarPendiente(m.clave);
          _todos = [
            for (final t in _todos)
              if (t.clave != m.clave) t,
          ];
          enviados++;
        } on ApiException catch (e) {
          // 401/403: la sesion vencio; no es un rechazo del movimiento. Y un
          // 5xx es una falla del servidor: se reintenta mas tarde.
          if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode >= 500) {
            break;
          }
          await _localDb.actualizarPendiente(
            m.clave,
            estado: MovimientoPendiente.estadoRechazado,
            detalle: e.detalle,
          );
          _todos = [
            for (final t in _todos)
              if (t.clave == m.clave)
                MovimientoPendiente(
                  clave: t.clave,
                  tipo: t.tipo,
                  razonId: t.razonId,
                  razonNombre: t.razonNombre,
                  sucursalId: t.sucursalId,
                  usuarioId: t.usuarioId,
                  items: t.items,
                  creadoEn: t.creadoEn,
                  estado: MovimientoPendiente.estadoRechazado,
                  detalle: e.detalle,
                )
              else
                t,
          ];
          rechazados++;
        } catch (e) {
          // Sin red: se corta aqui para respetar el orden.
          debugPrint('sincronizar cola: $e');
          break;
        }
      }
    } finally {
      _sincronizando = false;
    }
    final resultado = ResultadoSincronizacion(
      enviados: enviados,
      rechazados: rechazados,
    );
    if (!resultado.vacio) _aviso = resultado;
    notifyListeners();
    if (enviados > 0) alSincronizar?.call();
    return resultado;
  }

  /// Quita un movimiento de la cola sin enviarlo.
  Future<void> descartar(String clave) async {
    await _localDb.eliminarPendiente(clave);
    _todos = [
      for (final m in _todos)
        if (m.clave != clave) m,
    ];
    notifyListeners();
  }

  /// Vuelve a poner en la cola un movimiento rechazado (por ejemplo, tras
  /// reponer el stock que faltaba).
  Future<void> reintentar(String clave) async {
    await _localDb.actualizarPendiente(
      clave,
      estado: MovimientoPendiente.estadoPendiente,
      detalle: null,
    );
    await cargar();
    await sincronizar();
  }
}
