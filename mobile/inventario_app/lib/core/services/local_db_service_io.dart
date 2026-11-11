import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'inventario_zoom.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache_inventario (
        producto_id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        stock_actual INTEGER NOT NULL,
        stock_minimo INTEGER NOT NULL,
        precio_venta REAL NOT NULL,
        stock_bajo INTEGER NOT NULL DEFAULT 0,
        actualizado_en TEXT NOT NULL
      )
    ''');
  }

  Future<void> cachearInventario(List<Map<String, dynamic>> productos) async {
    final db = await database;
    // Transaccion + replace: varias pantallas pueden refrescar el inventario
    // a la vez (IndexedStack) y un delete+insert interleaved romperia la PK.
    await db.transaction((txn) async {
      await txn.delete('cache_inventario');
      for (final p in productos) {
        await txn.insert(
          'cache_inventario',
          {
            'producto_id': p['id'],
            'nombre': p['nombre'],
            'stock_actual': p['stock_actual'],
            'stock_minimo': p['stock_minimo'],
            'precio_venta': p['precio_venta'],
            'stock_bajo': p['stock_bajo'] == true ? 1 : 0,
            'actualizado_en': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> obtenerCacheInventario() async {
    final db = await database;
    return db.query('cache_inventario', orderBy: 'nombre ASC');
  }
}
