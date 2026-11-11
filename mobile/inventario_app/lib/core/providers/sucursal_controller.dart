import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sucursal.dart';
import '../services/configuracion_service.dart';

/// Sucursal en la que opera la sesión y catálogos que dependen de ella.
///
/// Cada sesión arranca en la sucursal predeterminada de Configuración. Solo
/// el administrador puede cambiarla; la elección se guarda hasta cerrar
/// sesión, así que sobrevive a reiniciar la app con la sesión abierta. El
/// `ApiClient` manda `activaId` en el encabezado `X-Sucursal-Id` (el backend
/// lo ignora para el vendedor).
class SucursalController extends ChangeNotifier {
  SucursalController._();

  static final SucursalController instance = SucursalController._();

  static const _claveActiva = 'sucursal_activa';

  List<Sucursal> _sucursales = const [];
  List<RazonMovimiento> _razones = const [];
  int? _predeterminadaId;
  int? _activaId;
  bool _cargando = false;
  String? _error;

  List<Sucursal> get sucursales => _sucursales;
  List<RazonMovimiento> get razones => _razones;
  int? get predeterminadaId => _predeterminadaId;
  int? get activaId => _activaId;
  bool get cargando => _cargando;
  String? get error => _error;

  Sucursal? get activa => porId(_activaId);

  Sucursal? porId(int? id) {
    for (final sucursal in _sucursales) {
      if (sucursal.id == id) return sucursal;
    }
    return null;
  }

  /// Razones activas que se pueden elegir para un tipo de movimiento.
  List<RazonMovimiento> razonesDe(String tipo) =>
      _razones.where((r) => r.tipoMovimiento == tipo && r.activo).toList();

  /// Carga sucursales, predeterminada y razones. Si la sucursal guardada ya
  /// no existe o se desactivó, vuelve a la predeterminada.
  Future<void> cargar(ConfiguracionService servicio, {required bool esAdmin}) async {
    _cargando = true;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        servicio.fetchSucursales(),
        servicio.fetchSucursalPredeterminadaId(),
        servicio.fetchRazones(),
      ]);
      _sucursales = resultados[0] as List<Sucursal>;
      _predeterminadaId = resultados[1] as int;
      _razones = resultados[2] as List<RazonMovimiento>;
      final guardada = esAdmin ? await _leerGuardada() : null;
      _activaId = porId(guardada) != null ? guardada : _predeterminadaId;
      _error = null;
    } catch (e) {
      debugPrint('cargar sucursales: $e');
      _error = 'No se pudieron cargar las sucursales.';
    }
    _cargando = false;
    notifyListeners();
  }

  /// Cambia la sucursal activa (solo administrador). Devuelve false si no
  /// cambió, para no recargar el inventario de gusto.
  Future<bool> seleccionar(int id) async {
    if (id == _activaId || porId(id) == null) return false;
    _activaId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_claveActiva, id);
    } catch (_) {
      // Sin almacenamiento la elección dura hasta cerrar la app: no es grave.
    }
    return true;
  }

  /// Al cerrar sesión: la próxima sesión arranca en la predeterminada.
  Future<void> reiniciar() async {
    _activaId = null;
    _sucursales = const [];
    _razones = const [];
    _predeterminadaId = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveActiva);
    } catch (_) {}
  }

  Future<int?> _leerGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_claveActiva);
    } catch (_) {
      return null;
    }
  }

  /// Solo para tests: fija el estado sin pasar por la red.
  @visibleForTesting
  void fijarParaPruebas({
    List<Sucursal> sucursales = const [],
    List<RazonMovimiento> razones = const [],
    int? predeterminadaId,
    int? activaId,
  }) {
    _sucursales = sucursales;
    _razones = razones;
    _predeterminadaId = predeterminadaId;
    _activaId = activaId ?? predeterminadaId;
    notifyListeners();
  }
}
