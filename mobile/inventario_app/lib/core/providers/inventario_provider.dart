import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/detection_record.dart';
import '../services/product_service.dart';
import '../services/detection_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

class InventarioProvider extends ChangeNotifier {
  final ProductService _productService;
  final DetectionService _detectionService;
  final LocalDbService _localDb;
  final SyncService _syncService;

  List<ProductoConStock> _productos = [];
  List<Movimiento> _historial = [];
  ResultadoInferencia? _ultimaInferencia;
  bool _cargando = false;
  String? _error;

  InventarioProvider(
    this._productService,
    this._detectionService,
    this._localDb,
    this._syncService,
  );

  List<ProductoConStock> get productos => _productos;
  List<Movimiento> get historial => _historial;
  ResultadoInferencia? get ultimaInferencia => _ultimaInferencia;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarInventario() async {
    _cargando = true;
    notifyListeners();

    try {
      _productos = await _productService.obtenerInventario();
      await _localDb.cachearInventario(
        _productos
            .map((p) => {
                  'id': p.id,
                  'nombre': p.nombre,
                  'stock_actual': p.stockActual,
                  'stock_minimo': p.stockMinimo,
                  'precio_venta': p.precioVenta,
                  'stock_bajo': p.stockBajo,
                })
            .toList(),
      );
      _error = null;
    } catch (e) {
      final cache = await _localDb.obtenerCacheInventario();
      _productos = cache
          .map((c) => ProductoConStock(
                id: c['producto_id'] as int,
                nombre: c['nombre'] as String,
                stockActual: c['stock_actual'] as int,
                stockMinimo: c['stock_minimo'] as int,
                precioVenta: (c['precio_venta'] as num).toDouble(),
                stockBajo: (c['stock_bajo'] as int) == 1,
                activo: true,
              ))
          .toList();
      _error = 'Mostrando datos en cache (sin conexion)';
    }

    _cargando = false;
    notifyListeners();
  }

  Future<void> cargarHistorial() async {
    try {
      _historial = await _detectionService.fetchHistory();
      _error = null;
    } catch (e) {
      _error = 'Error al cargar historial';
    }
    notifyListeners();
  }

  Future<bool> enviarImagen(String imagePath) async {
    _cargando = true;
    notifyListeners();

    try {
      _ultimaInferencia = await _detectionService.detectFromUpload(imagePath);
      _error = null;
      _cargando = false;
      notifyListeners();
      await cargarInventario();
      return true;
    } catch (e) {
      final file = File(imagePath);
      if (await file.exists()) {
        await _localDb.encolarMovimiento(0, 'salida_ia', 1);
      }
      _error = 'Sin conexion. Movimiento encolado para sincronizar.';
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<int> sincronizar() async {
    final count = await _syncService.sincronizarPendientes();
    if (count > 0) {
      await cargarInventario();
    }
    return count;
  }
}
