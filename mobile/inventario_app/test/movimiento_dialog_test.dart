import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/models/product.dart';
import 'package:inventario_app/core/models/sucursal.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/features/productos/presentation/movimiento_dialog.dart';

final _productos = [
  for (var i = 1; i <= 3; i++)
    ProductoConStock(
      id: i,
      sku: 'ZOOM-$i',
      nombre: 'Producto de demostración $i con descripción larga',
      precioCompra: 25,
      precioVenta: 40,
      stockMinimo: 5,
      activo: true,
      stockActual: 10,
      stockBajo: false,
    ),
];

// Una razon por tipo: el dialogo la elige sola, y los tests de filas no
// tienen que pasar por el selector.
const _razonesUnaPorTipo = [
  RazonMovimiento(id: 1, nombre: 'Ingreso desde proveedor', tipoMovimiento: 'entrada'),
  RazonMovimiento(id: 2, nombre: 'Salida por falla', tipoMovimiento: 'salida'),
  RazonMovimiento(id: 3, nombre: 'Ajuste por desglose', tipoMovimiento: 'ajuste'),
];

Future<void> _abrir(
  WidgetTester tester, {
  Size tamano = const Size(390, 844),
  double teclado = 0,
  bool claro = false,
  String tipo = 'entrada',
  GuardarMovimiento? enviar,
  List<RazonMovimiento> razones = _razonesUnaPorTipo,
  List<Sucursal> sucursales = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  tester.view.viewInsets = FakeViewPadding(bottom: teclado);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: claro ? buildTemaClaro() : buildTemaNoche(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => MovimientoDialog(
                productos: _productos,
                productoInicial: _productos.first,
                tipoInicial: tipo,
                cantidadInicial: 2,
                razones: razones,
                sucursales: sucursales,
                sucursalActualId: 1,
                enviar:
                    enviar ??
                    ({required tipo, required items, required razonId, sucursalDestinoId}) async =>
                            items.length,
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('letra ampliada y teclado mantienen visibles las acciones', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _abrir(tester, tamano: const Size(320, 640), teclado: 280);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Guardar lote')).bottom,
      lessThanOrEqualTo(360),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter en cantidad agrega una fila sin enviar el lote', (
    tester,
  ) async {
    var llamadas = 0;
    await _abrir(
      tester,
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
        llamadas++;
        return items.length;
      },
    );
    await tester.tap(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu<int>), findsNWidgets(2));
    expect(llamadas, 0);
    expect(tester.takeException(), isNull);
  });

  for (final claro in [false, true]) {
    for (final tamano in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(800, 600),
      const Size(1440, 900),
    ]) {
      testWidgets('lote sin desbordes: $tamano, claro=$claro, con teclado', (
        tester,
      ) async {
        await _abrir(tester, tamano: tamano, teclado: 280, claro: claro);
        expect(tester.takeException(), isNull);
        final guardar = tester.getRect(find.text('Guardar lote'));
        expect(guardar.bottom, lessThanOrEqualTo(tamano.height - 280));
        expect(find.text('Stock 10 → 12'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(MovimientoDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('selección buscable, filas múltiples y payload por lote', (
    tester,
  ) async {
    List<ItemMovimiento>? guardados;
    await _abrir(
      tester,
      tamano: const Size(1000, 800),
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
        expect(tipo, 'entrada');
        guardados = items;
        return items.length;
      },
    );
    final superficie = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    // La razon del movimiento suma un campo sobre el alto anterior (480).
    expect(tester.getSize(superficie).height, lessThanOrEqualTo(560));
    final filas = find.byWidgetPredicate(
      (widget) => widget is Container && widget.key is ObjectKey,
    );
    expect(tester.getSize(filas.first).height, lessThanOrEqualTo(90));
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    final menu = find.byType(DropdownMenu<int>).last;
    await tester.enterText(
      find.descendant(of: menu, matching: find.byType(TextField)).first,
      'ZOOM-2',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ZOOM-2 · ${_productos[1].nombre}').last);
    await tester.pumpAndSettle();
    final cantidad = find.byType(TextField).last;
    await tester.enterText(cantidad, '3');
    await tester.tap(find.text('Guardar lote'));
    await tester.pumpAndSettle();
    expect(guardados, [
      (productoId: 1, cantidad: 2),
      (productoId: 2, cantidad: 3),
    ]);
    expect(find.byType(MovimientoDialog), findsNothing);
  });

  testWidgets('doble envío y Ctrl+Enter solo ejecutan una petición', (
    tester,
  ) async {
    final completar = Completer<int>();
    var llamadas = 0;
    await _abrir(
      tester,
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) {
        llamadas++;
        return completar.future;
      },
    );
    await tester.tap(find.text('Guardar lote'));
    await tester.tap(find.text('Guardar lote'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(llamadas, 1);
    final cancelar = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    );
    expect(cancelar.onPressed, isNull);
    completar.complete(1);
    await tester.pumpAndSettle();
    expect(find.byType(MovimientoDialog), findsNothing);
  });

  testWidgets('salida rechaza exceso de stock y ajuste admite cero', (
    tester,
  ) async {
    var llamadas = 0;
    await _abrir(
      tester,
      tipo: 'salida',
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
        llamadas++;
        expect(tipo, 'ajuste');
        expect(items.single.cantidad, 0);
        return 1;
      },
    );
    await tester.enterText(find.byType(TextField).last, '11');
    await tester.tap(find.text('Guardar lote'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    expect(
      find.textContaining('No hay stock suficiente: disponible 10'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajuste'));
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.pumpAndSettle();
    expect(find.text('Stock 10 → 0'), findsOneWidget);
    await tester.tap(find.text('Guardar lote'));
    await tester.pumpAndSettle();
    expect(llamadas, 1);
  });

  testWidgets('error del API conserva captura y detalle fila a fila', (
    tester,
  ) async {
    await _abrir(
      tester,
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
        throw ApiException(400, '{"detail":"Fila 1: producto dado de baja"}');
      },
    );
    await tester.tap(find.text('Guardar lote'));
    await tester.pumpAndSettle();
    expect(find.byType(MovimientoDialog), findsOneWidget);
    expect(find.text('Fila 1: producto dado de baja'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '2',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar el buscador invalida una selección anterior', (
    tester,
  ) async {
    var llamadas = 0;
    await _abrir(
      tester,
      enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
        llamadas++;
        return 1;
      },
    );
    await tester.enterText(find.byType(TextField).first, 'No existe');
    await tester.tap(find.text('Guardar lote'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    expect(
      find.textContaining('Elige un producto del buscador.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'productos repetidos se rechazan y quitar una fila conserva la otra',
    (tester) async {
      var llamadas = 0;
      await _abrir(
        tester,
        tamano: const Size(1000, 800),
        enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
          llamadas++;
          expect(items, [(productoId: 1, cantidad: 2)]);
          return items.length;
        },
      );
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      final menu = find.byType(DropdownMenu<int>).last;
      await tester.enterText(
        find.descendant(of: menu, matching: find.byType(TextField)).first,
        'ZOOM-1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZOOM-1 · ${_productos.first.nombre}').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '7');
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(llamadas, 0);
      expect(
        find.textContaining('El producto ya está en la fila 1.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Quitar fila 2'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownMenu<int>), findsOneWidget);
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(llamadas, 1);
      expect(tester.takeException(), isNull);
    },
  );

  group('razón del movimiento', () {
    const varias = [
      RazonMovimiento(id: 10, nombre: 'Salida por falla', tipoMovimiento: 'salida'),
      RazonMovimiento(id: 11, nombre: 'Salida para tester', tipoMovimiento: 'salida'),
      RazonMovimiento(
        id: 12,
        nombre: 'Salida a sucursal',
        tipoMovimiento: 'salida',
        requiereSucursalDestino: true,
      ),
      RazonMovimiento(id: 13, nombre: 'Ingreso desde proveedor', tipoMovimiento: 'entrada'),
    ];
    const sucursales = [
      Sucursal(id: 1, nombre: 'Principal'),
      Sucursal(id: 2, nombre: 'Norte'),
      Sucursal(id: 3, nombre: 'Cerrada', activo: false),
    ];

    Future<void> elegir(WidgetTester tester, String campo, String opcion) async {
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, campo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    testWidgets('con varias razones no envía hasta elegir una', (tester) async {
      int? razonEnviada;
      await _abrir(
        tester,
        tamano: const Size(1000, 800),
        tipo: 'salida',
        razones: varias,
        sucursales: sucursales,
        enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
          razonEnviada = razonId;
          expect(sucursalDestinoId, isNull);
          return 1;
        },
      );
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(razonEnviada, isNull);
      expect(find.text('Elige la razón del movimiento.'), findsOneWidget);

      await elegir(tester, 'Razón del movimiento', 'Salida para tester');
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(razonEnviada, 11);
    });

    testWidgets('el selector solo ofrece razones del tipo elegido', (tester) async {
      await _abrir(
        tester,
        tamano: const Size(1000, 800),
        tipo: 'salida',
        razones: varias,
      );
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Razón del movimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Ingreso desde proveedor'), findsNothing);
      expect(find.text('Salida por falla'), findsWidgets);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Entrada solo tiene una razón: queda elegida sola.
      await tester.tap(find.text('Entrada'));
      await tester.pumpAndSettle();
      expect(find.text('Ingreso desde proveedor'), findsOneWidget);
    });

    testWidgets('traspaso pide destino, excluye la sucursal actual y lo envía', (
      tester,
    ) async {
      int? destinoEnviado;
      await _abrir(
        tester,
        tamano: const Size(1000, 800),
        tipo: 'salida',
        razones: varias,
        sucursales: sucursales,
        enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
          expect(razonId, 12);
          destinoEnviado = sucursalDestinoId;
          return 1;
        },
      );
      await elegir(tester, 'Razón del movimiento', 'Salida a sucursal');
      expect(find.text('Sucursal destino'), findsOneWidget);

      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(destinoEnviado, isNull);
      expect(find.text('Elige la sucursal destino.'), findsOneWidget);

      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Sucursal destino'));
      await tester.pumpAndSettle();
      // Ni la sucursal actual ni una desactivada son destinos posibles.
      expect(find.text('Principal'), findsNothing);
      expect(find.text('Cerrada'), findsNothing);
      await tester.tap(find.text('Norte').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(destinoEnviado, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin razones del tipo avisa que se crean en Configuración', (
      tester,
    ) async {
      var llamadas = 0;
      await _abrir(
        tester,
        tipo: 'ajuste',
        razones: varias,
        enviar: ({required tipo, required items, required razonId, sucursalDestinoId}) async {
          llamadas++;
          return 1;
        },
      );
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(llamadas, 0);
      expect(find.textContaining('Créalas en Configuración'), findsOneWidget);
    });
  });
}
