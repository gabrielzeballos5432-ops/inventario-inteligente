import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../network/api_client.dart';

/// Estado de la conexion con el backend.
enum EstadoServidor {
  /// Todavia no se ha comprobado (arranque de la app).
  comprobando,

  /// El backend respondio al ultimo chequeo.
  conectado,

  /// El backend no respondio: caido, laptop suspendida o red distinta.
  desconectado,
}

/// Vigila si el backend responde de verdad.
///
/// Saber si el telefono tiene red no basta: cuando la laptop
/// se suspende el telefono sigue con Wi-Fi: por eso la app no se enteraba de
/// que el servidor se habia caido y solo quedaba el error al pedir datos.
///
/// Este controlador pregunta a `/api/health` cada pocos segundos y tambien al
/// volver del segundo plano (ver `ServidorGuard`). Cuando el servidor vuelve,
/// avisa por [onReconectado] para recargar los datos que quedaron viejos.
class ServidorController extends ChangeNotifier {
  ServidorController(
    this._apiClient, {
    this.onReconectado,
    this.intervalo = const Duration(seconds: 15),
  });

  final ApiClient _apiClient;

  /// Se llama solo en la transicion desconectado -> conectado.
  final VoidCallback? onReconectado;

  final Duration intervalo;

  EstadoServidor _estado = EstadoServidor.comprobando;
  EstadoServidor get estado => _estado;
  bool get conectado => _estado == EstadoServidor.conectado;

  Timer? _timer;
  bool _enCurso = false;

  /// Arranca el chequeo periodico. Solo se llama desde `main()`: los tests no
  /// deben dejar un timer vivo o `pumpAndSettle` no termina.
  void iniciar() {
    verificar();
    _timer = Timer.periodic(intervalo, (_) => verificar());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  /// Un chequeo puntual. Se ignora si ya hay uno en curso para no solapar.
  Future<void> verificar() async {
    if (_enCurso) return;
    _enCurso = true;
    final antes = _estado;
    try {
      await _apiClient.getJson(ApiConfig.salud);
      _cambiarEstado(EstadoServidor.conectado);
      if (antes == EstadoServidor.desconectado) {
        onReconectado?.call();
      }
    } catch (_) {
      // Timeout, socket cerrado o error HTTP: para el usuario es lo mismo,
      // el servidor no esta disponible.
      _cambiarEstado(EstadoServidor.desconectado);
    } finally {
      _enCurso = false;
    }
  }

  void _cambiarEstado(EstadoServidor nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    notifyListeners();
  }

  @override
  void dispose() {
    detener();
    super.dispose();
  }
}
