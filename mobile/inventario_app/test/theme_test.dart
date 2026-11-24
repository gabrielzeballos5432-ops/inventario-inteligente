import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/app/inventario_app.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/providers/servidor_controller.dart';
import 'package:inventario_app/core/providers/theme_controller.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ratio de contraste segun WCAG 2.1: (L1 + 0.05) / (L2 + 0.05).
double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

/// Monta la app completa con el modo indicado, igual que hace main().
Future<void> _montarApp(WidgetTester tester, ThemeMode modo) async {
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
        ChangeNotifierProvider.value(value: ThemeController.inicial(modo)),
      ],
      child: const InventarioApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  // ------------------------------------------------------------- el login
  testWidgets('la pantalla de login también funciona en modo claro',
      (tester) async {
    await _montarApp(tester, ThemeMode.light);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Acceso al sistema'), findsOneWidget);
  });

  testWidgets('el modo elegido es el que se aplica a la pantalla', (tester) async {
    await _montarApp(tester, ThemeMode.light);
    final contexto = tester.element(find.text('Acceso al sistema'));
    expect(Theme.of(contexto).brightness, Brightness.light);
    expect(Theme.of(contexto).extension<AppPaleta>(), isNotNull);
  });

  // ------------------------------------------------------------- la paleta
  test('los dos modos traen su paleta semantica', () {
    expect(buildTemaNoche().brightness, Brightness.dark);
    expect(buildTemaClaro().brightness, Brightness.light);
    expect(buildTemaNoche().extension<AppPaleta>()!.fondo, AppColors.negro);
    expect(buildTemaClaro().extension<AppPaleta>()!.fondo, isNot(AppColors.negro));
  });

  test('el modo noche conserva el aspecto que tenia la app', () {
    final p = AppPaleta.oscuro;
    expect(p.superficie, AppColors.plomo);
    expect(p.superficieElevada, AppColors.plomoClaro);
    expect(p.textoPrimario, Colors.white);
  });

  test('el modo claro usa fondo claro y superficie blanca', () {
    final p = AppPaleta.claro;
    expect(p.superficie, Colors.white);
    // "Claro" tiene que ser de verdad mas claro que el texto, no al reves.
    expect(p.fondo.computeLuminance(), greaterThan(p.textoPrimario.computeLuminance()));
    expect(p.fondo.computeLuminance(), greaterThan(p.textoSecundario.computeLuminance()));
  });

  test('los textos se leen sobre el fondo en los dos modos', () {
    for (final p in [AppPaleta.oscuro, AppPaleta.claro]) {
      expect(_ratio(p.textoPrimario, p.fondo), greaterThanOrEqualTo(4.5),
          reason: 'texto principal sobre el fondo');
      expect(_ratio(p.textoSecundario, p.fondo), greaterThanOrEqualTo(4.5),
          reason: 'texto secundario sobre el fondo');
      expect(_ratio(p.textoPrimario, p.superficie), greaterThanOrEqualTo(4.5),
          reason: 'texto principal sobre la tarjeta');
      expect(_ratio(p.textoSecundario, p.superficie), greaterThanOrEqualTo(4.5),
          reason: 'texto secundario sobre la tarjeta');
    }
  });

  test('los colores de estado se leen sobre el fondo y sobre la tarjeta', () {
    for (final p in [AppPaleta.oscuro, AppPaleta.claro]) {
      for (final entry in {
        'stockBajo': p.stockBajo,
        'positivo': p.positivo,
        'negativo': p.negativo,
        'aviso': p.aviso,
        'info': p.info,
      }.entries) {
        expect(_ratio(entry.value, p.fondo), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} sobre el fondo');
        expect(_ratio(entry.value, p.superficie), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} sobre la tarjeta');
      }
    }
  });

  test('el morado de marca lleva texto blanco con contraste suficiente', () {
    // Se usa en botones y barra de navegacion en los dos modos.
    expect(_ratio(Colors.white, AppColors.morado), greaterThanOrEqualTo(4.5));
  });

  // ---------------------------------------------------- el controlador
  test('el controlador por defecto arranca en modo noche', () async {
    final controller = await ThemeController.cargar();
    expect(controller.esNoche, isTrue);
    expect(controller.modo, ThemeMode.dark);
  });

  test('alternar cambia de noche a claro y se guarda', () async {
    final controller = await ThemeController.cargar();
    await controller.alternar();

    expect(controller.modo, ThemeMode.light);
    expect(controller.esNoche, isFalse);

    // La preferencia tiene que sobrevivir a cerrar y abrir la app.
    final recargado = await ThemeController.cargar();
    expect(recargado.modo, ThemeMode.light);
  });

  test('alternar dos veces vuelve al modo noche', () async {
    final controller = await ThemeController.cargar();
    await controller.alternar();
    await controller.alternar();

    expect(controller.modo, ThemeMode.dark);
    final recargado = await ThemeController.cargar();
    expect(recargado.modo, ThemeMode.dark);
  });

  test('el cambio de modo avisa a quien este escuchando', () async {
    final controller = ThemeController.inicial(ThemeMode.dark);
    var avisos = 0;
    controller.addListener(() => avisos++);

    await controller.alternar();
    expect(avisos, 1);

    // Poner el mismo modo dos veces no deberia redibujar la app entera.
    await controller.setModo(ThemeMode.light);
    expect(avisos, 1);
  });
}