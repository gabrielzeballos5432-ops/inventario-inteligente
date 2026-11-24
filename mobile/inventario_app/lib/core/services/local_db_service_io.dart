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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Version 2: cola de movimientos hechos sin conexion.
  static const _crearCola = '''
      CREATE TABLE cola_movimiento (
        clave TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        razon_id INTEGER NOT NULL,
        razon_nombre TEXT NOT NULL,
        sucursal_id INTEGER,
        usuario_id INTEGER NOT NULL,
        items TEXT NOT NULL,
        creado_en TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        detalle TEXT
      )
  ''';

  Future<void> _onUpgrade(Database db, int anterior, int nueva) async {
    if (anterior < 2) await db.execute(_crearCola);
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
    await db.execute(_crearCola);
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

  // ------------------------------------------------ cola de movimientos

  Future<void> guardarPendiente(Map<String, dynamic> fila) async {
    final db = await database;
    await db.insert(
      'cola_movimiento',
      fila,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// En el orden en que se registraron: asi se envian al sincronizar.
  Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final db = await database;
    return db.query('cola_movimiento', orderBy: 'creado_en ASC');
  }

  Future<void> actualizarPendiente(
    String clave, {
    required String estado,
    String? detalle,
  }) async {
    final db = await database;
    await db.update(
      'cola_movimiento',
      {'estado': estado, 'detalle': detalle},
      where: 'clave = ?',
      whereArgs: [clave],
    );
  }

  Future<void> eliminarPendiente(String clave) async {
    final db = await database;
    await db.delete('cola_movimiento', where: 'clave = ?', whereArgs: [clave]);
  }
}
