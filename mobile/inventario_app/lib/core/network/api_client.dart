import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../providers/sucursal_controller.dart';
import '../session/session_controller.dart';
import '../session/token_jwt.dart';

class ApiClient {
  final http.Client _httpClient;
  String? _token;

  /// Espera maxima de una peticion normal. Sin un timeout explicito, package:http
  /// espera al del sistema (o indefinitely) y con el servidor apagado la app
  /// se queda congelada varios minutos antes de avisar: el usuario ve la app
  /// colgada y no sabe si fallo.
  static const Duration timeoutPeticion = Duration(seconds: 12);

  /// La deteccion por imagen sube el archivo y luego el backend carga el
  /// modelo YOLO, con lo que necesita bastante mas margen que un GET.
  static const Duration timeoutSubida = Duration(minutes: 2);

  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Se llama cuando el servidor rechaza el token (401): la sesión venció o
  /// dejó de ser válida. Lo registra AuthProvider para volver al login con
  /// aviso, en vez de dejar la app abierta con todo vacío.
  static void Function()? alSesionVencida;

  /// Se llama tras una respuesta correcta si al token le queda poco: la app
  /// lo renueva sola y quien está trabajando no termina en el login.
  static void Function()? alRenovarSesion;

  /// Con menos de esto por delante, el token se renueva.
  static const Duration margenRenovacion = Duration(hours: 1);

  /// Rutas donde un 401 no significa "sesión vencida": en el login es una
  /// contraseña incorrecta, y la renovación maneja su propio rechazo.
  static const _rutasSinSesion = {'/api/auth/login', '/api/auth/renovar'};

  void setToken(String? token) {
    _token = token;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query);
  }

  Map<String, String> _buildHeaders({bool includeJson = true, int? sucursalId}) {
    final headers = <String, String>{};
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _token ?? SessionController.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    // Sucursal en la que se registra la operacion. El backend solo la
    // respeta para el administrador; al vendedor lo deja en la predeterminada.
    // Un movimiento de la cola offline se envia con la sucursal en la que se
    // hizo, aunque la activa haya cambiado desde entonces.
    final sucursal = sucursalId ?? SucursalController.instance.activaId;
    if (sucursal != null) {
      headers['X-Sucursal-Id'] = '$sucursal';
    }
    return headers;
  }

  void _ensureSuccess(http.Response response, String ruta) {
    final conSesion = !_rutasSinSesion.contains(ruta);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (conSesion) _quizasRenovar();
      return;
    }
    if (response.statusCode == 401 && conSesion) {
      alSesionVencida?.call();
    }
    throw ApiException(response.statusCode, response.body);
  }

  void _quizasRenovar() {
    final vence = vencimientoToken(_token ?? SessionController.instance.token);
    if (vence == null) return;
    final restante = vence.difference(DateTime.now().toUtc());
    if (restante > Duration.zero && restante < margenRenovacion) {
      alRenovarSesion?.call();
    }
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final response = await _httpClient
        .get(_buildUri(path, query), headers: _buildHeaders())
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<String> getRaw(String path) async {
    final response = await _httpClient
        .get(_buildUri(path), headers: _buildHeaders(includeJson: false))
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    return utf8.decode(response.bodyBytes);
  }

  Future<List<int>> getBytes(String path, {Map<String, String>? query}) async {
    final response = await _httpClient.get(
      _buildUri(path, query),
      headers: _buildHeaders(includeJson: false),
    );
    _ensureSuccess(response, path);
    return response.bodyBytes;
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    int? sucursalId,
  }) async {
    final response = await _httpClient
        .post(
          _buildUri(path),
          headers: _buildHeaders(sucursalId: sucursalId),
          body: jsonEncode(body),
        )
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient
        .put(_buildUri(path), headers: _buildHeaders(), body: jsonEncode(body))
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _httpClient
        .delete(_buildUri(path), headers: _buildHeaders())
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient
        .patch(
          _buildUri(path),
          headers: _buildHeaders(),
          body: jsonEncode(body),
        )
        .timeout(timeoutPeticion);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> postMultipart(
    String path, {
    required String fieldName,
    required String fileName,
    required List<int> bytes,
    Map<String, String>? fields,
    Duration timeout = timeoutSubida,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path));
    request.headers.addAll(_buildHeaders(includeJson: false));
    request.fields.addAll(fields ?? {});
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
    );
    final response = await (() async {
      final streamed = await _httpClient.send(request);
      return http.Response.fromStream(streamed);
    })().timeout(timeout);
    _ensureSuccess(response, path);
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  /// Texto legible del rechazo del backend. FastAPI responde
  /// {"detail": "..."}, y sin esto los mensajes de la app muestran el JSON
  /// crudo: el usuario ve Error HTTP 400: {"detail":"Ya existe..."} en vez
  /// de la frase que explica el problema.
  String get detalle {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final d = json['detail'];
        if (d is String) return d;
        if (d is List && d.isNotEmpty) return d.first.toString();
      }
    } catch (_) {
      // El cuerpo no es JSON (por ejemplo un HTML de proxy): se devuelve tal cual.
    }
    return body;
  }

  @override
  String toString() => 'Error HTTP $statusCode: $body';
}
