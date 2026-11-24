import '../config/api_config.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';

class DetectionService {
  final ApiClient _apiClient;

  DetectionService(this._apiClient);

  Future<List<Movimiento>> fetchHistory() async {
    // Los filtros de la pestaña Historial (tipo, periodo, producto) corren
    // del lado de la app: con 50 registros el filtro encontraba poco; 200
    // cubre un par de semanas de operacion sin pesar la lista.
    final json =
        await _apiClient.getJson(ApiConfig.historial, query: {'limite': '200'})
            as List<dynamic>;
    return json
        .map((item) => Movimiento.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Detecta productos en la foto SIN tocar el stock: el usuario revisa y
  /// corrige el resultado, y la entrada se registra al confirmar
  /// (`InventarioProvider.confirmarDeteccion`).
  Future<ResultadoInferencia> detectFromUpload(
    List<int> bytes,
    String fileName,
  ) async {
    final json = await _apiClient.postMultipart(
      ApiConfig.inferencia,
      fieldName: 'imagen',
      fileName: fileName,
      bytes: bytes,
      fields: const {'tipo_operacion': 'entrada', 'registrar': 'false'},
    );
    return ResultadoInferencia.fromJson(json as Map<String, dynamic>);
  }

  /// Recuadros para la camara en vivo: el servidor no guarda nada. Timeout
  /// corto: un cuadro que tarda mas ya no corresponde a lo que se ve.
  Future<ResultadoInferencia> vistaPrevia(List<int> bytes) async {
    final json = await _apiClient.postMultipart(
      ApiConfig.inferenciaVistaPrevia,
      fieldName: 'imagen',
      fileName: 'vista.jpg',
      bytes: bytes,
      timeout: const Duration(seconds: 6),
    );
    return ResultadoInferencia.fromJson(json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> salud() async {
    final json = await _apiClient.getJson(ApiConfig.salud);
    return json as Map<String, dynamic>;
  }
}
