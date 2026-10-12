import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';
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
  ValorizacionInventario? _valorizacion;
  bool? _yoloDisponible;
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
  ValorizacionInventario? get valorizacion => _valorizacion;
  bool? get yoloDisponible => _yoloDisponible;
  bool get cargando => _cargando;
  String? get error => _error;
  ProductService get productService => _productService;

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
    } catch (e, st) {
      debugPrint('cargarInventario FALLA: $e | $st');
      final cache = await _localDb.obtenerCacheInventario();
      _productos = cache
          .map((c) => ProductoConStock(
                id: c['producto_id'] as int,
                nombre: c['nombre'] as String,
                stockActual: c['stock_actual'] as int,
                stockMinimo: c['stock_minimo'] as int,
                precioCompra: 0,
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

  Future<bool> enviarImagen(List<int> bytes, String fileName) async {
    _cargando = true;
    notifyListeners();

    try {
      _ultimaInferencia =
          await _detectionService.detectFromUpload(bytes, fileName);
      _error = null;
      _cargando = false;
      notifyListeners();
      await cargarInventario();
      return true;
    } on ApiException catch (e) {
      _error = e.statusCode == 503
          ? 'El reconocimiento con IA aun no esta activo: falta el modelo '
              'entrenado en el servidor. Puedes registrar el producto a mano '
              'desde la pestaña Productos.'
          : 'El servidor rechazo la peticion (HTTP ${e.statusCode}).';
      _cargando = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sin conexion. No se pudo procesar la deteccion.';
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cargarValorizacion() async {
    try {
      _valorizacion = await _productService.valorizacion();
      notifyListeners();
    } catch (e) {
      debugPrint('cargarValorizacion FALLA: $e');
    }
  }

  Future<void> consultarEstadoServidor() async {
    try {
      final json = await _detectionService.salud();
      _yoloDisponible = json['yolo_disponible'] as bool?;
    } catch (e) {
      _yoloDisponible = null;
      debugPrint('consultarEstadoServidor FALLA: $e');
    }
    notifyListeners();
  }

  Future<int> sincronizar() async {
    final count = await _syncService.sincronizarPendientes();
    if (count > 0) {
      await cargarInventario();
    }
    return count;
  }

  Future<bool> crearProducto(Map<String, dynamic> payload) async {
    try {
      await _productService.createProduct(payload);
      await cargarInventario();
      return true;
    } catch (e) {
      _error = 'No se pudo registrar el producto';
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarProducto(
      int id, Map<String, dynamic> payload) async {
    try {
      await _productService.updateProduct(id, payload);
      await cargarInventario();
      return true;
    } catch (e) {
      _error = 'No se pudo actualizar el producto';
      notifyListeners();
      return false;
    }
  }

  Future<bool> desactivarProducto(int id) async {
    try {
      await _productService.deactivateProduct(id);
      await cargarInventario();
      return true;
    } catch (e) {
      _error = 'No se pudo dar de baja el producto';
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarStockMinimo(int id, int stockMinimo) async {
    try {
      await _productService.updateStockMinimo(id, stockMinimo);
      await cargarInventario();
      return true;
    } catch (e) {
      _error = 'No se pudo actualizar el stock minimo';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registrarMovimiento({
    required int productoId,
    required String tipo,
    required int cantidad,
    String origen = 'manual',
  }) async {
    try {
      await _productService.registrarMovimiento(
        productoId: productoId,
        tipo: tipo,
        cantidad: cantidad,
        origen: origen,
      );
      await cargarInventario();
      await cargarHistorial();
      return true;
    } catch (e) {
      _error = 'No se pudo registrar el movimiento';
      notifyListeners();
      return false;
    }
  }
}
