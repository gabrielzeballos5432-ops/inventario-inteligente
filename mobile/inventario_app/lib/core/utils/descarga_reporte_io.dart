import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Version nativa. Movil: menu de compartir (guardar en archivos, enviar,
/// imprimir). Escritorio: se guarda directo en Descargas y devuelve la ruta.
Future<String?> descargarReporte(
  List<int> bytes,
  String nombreArchivo,
  String mimeType,
) async {
  final esMovil = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (esMovil) {
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: mimeType,
        name: nombreArchivo,
      ),
    ]);
    return null;
  }

  final descargas = await getDownloadsDirectory();
  final directorio = descargas ?? await getTemporaryDirectory();
  final archivo = File(
      '${directorio.path}${Platform.pathSeparator}$nombreArchivo');
  await archivo.writeAsBytes(bytes, flush: true);
  return archivo.path;
}
