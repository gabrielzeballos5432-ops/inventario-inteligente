import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventario_app/core/models/auth_user.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/session/session_controller.dart';
import 'package:inventario_app/core/session/token_jwt.dart';

/// Token con la forma de un JWT (la firma no se verifica en la app).
String _token(DateTime vence) {
  String parte(Map<String, dynamic> datos) =>
      base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
  return '${parte({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${parte({'sub': '1', 'rol': 'administrador', 'exp': vence.millisecondsSinceEpoch ~/ 1000})}'
      '.firma';
}

http.Response _json(Object cuerpo, [int estado = 200]) =>
    http.Response(jsonEncode(cuerpo), estado);

const _admin = AuthUser(
  id: 1,
  nombre: 'Admin',
  email: 'admin@zoom.com',
  rol: 'administrador',
  activo: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient.alSesionVencida = null;
    ApiClient.alRenovarSesion = null;
    await SessionController.instance.clearSession();
  });

  group('vencimiento del token', () {
    test('lee la fecha exp del token', () {
      final vence = DateTime.utc(2030, 1, 2, 3, 4, 5);
      expect(vencimientoToken(_token(vence)), vence);
    });

    test('vencido, vigente o ilegible', () {
      final ahora = DateTime.now().toUtc();
      expect(tokenVencido(_token(ahora.subtract(const Duration(minutes: 1)))), isTrue);
      expect(tokenVencido(_token(ahora.add(const Duration(hours: 2)))), isFalse);
      expect(tokenVencido('no-es-un-token'), isTrue);
      expect(tokenVencido(null), isTrue);
    });
  });

  group('ApiClient', () {
    test('un 401 avisa que la sesión venció', () async {
      var avisos = 0;
      ApiClient.alSesionVencida = () => avisos++;
      final api = ApiClient(
        httpClient: MockClient((_) async => _json({'detail': 'Token invalido'}, 401)),
      );
      await expectLater(api.getJson('/api/inventario/'), throwsA(isA<ApiException>()));
      expect(avisos, 1);
    });

    test('un 401 del login es contraseña incorrecta, no sesión vencida', () async {
      var avisos = 0;
      ApiClient.alSesionVencida = () => avisos++;
      final api = ApiClient(
        httpClient: MockClient((_) async => _json({'detail': 'Credenciales invalidas'}, 401)),
      );
      await expectLater(
        api.postJson('/api/auth/login', {'email': 'x@y.com', 'password': 'mal'}),
        throwsA(isA<ApiException>()),
      );
      expect(avisos, 0);
    });

    test('pide renovar solo cuando al token le queda menos de una hora', () async {
      var renovaciones = 0;
      ApiClient.alRenovarSesion = () => renovaciones++;
      final api = ApiClient(httpClient: MockClient((_) async => _json([])));
      final ahora = DateTime.now().toUtc();

      api.setToken(_token(ahora.add(const Duration(hours: 5))));
      await api.getJson('/api/inventario/');
      expect(renovaciones, 0);

      api.setToken(_token(ahora.add(const Duration(minutes: 30))));
      await api.getJson('/api/inventario/');
      expect(renovaciones, 1);
    });
  });

  group('AuthProvider', () {
    Future<AuthProvider> conSesion(String token, MockClient cliente) async {
      await SessionController.instance.setSession(token: token, user: _admin);
      final auth = AuthProvider(AuthService(ApiClient(httpClient: cliente)));
      await auth.tryAutoLogin();
      return auth;
    }

    test('al abrir la app con el token vencido pide iniciar sesión con aviso', () async {
      final vencido = _token(DateTime.now().toUtc().subtract(const Duration(hours: 1)));
      final auth = await conSesion(vencido, MockClient((_) async => _json([])));
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMsg, AuthProvider.mensajeSesionVencida);
      expect(SessionController.instance.token, isNull);
    });

    test('con el token vigente entra directo', () async {
      final vigente = _token(DateTime.now().toUtc().add(const Duration(hours: 4)));
      final auth = await conSesion(vigente, MockClient((_) async => _json([])));
      expect(auth.isAuthenticated, isTrue);
      expect(auth.errorMsg, isNull);
    });

    test('un 401 en plena sesión vuelve al login una sola vez', () async {
      final vigente = _token(DateTime.now().toUtc().add(const Duration(hours: 4)));
      final auth = await conSesion(vigente, MockClient((_) async => _json([])));
      var notificaciones = 0;
      auth.addListener(() => notificaciones++);

      // Varias peticiones fallan juntas al vencer la sesión.
      final api = ApiClient(
        httpClient: MockClient((_) async => _json({'detail': 'Token invalido'}, 401)),
      );
      await Future.wait([
        for (final ruta in ['/api/inventario/', '/api/sucursales/', '/api/razones-movimiento/'])
          api.getJson(ruta).then((_) {}, onError: (_) {}),
      ]);
      await pumpEventQueue();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMsg, AuthProvider.mensajeSesionVencida);
      expect(SessionController.instance.token, isNull);
      expect(notificaciones, 1);
    });

    test('renovar guarda el token nuevo y sigue en sesión', () async {
      final viejo = _token(DateTime.now().toUtc().add(const Duration(minutes: 20)));
      final nuevo = _token(DateTime.now().toUtc().add(const Duration(hours: 8)));
      final auth = await conSesion(
        viejo,
        MockClient((peticion) async {
          expect(peticion.url.path, '/api/auth/renovar');
          return _json({
            'access_token': nuevo,
            'usuario_id': 1,
            'nombre': 'Admin',
            'rol': 'administrador',
          });
        }),
      );
      await auth.renovarSesion();
      expect(auth.isAuthenticated, isTrue);
      expect(SessionController.instance.token, nuevo);
    });

    test('si el servidor ya no acepta la sesión al renovar, vuelve al login', () async {
      final viejo = _token(DateTime.now().toUtc().add(const Duration(minutes: 20)));
      final auth = await conSesion(
        viejo,
        MockClient((_) async => _json({'detail': 'Usuario desactivado'}, 403)),
      );
      await auth.renovarSesion();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMsg, AuthProvider.mensajeSesionVencida);
    });

    test('sin conexión al renovar, la sesión sigue igual', () async {
      final viejo = _token(DateTime.now().toUtc().add(const Duration(minutes: 20)));
      final auth = await conSesion(
        viejo,
        MockClient((_) async => throw http.ClientException('sin red')),
      );
      await auth.renovarSesion();
      expect(auth.isAuthenticated, isTrue);
      expect(SessionController.instance.token, viejo);
    });
  });
}
