import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/models/product.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:inventario_app/core/services/sync_service.dart';
import 'package:inventario_app/features/ventas/presentation/sales_page.dart';
import 'package:provider/provider.dart';

class _InventarioPrueba extends InventarioProvider {
  _InventarioPrueba(ApiClient api)
    : super(
        ProductService(api),
        DetectionService(api),
        LocalDbService(),
        SyncService(api, LocalDbService()),
      );

  final ventas = <Map<String, dynamic>>[];
  Completer<void>? pendiente;

  @override
  List<ProductoConStock> get productos => [
    ProductoConStock(
      id: 1,
      sku: 'ZOOM-1',
      nombre: 'Producto de prueba',
      precioCompra: 10,
      precioVenta: 20,
      stockMinimo: 1,
      activo: true,
      stockActual: 10,
      stockBajo: false,
    ),
  ];

  @override
  Future<void> cargarInventario() async {}

  @override
  Future<void> registrarVenta(Map<String, dynamic> payload) async {
    ventas.add(payload);
    if (pendiente != null) await pendiente!.future;
  }
}

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

Future<_InventarioPrueba> _montar(WidgetTester tester, Size tamano) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
  final api = ApiClient(
    httpClient: MockClient((_) async => http.Response('[]', 200)),
  );
  final inventario = _InventarioPrueba(api);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(AuthService(api)),
        ),
        ChangeNotifierProvider<InventarioProvider>(create: (_) => inventario),
        Provider(create: (_) => OperacionesService(api)),
      ],
      child: MaterialApp(
        theme: buildTemaNoche(),
        home: const Scaffold(body: SalesPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return inventario;
}

void main() {
  for (final tamano in [const Size(600, 844), const Size(1440, 900)]) {
    testWidgets('Tab baja entre campos y Shift+Tab retrocede: $tamano', (
      tester,
    ) async {
      final inventario = await _montar(tester, tamano);
      await tester.enterText(_campo('Código'), 'ZOOM-1');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_campo('Cantidad')).focusNode!.hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(_campo('Monto total (Bs)'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_campo('Cantidad')).focusNode!.hasFocus,
        isTrue,
      );
      expect(inventario.ventas, isEmpty);
    });
  }

  bool enfocado(WidgetTester tester, String etiqueta) =>
      tester.widget<TextField>(_campo(etiqueta)).focusNode!.hasFocus;

  Future<void> ctrlEnter(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  for (final tecla in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  ]) {
    testWidgets('$tecla avanza Código → Cantidad → Monto y agrega la fila', (
      tester,
    ) async {
      final inventario = await _montar(tester, const Size(1440, 900));
      await tester.enterText(_campo('Código'), 'ZOOM-1');
      await tester.sendKeyEvent(tecla);
      await tester.pumpAndSettle();
      expect(enfocado(tester, 'Cantidad'), isTrue);

      await tester.enterText(_campo('Cantidad'), '2');
      await tester.sendKeyEvent(tecla);
      await tester.pumpAndSettle();
      expect(enfocado(tester, 'Monto total (Bs)'), isTrue);

      await tester.enterText(_campo('Monto total (Bs)'), '30');
      await tester.sendKeyEvent(tecla);
      await tester.pumpAndSettle();
      // La fila quedó agregada y la captura vuelve a Código, sin cobrar.
      expect(inventario.ventas, isEmpty);
      expect(enfocado(tester, 'Código'), isTrue);
      expect(
        tester.widget<TextField>(_campo('Código')).controller!.text,
        isEmpty,
      );

      // Enter con el código vacío registra la venta.
      await tester.sendKeyEvent(tecla);
      await tester.pumpAndSettle();
      expect(inventario.ventas, hasLength(1));
      expect(inventario.ventas.single['detalles'], [
        {
          'producto_id': 1,
          'cantidad': 2,
          'precio_unitario_negociado': '15.00',
          'total_linea': '30.00',
        },
      ]);
    });
  }

  testWidgets('lector de códigos: código + Enter carga el producto sin cobrar', (
    tester,
  ) async {
    final inventario = await _montar(tester, const Size(1440, 900));
    await tester.enterText(_campo('Código'), 'ZOOM-1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(inventario.ventas, isEmpty);
    expect(enfocado(tester, 'Cantidad'), isTrue);
    expect(find.text('Producto de prueba'), findsWidgets);
  });

  for (final etiqueta in ['Código', 'Cantidad', 'Monto total (Bs)']) {
    testWidgets('Ctrl+Enter registra desde $etiqueta con la captura', (
      tester,
    ) async {
      final inventario = await _montar(tester, const Size(1440, 900));
      await tester.enterText(_campo('Código'), 'ZOOM-1');
      await tester.enterText(_campo('Cantidad'), '2');
      await tester.enterText(_campo('Monto total (Bs)'), '30');
      await tester.tap(_campo(etiqueta));
      await ctrlEnter(tester);
      expect(inventario.ventas, hasLength(1));
      expect(inventario.ventas.single['detalles'], hasLength(1));
      expect(
        tester.widget<TextField>(_campo('Código')).controller!.text,
        isEmpty,
      );
    });
  }

  testWidgets('Ctrl+Enter incluye captura pendiente con filas ya agregadas', (
    tester,
  ) async {
    final inventario = await _montar(tester, const Size(1440, 900));
    await tester.enterText(_campo('Código'), 'ZOOM-1');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(_campo('Código'), 'ZOOM-1');
    await tester.enterText(_campo('Cantidad'), '2');
    await ctrlEnter(tester);
    expect(inventario.ventas, hasLength(1));
    expect(inventario.ventas.single['detalles'], hasLength(2));
  });

  testWidgets('Ctrl+Enter repetido no duplica registro pendiente', (
    tester,
  ) async {
    final inventario = await _montar(tester, const Size(1440, 900));
    inventario.pendiente = Completer<void>();
    await tester.enterText(_campo('Código'), 'ZOOM-1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(inventario.ventas, hasLength(1));
    inventario.pendiente!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('teclado del celular: avanza campo por campo y código inválido avisa', (
    tester,
  ) async {
    final inventario = await _montar(tester, const Size(600, 844));
    await tester.enterText(_campo('Código'), 'NO-EXISTE');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.text('No existe un producto con ese código.'), findsOneWidget);
    expect(enfocado(tester, 'Código'), isTrue);

    await tester.enterText(_campo('Código'), 'ZOOM-1');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(enfocado(tester, 'Cantidad'), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(enfocado(tester, 'Monto total (Bs)'), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Se agregó la fila (monto de lista), sin registrar todavía.
    expect(inventario.ventas, isEmpty);
    expect(enfocado(tester, 'Código'), isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(inventario.ventas, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final tamano in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
  ]) {
    testWidgets('teléfono angosto sin desbordes, vacía y con productos: $tamano', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _montar(tester, tamano);
      expect(tester.takeException(), isNull);
      await tester.enterText(_campo('Código'), 'ZOOM-1');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
