import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/models/movimiento_pendiente.dart';
import 'package:inventario_app/core/models/product.dart';
import 'package:inventario_app/core/models/sucursal.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/cola_movimientos_controller.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:inventario_app/features/productos/presentation/movimiento_dialog.dart';
import 'package:inventario_app/shared/widgets/movimientos_pendientes.dart';

/// Base local en memoria: en los tests no hay SQLite.
class _DbFalsa implements LocalDbService {
  final Map<String, Map<String, dynamic>> cola = {};

  @override
  Future<void> guardarPendiente(Map<String, dynamic> fila) async {
    cola[fila['clave'] as String] = Map.of(fila);
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerPendientes() async =>
      cola.values.map(Map<String, dynamic>.of).toList()..sort(
        (a, b) => (a['creado_en'] as String).compareTo(b['creado_en'] as String),
      );

  @override
  Future<void> actualizarPendiente(
    String clave, {
    required String estado,
    String? detalle,
  }) async {
    cola[clave]!
      ..['estado'] = estado
      ..['detalle'] = detalle;
  }

  @override
  Future<void> eliminarPendiente(String clave) async => cola.remove(clave);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _items = [
  ItemPendiente(productoId: 7, nombre: 'Esmalte Rojo', cantidad: 3),
];

void main() {
  late List<http.Request> peticiones;
  late _DbFalsa db;
  late int sincronizaciones;

  /// `responder` decide que contesta el servidor a cada lote, por orden.
  ColaMovimientosController cola(
    http.Response Function(http.Request peticion) responder, {
    int? usuario = 1,
  }) {
    peticiones = [];
    sincronizaciones = 0;
    final api = ApiClient(
      httpClient: MockClient((peticion) async {
        peticiones.add(peticion);
        return responder(peticion);
      }),
    );
    return ColaMovimientosController(
      ProductService(api),
      db,
      alSincronizar: () => sincronizaciones++,
      usuarioActual: () => usuario,
    );
  }

  http.Response ok(http.Request _) => http.Response(
    jsonEncode({'tipo': 'entrada', 'guardados': 1, 'resultados': []}),
    201,
  );

  Future<void> encolar(
    ColaMovimientosController c,
    String clave, {
    String tipo = 'entrada',
    int? sucursalId = 2,
  }) => c.encolar(
    clave: clave,
    tipo: tipo,
    razonId: 5,
    razonNombre: 'Ingreso desde proveedor',
    sucursalId: sucursalId,
    items: _items,
  );

  setUp(() => db = _DbFalsa());

  test('el movimiento hecho sin conexión queda guardado y se cuenta', () async {
    final c = cola(ok);
    await encolar(c, 'clave-uno-0001');
    expect(c.pendientes, 1);
    expect(db.cola.keys, ['clave-uno-0001']);

    // Sobrevive a cerrar la app: otro controlador lo lee de la base local.
    final otra = cola(ok);
    await otra.cargar();
    expect(otra.movimientos.single.items.single.nombre, 'Esmalte Rojo');
    expect(otra.movimientos.single.unidades, 3);
  });

  test('al sincronizar envia el lote con su clave y su sucursal, y lo quita', () async {
    final c = cola(ok);
    await encolar(c, 'clave-uno-0001', sucursalId: 2);
    final resultado = await c.sincronizar();

    final cuerpo = jsonDecode(peticiones.single.body) as Map<String, dynamic>;
    expect(peticiones.single.url.path, '/api/inventario/movimientos/lote');
    expect(cuerpo['clave_idempotencia'], 'clave-uno-0001');
    expect(cuerpo['tipo'], 'entrada');
    expect(cuerpo['razon_movimiento_id'], 5);
    expect(cuerpo['items'], [
      {'producto_id': 7, 'cantidad': 3},
    ]);
    // La sucursal en la que se hizo, no la que este activa al sincronizar.
    expect(peticiones.single.headers['X-Sucursal-Id'], '2');

    expect(resultado.enviados, 1);
    expect(c.pendientes, 0);
    expect(db.cola, isEmpty);
    expect(sincronizaciones, 1);
    expect(c.tomarAviso()!.mensaje, '1 movimiento(s) pendiente(s) enviado(s).');
    expect(c.tomarAviso(), isNull);
  });

  test('si el servidor sigue caido no se pierde nada y se respeta el orden', () async {
    final c = cola((_) => throw const SocketException('sin red'));
    await encolar(c, 'clave-uno-0001');
    await encolar(c, 'clave-dos-0002');
    final resultado = await c.sincronizar();

    expect(resultado.vacio, isTrue);
    // Se corta en el primero: el segundo no se adelanta.
    expect(peticiones, hasLength(1));
    expect(c.pendientes, 2);
    expect(sincronizaciones, 0);
    expect(c.tomarAviso(), isNull);
  });

  test('un rechazo del servidor queda con su motivo y no frena a los demas', () async {
    final c = cola((p) {
      final clave = (jsonDecode(p.body) as Map)['clave_idempotencia'];
      if (clave == 'clave-uno-0001') {
        return http.Response(
          jsonEncode({'detail': 'Fila 1 (Esmalte Rojo): no hay stock suficiente: disponible 1'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return ok(p);
    });
    await encolar(c, 'clave-uno-0001', tipo: 'salida');
    await encolar(c, 'clave-dos-0002');
    final resultado = await c.sincronizar();

    expect((resultado.enviados, resultado.rechazados), (1, 1));
    expect(c.pendientes, 0);
    expect(c.rechazados, 1);
    final rechazado = c.movimientos.single;
    expect(rechazado.clave, 'clave-uno-0001');
    expect(rechazado.detalle, contains('disponible 1'));
    expect(db.cola['clave-uno-0001']!['estado'], 'rechazado');

    // No se reenvia solo: lo decide el usuario (reintentar o descartar).
    await c.sincronizar();
    expect(peticiones, hasLength(2));
    await c.descartar('clave-uno-0001');
    expect(c.rechazados, 0);
    expect(db.cola, isEmpty);
  });

  test('con la sesión vencida el movimiento sigue pendiente, no rechazado', () async {
    final c = cola((_) => http.Response('{"detail":"Token vencido"}', 401));
    await encolar(c, 'clave-uno-0001');
    await c.sincronizar();
    expect(c.pendientes, 1);
    expect(c.rechazados, 0);
  });

  test('solo se envian los movimientos de la cuenta que tiene la sesión', () async {
    final deOtro = cola(ok, usuario: 9);
    await encolar(deOtro, 'clave-otro-0009');

    final c = cola(ok, usuario: 1);
    await c.cargar();
    expect(c.pendientes, 0);
    await c.sincronizar();
    expect(peticiones, isEmpty);
    expect(db.cola.keys, ['clave-otro-0009']);
  });

  test('cada lote lleva una clave distinta y válida para el servidor', () {
    final a = ColaMovimientosController.nuevaClave();
    final b = ColaMovimientosController.nuevaClave();
    expect(a, isNot(b));
    expect(a.length, inInclusiveRange(8, 100));
  });

  group('dialogo de movimiento sin conexión', () {
    final producto = ProductoConStock(
      id: 7,
      sku: 'ZOOM-7',
      nombre: 'Esmalte Rojo',
      precioCompra: 25,
      precioVenta: 40,
      stockMinimo: 5,
      activo: true,
      stockActual: 10,
      stockBajo: false,
    );
    const sucursales = [
      Sucursal(id: 1, nombre: 'Principal'),
      Sucursal(id: 2, nombre: 'Norte'),
    ];

    Future<List<String>> abrir(
      WidgetTester tester, {
      required List<RazonMovimiento> razones,
      String tipo = 'entrada',
      bool conCola = true,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);
      final encolados = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTemaNoche(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => MovimientoDialog(
                    productos: [producto],
                    productoInicial: producto,
                    tipoInicial: tipo,
                    cantidadInicial: 2,
                    razones: razones,
                    sucursales: sucursales,
                    sucursalActualId: 1,
                    enviar:
                        ({
                          required tipo,
                          required items,
                          required razonId,
                          sucursalDestinoId,
                        }) async => throw const SocketException('sin red'),
                    encolar: !conCola
                        ? null
                        : ({required tipo, required razon, required items}) async {
                            encolados.add(
                              '$tipo/${razon.nombre}/'
                              '${items.single.producto.nombre}x${items.single.cantidad}',
                            );
                          },
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
      return encolados;
    }

    testWidgets('sin red, el lote se guarda en el dispositivo y el dialogo cierra', (
      tester,
    ) async {
      final encolados = await abrir(
        tester,
        razones: const [
          RazonMovimiento(id: 1, nombre: 'Ingreso desde proveedor', tipoMovimiento: 'entrada'),
        ],
      );
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();

      expect(encolados, ['entrada/Ingreso desde proveedor/Esmalte Rojox2']);
      expect(find.byType(MovimientoDialog), findsNothing);
      expect(find.textContaining('quedo guardado en este dispositivo'), findsOneWidget);
    });

    testWidgets('un traspaso entre sucursales no se encola: necesita al servidor', (
      tester,
    ) async {
      final encolados = await abrir(
        tester,
        tipo: 'salida',
        razones: const [
          RazonMovimiento(
            id: 12,
            nombre: 'Salida a sucursal',
            tipoMovimiento: 'salida',
            requiereSucursalDestino: true,
          ),
        ],
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'Sucursal destino'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Norte').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();

      expect(encolados, isEmpty);
      expect(find.byType(MovimientoDialog), findsOneWidget);
      expect(find.textContaining('No se pudo confirmar el registro'), findsOneWidget);
    });

    testWidgets('sin cola, el error de red se muestra como antes', (tester) async {
      await abrir(
        tester,
        conCola: false,
        razones: const [
          RazonMovimiento(id: 1, nombre: 'Ingreso desde proveedor', tipoMovimiento: 'entrada'),
        ],
      );
      await tester.tap(find.text('Guardar lote'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo confirmar el registro'), findsOneWidget);
    });
  });

  testWidgets('la franja avisa los pendientes y la lista muestra el rechazo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final c = cola(
      (_) => http.Response(
        jsonEncode({'detail': 'No hay stock suficiente: disponible 1'}),
        400,
      ),
    );
    await encolar(c, 'clave-uno-0001', tipo: 'salida');

    await tester.pumpWidget(
      ChangeNotifierProvider<ColaMovimientosController?>.value(
        value: c,
        child: MaterialApp(
          theme: buildTemaClaro(),
          home: const Scaffold(
            body: Column(children: [AvisoMovimientosPendientes()]),
          ),
        ),
      ),
    );
    expect(find.text('1 movimiento(s) pendiente(s) de enviar'), findsOneWidget);

    await tester.runAsync(c.sincronizar);
    await tester.pump();
    expect(find.text('1 rechazado(s) por el servidor'), findsOneWidget);
    // RF-20: el resultado de la sincronizacion se avisa.
    expect(find.textContaining('revisa los pendientes'), findsOneWidget);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Salida · Ingreso desde proveedor'), findsOneWidget);
    expect(find.text('3 × Esmalte Rojo'), findsOneWidget);
    expect(find.text('Rechazado: No hay stock suficiente: disponible 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
