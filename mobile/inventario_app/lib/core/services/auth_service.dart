import '../config/api_config.dart';
import '../models/auth_user.dart';
import '../network/api_client.dart';

class LoginResult {
  final String accessToken;
  final int usuarioId;
  final String nombre;
  final String rol;

  const LoginResult({
    required this.accessToken,
    required this.usuarioId,
    required this.nombre,
    required this.rol,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String? ?? '',
      usuarioId: json['usuario_id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      rol: json['rol'] as String? ?? 'vendedor',
    );
  }
}

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson(ApiConfig.login, {
      'email': email,
      'password': password,
    });
    return LoginResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final json = await _apiClient.getJson('/api/auth/me');
    return AuthUser.fromJson(json as Map<String, dynamic>);
  }
}
