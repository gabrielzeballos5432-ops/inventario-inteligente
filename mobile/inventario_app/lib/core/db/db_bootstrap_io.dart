import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// En escritorio (Windows/Linux/macOS) sqflite no tiene plugin nativo:
// se usa la implementacion FFI con SQLite incluido (sqlite3_flutter_libs).
// En Android/iOS el plugin nativo se registra automaticamente.
void initLocalDatabase() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
