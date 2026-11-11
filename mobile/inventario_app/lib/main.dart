import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/inventario_app.dart';
import 'core/config/api_config.dart';
import 'core/db/db_bootstrap.dart'
    if (dart.library.io) 'core/db/db_bootstrap_io.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/inventario_provider.dart';
import 'core/providers/servidor_controller.dart';
import 'core/providers/sucursal_controller.dart';
import 'core/providers/theme_controller.dart';
import 'core/network/api_client.dart';
import 'core/services/local_db_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/product_service.dart';
import 'core/services/detection_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/operaciones_service.dart';
import 'core/services/configuracion_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Servidor configurado desde la app (si cambia la IP del PC no hay que recompilar).
  await ApiConfig.init();

  // Modo claro / noche. Se lee antes de runApp para no arrancar en claro y
  // cambiar a noche un instante despues (el parpadeo se nota mucho).
  final themeController = await ThemeController.cargar();

  // Escritorio: SQLite via FFI. Web: no-op (BD local en memoria).
  initLocalDatabase();

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

  // Vigila que el backend responda (la laptop puede suspenderse y "desaparecer"
  // aunque el telefono siga con Wi-Fi). Al reconectar, recarga el inventario.
  final servidorController = ServidorController(
    apiClient,
    onReconectado: () => inventarioProvider.cargarInventario(),
  );
  servidorController.iniciar();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService(apiClient))..tryAutoLogin(),
        ),
        ChangeNotifierProvider.value(value: inventarioProvider),
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: servidorController),
        ChangeNotifierProvider.value(value: SucursalController.instance),
        Provider<ConfiguracionService>(
          create: (_) => ConfiguracionService(apiClient),
        ),
        Provider<OperacionesService>(
          create: (_) => OperacionesService(apiClient),
        ),
      ],
      child: const InventarioApp(),
    ),
  );
}
