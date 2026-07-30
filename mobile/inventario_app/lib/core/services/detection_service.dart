import '../config/api_config.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';

class DetectionService {
  final ApiClient _apiClient;

  DetectionService(this._apiClient);

  Future<List<Movimiento>> fetchHistory() async {
    final json =
        await _apiClient.getJson(ApiConfig.historial, query: {'limite': '50'})
            as List<dynamic>;
    return json
        .map((item) => Movimiento.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ResultadoInferencia> detectFromUpload(String imagePath) async {
    final json = await _apiClient.postMultipart(
      ApiConfig.inferencia,
      fieldName: 'imagen',
      filePath: imagePath,
    );
    return ResultadoInferencia.fromJson(json as Map<String, dynamic>);
  }
}
