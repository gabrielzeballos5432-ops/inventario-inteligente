import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/app/inventario_app.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/providers/servidor_controller.dart';
import 'package:inventario_app/core/providers/theme_controller.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/product_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('muestra la pantalla de login sin sesión', (tester) async {
    final apiClient = ApiClient();
    final localDb = LocalDbService();
    final inventarioProvider = InventarioProvider(
      ProductService(apiClient),
      DetectionService(apiClient),
      localDb,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(AuthService(apiClient))..tryAutoLogin(),
          ),
          ChangeNotifierProvider.value(value: inventarioProvider),
          ChangeNotifierProvider.value(value: ServidorController(apiClient)),
          ChangeNotifierProvider.value(
            value: ThemeController.inicial(ThemeMode.dark),
          ),
        ],
        child: const InventarioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}