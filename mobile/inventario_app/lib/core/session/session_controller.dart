import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';

class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  final _storage = const FlutterSecureStorage();

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdmin => _user?.rol == 'administrador';

  Future<void> loadSession() async {
    final token = await _storage.read(key: 'auth_token');
    final userJson = await _storage.read(key: 'auth_user');
    if (token != null && userJson != null) {
      _token = token;
      _user = AuthUser.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      notifyListeners();
    }
  }

  Future<void> setSession({
    required String token,
    required AuthUser user,
  }) async {
    _token = token;
    _user = user;
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'auth_user', value: jsonEncode({
      'id': user.id,
      'nombre': user.nombre,
      'email': user.email,
      'rol': user.rol,
      'activo': user.activo,
    }));
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_user');
    notifyListeners();
  }
}
