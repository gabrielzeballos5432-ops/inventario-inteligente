import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../session/session_controller.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _usuario;
  String? _errorMsg;

  AuthProvider(this._authService);

  AuthStatus get status => _status;
  AuthUser? get usuario => _usuario;
  String? get errorMsg => _errorMsg;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _usuario?.isAdmin ?? false;

  Future<void> tryAutoLogin() async {
    await SessionController.instance.loadSession();
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

  Future<void> logout() async {
    await SessionController.instance.clearSession();
    _usuario = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
