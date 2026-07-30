import '../config/api_config.dart';
import '../models/detection_record.dart';
import '../network/api_client.dart';
import 'local_db_service.dart';

class SyncService {
  final ApiClient _apiClient;
  final LocalDbService _localDb;

  SyncService(this._apiClient, this._localDb);

  Future<int> sincronizarPendientes() async {
    final pendientes = await _localDb.obtenerPendientes();
    int sincronizados = 0;

    for (final item in pendientes) {
      try {
        final mov = Movimiento(
          id: 0,
          productoId: item['producto_id'] as int,
          tipo: item['tipo'] as String,
          cantidad: item['cantidad'] as int,
          usuarioId: 0,
          stockResultante: 0,
          origen: 'offline',
        );
        await _apiClient.postJson(ApiConfig.movimiento, mov.toJson());
        await _localDb.marcarSincronizado(item['id'] as int);
        sincronizados++;
      } catch (_) {}
    }

    return sincronizados;
  }
}
