// Selecciona la implementacion de la base de datos local:
// - plataformas con dart:io (Android, iOS, Windows, Linux, macOS): sqflite
// - web: almacenamiento en memoria
export 'local_db_service_web.dart'
    if (dart.library.io) 'local_db_service_io.dart';
