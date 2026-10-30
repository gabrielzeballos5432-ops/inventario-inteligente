import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/providers/theme_controller.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:inventario_app/core/services/sync_service.dart';
import 'package:inventario_app/features/shell/presentation/shell_page.dart';
import 'package:inventario_app/features/contabilidad/presentation/finanzas_page.dart';
import 'package:inventario_app/features/productos/presentation/products_page.dart';
import 'package:inventario_app/features/productos/presentation/marcas_dialog.dart';
import 'package:inventario_app/features/productos/presentation/proveedores_dialog.dart';
import 'package:inventario_app/shared/widgets/menu_lateral.dart';
import 'package:provider/provider.dart';

class _AuthPrueba extends AuthProvider {
  _AuthPrueba(ApiClient api, this.administrador) : super(AuthService(api));

  final bool administrador;

  @override
  bool get isAdmin => administrador;
}

class _InventarioPrueba extends InventarioProvider {
  _InventarioPrueba(ApiClient api)
    : super(
        ProductService(api),
        DetectionService(api),
        LocalDbService(),
        SyncService(api, LocalDbService()),
      );

  @override
  Future<void> cargarInventario() async {}

  @override
  Future<void> cargarValorizacion() async {}

  @override
  Future<void> cargarHistorial() async {}
}

const _reporte = {
  'costo_historico_completo': true,
  'detalles_sin_costo_historico': 0,
  'ventas_netas_bob': '100000.00',
  'costo_ventas_bob': '60000.00',
  'ganancia_bruta_bob': '40000.00',
  'gastos_operativos_bob': '12000.00',
  'sueldos_y_bonos_bob': '4000.00',
  'utilidad_operativa_bob': '24000.00',
  'utilidad_neta_estimada_bob': '24000.00',
  'nota': 'Estimación de prueba.',
};

Future<void> _montar(
  WidgetTester tester,
  List<String> peticiones, {
  required Size tamano,
  bool admin = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
  final api = ApiClient(
    httpClient: MockClient((peticion) async {
      peticiones.add(peticion.url.path);
      return http.Response(
        jsonEncode(
          peticion.url.path.endsWith('/reporte-financiero') ? _reporte : [],
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _AuthPrueba(api, admin),
        ),
        ChangeNotifierProvider<InventarioProvider>(
          create: (_) => _InventarioPrueba(api),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController.inicial(ThemeMode.dark),
        ),
        Provider(create: (_) => OperacionesService(api)),
      ],
      child: MaterialApp(theme: buildTemaNoche(), home: const ShellPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final tamano in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('catálogos en el shell, sin rutas superpuestas: $tamano', (
      tester,
    ) async {
      await _montar(tester, [], tamano: tamano);
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      for (final entrada in <String, Type>{
        'Categorías': CategoriasPage,
        'Marcas': MarcasPage,
        'Proveedores': ProveedoresPage,
        'Clientes': FinanzasPage,
      }.entries) {
        if (tamano.width < 1100) {
          scaffold.openDrawer();
          await tester.pumpAndSettle();
        }
        final menu = find.byType(MenuLateral);
        final destino = find.descendant(
          of: menu,
          matching: find.text(entrada.key),
        );
        await tester.scrollUntilVisible(
          destino,
          150,
          scrollable: find
              .descendant(of: menu, matching: find.byType(Scrollable))
              .first,
        );
        await tester.tap(destino);
        await tester.pumpAndSettle();
        expect(find.byType(entrada.value), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(
          tester.state<ScaffoldState>(find.byType(Scaffold)),
          same(scaffold),
        );
        expect(
          Navigator.of(tester.element(find.byType(ShellPage))).canPop(),
          isFalse,
        );
        expect(scaffold.isDrawerOpen, isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('escritorio: pantallas independientes y carga diferida', (
    tester,
  ) async {
    final peticiones = <String>[];
    await _montar(tester, peticiones, tamano: const Size(1440, 900));
    expect(peticiones, isEmpty);
    expect(find.byType(MenuLateral), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    final menu = find.byType(MenuLateral);
    await tester.ensureVisible(
      find.descendant(of: menu, matching: find.text('Compras')),
    );
    await tester.tap(find.descendant(of: menu, matching: find.text('Compras')));
    await tester.pumpAndSettle();
    expect(find.text('Compras e ingresos de mercadería'), findsOneWidget);
    expect(peticiones, contains('/api/compras/'));
    expect(peticiones, isNot(contains('/api/contabilidad/gastos')));
    final comprasCargadas = peticiones
        .where((p) => p == '/api/compras/')
        .length;
    await tester.ensureVisible(
      find.descendant(of: menu, matching: find.text('Resultados')),
    );
    await tester.tap(
      find.descendant(of: menu, matching: find.text('Resultados')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resumen del negocio'), findsOneWidget);
    expect(find.text('Ventas netas'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    await tester.scrollUntilVisible(
      find.descendant(of: menu, matching: find.text('Compras')),
      -180,
      scrollable: find
          .descendant(of: menu, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.descendant(of: menu, matching: find.text('Compras')));
    await tester.pumpAndSettle();
    expect(
      peticiones.where((p) => p == '/api/compras/').length,
      comprasCargadas,
    );
    expect(find.text('Compras e ingresos de mercadería'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('móvil: resultados caben y se accede desde el drawer', (
    tester,
  ) async {
    final peticiones = <String>[];
    await _montar(tester, peticiones, tamano: const Size(320, 640));
    expect(find.byType(MenuLateral), findsNothing);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    final destino = find.descendant(
      of: find.byType(MenuLateral),
      matching: find.text('Resultados'),
    );
    await tester.ensureVisible(destino);
    await tester.tap(destino);
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);
    expect(find.text('Resumen del negocio'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Utilidad neta estimada'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vendedor: sin finanzas administrativas y con Mi jornada', (
    tester,
  ) async {
    await _montar(tester, [], tamano: const Size(390, 844), admin: false);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Compras'), findsNothing);
    expect(find.text('Gastos'), findsNothing);
    expect(find.text('Resultados'), findsNothing);
    final jornada = find.text('Mi jornada');
    await tester.ensureVisible(jornada);
    await tester.tap(jornada);
    await tester.pumpAndSettle();
    expect(find.text('Marcar entrada'), findsOneWidget);
    expect(find.text('Marcar salida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
