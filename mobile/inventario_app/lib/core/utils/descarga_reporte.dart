import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Comparte/guarda un reporte. Version web: se envia al menu de compartir
/// del navegador (descarga el archivo).
/// En nativo se usa descarga_reporte_io.dart (import condicional).
Future<String?> descargarReporte(
  List<int> bytes,
  String nombreArchivo,
  String mimeType,
) async {
  await Share.shareXFiles([
    XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mimeType,
      name: nombreArchivo,
    ),
  ]);
  return null;
}
