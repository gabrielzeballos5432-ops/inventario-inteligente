import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/inventario_app.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/inventario_provider.dart';
import 'core/network/api_client.dart';
import 'core/services/local_db_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/product_service.dart';
import 'core/services/detection_service.dart';
import 'core/services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final localDb = LocalDbService();
  final syncService = SyncService(apiClient, localDb);
  final inventarioProvider = InventarioProvider(
    ProductService(apiClient),
    DetectionService(apiClient),
    localDb,
    syncService,
  );

  final connectivityService = ConnectivityService(
    syncService: syncService,
    localDb: localDb,
    onSyncComplete: () => inventarioProvider.cargarInventario(),
  );
  connectivityService.iniciar();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService(apiClient))..tryAutoLogin(),
        ),
        ChangeNotifierProvider.value(value: inventarioProvider),
      ],
      child: const InventarioApp(),
    ),
  );
}
