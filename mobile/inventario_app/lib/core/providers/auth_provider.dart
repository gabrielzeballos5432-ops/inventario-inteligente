import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../network/api_client.dart';
import '../services/auth_service.dart';
import '../session/session_controller.dart';
import '../session/token_jwt.dart';
import 'sucursal_controller.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _usuario;
  String? _errorMsg;

  bool _renovando = false;
  bool _cerrandoPorVencimiento = false;

  static const mensajeSesionVencida =
      'Tu sesión expiró. Vuelve a iniciar sesión.';

  AuthProvider(this._authService) {
    // Cualquier petición puede descubrir que la sesión murió (401) o que al
    // token le queda poco; el ApiClient avisa aquí.
    ApiClient.alSesionVencida = sesionVencida;
    ApiClient.alRenovarSesion = renovarSesion;
  }

  AuthStatus get status => _status;
  AuthUser? get usuario => _usuario;
  String? get errorMsg => _errorMsg;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _usuario?.isAdmin ?? false;

  Future<void> tryAutoLogin() async {
    await SessionController.instance.loadSession();
    // El token guardado puede haber vencido con la app cerrada: entrar con
    // él dejaba la app "abierta" pero con todo vacío (el servidor rechaza
    // cada petición). Se descarta y se pide iniciar sesión con aviso.
    if (SessionController.instance.isAuthenticated &&
        tokenVencido(SessionController.instance.token)) {
      await SessionController.instance.clearSession();
      _errorMsg = mensajeSesionVencida;
    }
    if (SessionController.instance.isAuthenticated) {
      _usuario = SessionController.instance.user;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      final user = AuthUser(
        id: result.usuarioId,
        nombre: result.nombre,
        email: email,
        rol: result.rol,
        activo: true,
      );

      await SessionController.instance.setSession(
        token: result.accessToken,
        user: user,
      );

      _usuario = user;
      _status = AuthStatus.authenticated;
      _errorMsg = null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMsg = 'Credenciales invalidas o servidor no disponible';
    }
    notifyListeners();
  }

  /// El servidor rechazó el token: vuelve al login con aviso. Varias
  /// peticiones fallan a la vez (inventario, sucursales, razones), así que
  /// solo actúa la primera.
  Future<void> sesionVencida() async {
    if (_status != AuthStatus.authenticated || _cerrandoPorVencimiento) return;
    _cerrandoPorVencimiento = true;
    try {
      await SucursalController.instance.reiniciar();
      await SessionController.instance.clearSession();
      _usuario = null;
      _status = AuthStatus.unauthenticated;
      _errorMsg = mensajeSesionVencida;
      notifyListeners();
    } finally {
      _cerrandoPorVencimiento = false;
    }
  }

  /// Pide un token nuevo mientras la sesión sigue vigente, para que un turno
  /// largo no termine en el login. Si falla por red no pasa nada: se vuelve a
  /// intentar con la próxima petición. Si el servidor ya no acepta la sesión,
  /// se trata como vencida.
  Future<void> renovarSesion() async {
    if (_status != AuthStatus.authenticated || _renovando) return;
    final actual = _usuario;
    if (actual == null) return;
    _renovando = true;
    try {
      final result = await _authService.renovar();
      final user = AuthUser(
        id: result.usuarioId,
        nombre: result.nombre,
        email: actual.email,
        rol: result.rol,
        activo: true,
      );
      await SessionController.instance.setSession(
        token: result.accessToken,
        user: user,
      );
      _usuario = user;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await sesionVencida();
    } catch (_) {
      // Sin conexión: se reintenta en la próxima respuesta correcta.
    } finally {
      _renovando = false;
    }
  }

  Future<void> logout() async {
    await SessionController.instance.clearSession();
    _usuario = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
