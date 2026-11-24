import 'dart:async';

import 'package:http/http.dart' as http;

import '../network/api_client.dart';

/// Frase legible para cualquier error de una llamada al API.
///
/// Antes cada pantalla hacia `e is ApiException ? e.detalle : '$e'`, y el
/// resto de errores llegaba al usuario tal cual: "TimeoutException after
/// 0:00:12.000000: Future not completed" o "ClientException: Failed to fetch".
/// Aqui se traducen los casos de red; el rechazo del backend se muestra con
/// su propio mensaje.
String mensajeDeError(Object error) {
  if (error is ApiException) return error.detalle;
  if (error is TimeoutException) {
    return 'El servidor no respondió a tiempo. Revisa la conexión e '
        'intenta de nuevo.';
  }
  // En Android/escritorio package:http envuelve el SocketException en un
  // ClientException; en web es el "Failed to fetch" del navegador.
  if (error is http.ClientException) {
    return 'No se pudo conectar con el servidor. Revisa que esté encendido '
        'y que el equipo esté en la misma red.';
  }
  if (error is FormatException || error is TypeError) {
    return 'El servidor respondió con datos inesperados. Actualiza la app o '
        'avisa al administrador.';
  }
  final texto = '$error';
  return texto.startsWith('Exception: ') ? texto.substring(11) : texto;
}
