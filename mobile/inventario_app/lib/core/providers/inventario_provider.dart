import 'package:flutter/foundation.dart';

import 'sucursal_controller.dart';

import '../models/product.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';
import '../services/product_service.dart';
import '../services/detection_service.dart';
import '../services/local_db_service.dart';

class InventarioProvider extends ChangeNotifier {
  final ProductService _productService;
  final DetectionService _detectionService;
  final LocalDbService _localDb;

  List<ProductoConStock> _productos = [];
  List<Movimiento> _historial = [];
  ResultadoInferencia? _ultimaInferencia;
  ValorizacionInventario? _valorizacion;
  bool? _yoloDisponible;
  bool _cargando = false;
  String? _error;

  /// Error de la ultima deteccion, aparte de [_error]: al volver de la
  /// camara la app recarga el inventario, y esa recarga ponia `_error` en
  /// null, asi que el rechazo de la deteccion no llegaba a verse.
  String? _errorDeteccion;

  InventarioProvider(
    this._productService,
    this._detectionService,
    this._localDb,
  );

  List<ProductoConStock> get productos => _productos;
  List<Movimiento> get historial => _historial;
  ResultadoInferencia? get ultimaInferencia => _ultimaInferencia;
  ValorizacionInventario? get valorizacion => _valorizacion;
  bool? get yoloDisponible => _yoloDisponible;
  bool get cargando => _cargando;
  String? get error => _error;
  String? get errorDeteccion => _errorDeteccion;
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
    } on ApiException catch (e) {
      // El servidor respondio (con error). Antes esto caia en el catch
      // generico y reportaba "sin conexion" tambien ante un 401 o un 500,
      // que depurar es mucho mas dificil. La cache se sigue mostrando para no
      // dejar la pantalla vacia, pero el mensaje dice la causa real.
      debugPrint('cargarInventario: HTTP ${e.statusCode} | ${e.body}');
      _productos = await _leerCache();
      _error = switch (e.statusCode) {
        401 || 403 => 'Sesion expirada o sin permisos. Vuelve a iniciar sesion.',
        404 => 'El servidor no encontro el recurso de inventario.',
        >= 500 => 'El servidor tiene un problema (HTTP ${e.statusCode}). '
            'Se muestran los datos de la ultima carga.',
        _ => 'El servidor rechazo la peticion (HTTP ${e.statusCode}). '
            'Se muestran los datos de la ultima carga.',
      };
    } catch (e, st) {
      // Solo aqui es un problema de red de verdad: no hay IP valida, el wifi
      // cayo o el servidor esta apagado.
      debugPrint('cargarInventario FALLA: $e | $st');
      _productos = await _leerCache();
      _error = 'Sin conexion con el servidor. '
          'Se muestran los datos de la ultima carga.';
    }

    _cargando = false;
    notifyListeners();
  }

  /// Lee el inventario desde la cache local de la ultima carga correcta.
  Future<List<ProductoConStock>> _leerCache() async {
    final cache = await _localDb.obtenerCacheInventario();
    return cache
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

  /// Recuadros en vivo mientras se apunta con la camara. No cambia el estado
  /// del provider: la deteccion que cuenta es la de la foto final.
  Future<ResultadoInferencia> vistaPrevia(List<int> bytes) =>
      _detectionService.vistaPrevia(bytes);

  Future<bool> enviarImagen(List<int> bytes, String fileName) async {
    _cargando = true;
    // Una foto nueva reemplaza el resultado anterior: si falla, no debe
    // quedar en pantalla la deteccion de la foto previa para confirmarla.
    _ultimaInferencia = null;
    _errorDeteccion = null;
    notifyListeners();

    try {
      _ultimaInferencia =
          await _detectionService.detectFromUpload(bytes, fileName);
      _cargando = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorDeteccion = e.statusCode == 503
          ? 'El reconocimiento con IA aun no esta activo: falta el modelo '
              'entrenado en el servidor. Puedes registrar el producto a mano '
              'desde la pestaña Productos.'
          : 'El servidor rechazo la foto: ${e.detalle}';
      _cargando = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorDeteccion = 'Sin conexion. No se pudo procesar la deteccion.';
      _cargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cargarValorizacion() async {
    try {
      _valorizacion = await _productService.valorizacion(
        sucursalId: SucursalController.instance.activaId,
      );
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

  /// Vuelve a pedir al servidor todo lo que la app muestra: inventario,
  /// historial, valorizacion y estado del modelo. Se usa desde el menu de
  /// usuario para que un cambio hecho en otro dispositivo (por ejemplo al
  /// editar un producto) aparezca sin cerrar y abrir la app.
  Future<void> refrescarTodo() async {
    await Future.wait([
      cargarInventario(),
      cargarHistorial(),
      cargarValorizacion(),
      consultarEstadoServidor(),
    ]);
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
    required int razonId,
    String origen = 'manual',
  }) async {
    try {
      await _productService.registrarMovimiento(
        productoId: productoId,
        tipo: tipo,
        cantidad: cantidad,
        razonId: razonId,
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

  /// Registra varios movimientos del mismo tipo y devuelve cuantos quedaron
  /// guardados.
  ///
  /// A diferencia de registrarMovimiento, aqui NO se atrapa ApiException: el
  /// 400 del lote trae el rechazo fila a fila ("Fila 2 (Esmalte Rojo 30):
  /// no hay stock suficiente: disponible 3") y el dialogo lo muestra tal
  /// cual; atraparlo lo degeneraria en 'No se pudo registrar el movimiento'
  /// y el usuario tendria que adivinar que fila corregir.
  Future<int> registrarLote({
    required String tipo,
    required List<({int productoId, int cantidad})> items,
    required int razonId,
    int? sucursalDestinoId,
  }) async {
    final resultado = await _productService.registrarLote(
      tipo: tipo,
      items: items,
      razonId: razonId,
      sucursalDestinoId: sucursalDestinoId,
    );
    await cargarInventario();
    await cargarHistorial();
    return resultado.guardados;
  }

  /// Registra la entrada de lo detectado por la IA, ya revisado por el
  /// usuario (cantidades corregidas; las filas en 0 no se envian). Va por
  /// lote con origen "ia" y la sesion de camara: el backend asigna la razon
  /// "Deteccion IA" y guarda todo o nada. Como en registrarLote, no se
  /// atrapa ApiException para que el detalle llegue a la pantalla.
  Future<ResultadoLote> confirmarDeteccion(
    List<({int productoId, int cantidad})> items,
  ) async {
    final filas = items.where((i) => i.cantidad > 0).toList();
    if (filas.isEmpty) return ResultadoLote(guardados: 0);
    final resultado = await _productService.registrarLote(
      tipo: 'entrada',
      items: filas,
      origen: 'ia',
      sesionId: _ultimaInferencia?.sesionId,
    );
    _ultimaInferencia = null;
    // La entrada ya quedo guardada: si falla la recarga (por ejemplo, se
    // corta la red justo despues), no debe parecer que fallo el registro, o
    // el usuario reintentaria y la duplicaria.
    try {
      await cargarInventario();
      await cargarHistorial();
    } catch (e) {
      debugPrint('recargar tras confirmar deteccion: $e');
      notifyListeners();
    }
    return resultado;
  }

  /// Descarta el resultado de la deteccion sin registrar nada.
  void descartarDeteccion() {
    _ultimaInferencia = null;
    _errorDeteccion = null;
    notifyListeners();
  }

  Future<void> registrarVenta(Map<String, dynamic> payload) async {
    await _productService.registrarVenta(payload);
    await cargarInventario();
    await cargarHistorial();
  }
}
