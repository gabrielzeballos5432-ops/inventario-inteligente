import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:inventario_app/features/deteccion/presentation/detection_page.dart';

/// La IA nunca toca el stock por su cuenta: detecta, el usuario corrige y
/// recien al confirmar se registra la entrada, por lote y con origen "ia".
void main() {
  late List<http.Request> peticiones;

  Future<InventarioProvider> montar(
    WidgetTester tester, {
    bool rechazarFoto = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);
    peticiones = [];
    final api = ApiClient(
      httpClient: MockClient((peticion) async {
        peticiones.add(peticion);
        final ruta = peticion.url.path;
        if (ruta == '/api/inference/' && rechazarFoto) {
          return http.Response(
            jsonEncode({'detail': 'El archivo debe ser una imagen'}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (ruta == '/api/inference/') {
          return http.Response(
            jsonEncode({
              'detecciones': [
                {'producto_id': 21, 'producto_nombre': 'Iluminador líquido', 'confianza': 0.81, 'cantidad': 1},
                {'producto_id': 22, 'producto_nombre': 'Sombra de ojos líquida', 'confianza': 0.66, 'cantidad': 2},
              ],
              'total_productos': 2,
              'movimientos_creados': 0,
              'sesion_id': 7,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (ruta == '/api/inventario/movimientos/lote') {
          return http.Response(
            jsonEncode({'tipo': 'entrada', 'guardados': 1, 'resultados': []}),
            201,
          );
        }
        if (ruta == '/api/health') {
          return http.Response(jsonEncode({'yolo_disponible': true}), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    final inventario = InventarioProvider(
      ProductService(api),
      DetectionService(api),
      LocalDbService(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: inventario,
        child: MaterialApp(
          theme: buildTemaNoche(),
          home: const Scaffold(body: DetectionPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await inventario.enviarImagen([1, 2, 3], 'foto.jpg');
    await tester.pumpAndSettle();
    return inventario;
  }

  testWidgets('detectar no registra nada y muestra lo detectado para revisar', (
    tester,
  ) async {
    await montar(tester);
    final deteccion = peticiones.firstWhere((p) => p.url.path == '/api/inference/');
    expect(deteccion.method, 'POST');
    expect(peticiones.any((p) => p.url.path.contains('/movimiento')), isFalse);
    expect(find.text('Revisa antes de registrar'), findsOneWidget);
    expect(find.text('Iluminador líquido'), findsOneWidget);
    expect(find.text('Registrar entrada (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('corregir cantidades y confirmar envia solo lo que queda, con origen ia', (
    tester,
  ) async {
    await montar(tester);
    // El iluminador fue un error: se baja a 0.
    await tester.tap(find.byTooltip('Quitar una unidad de Iluminador líquido'));
    // Habia una sombra mas que la IA no vio.
    await tester.tap(find.byTooltip('Agregar una unidad de Sombra de ojos líquida'));
    await tester.pump();
    expect(find.text('Registrar entrada (3)'), findsOneWidget);

    await tester.tap(find.text('Registrar entrada (3)'));
    await tester.pumpAndSettle();

    final lote = peticiones.singleWhere((p) => p.url.path == '/api/inventario/movimientos/lote');
    final cuerpo = jsonDecode(lote.body) as Map<String, dynamic>;
    expect(cuerpo['tipo'], 'entrada');
    expect(cuerpo['origen'], 'ia');
    expect(cuerpo['sesion_id'], 7);
    expect(cuerpo.containsKey('razon_movimiento_id'), isFalse);
    expect(cuerpo['items'], [
      {'producto_id': 22, 'cantidad': 3},
    ]);
    expect(find.text('Revisa antes de registrar'), findsNothing);
    expect(find.textContaining('Entrada registrada'), findsOneWidget);
  });

  testWidgets('descartar no registra nada', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa antes de registrar'), findsNothing);
    expect(peticiones.any((p) => p.url.path.contains('/movimiento')), isFalse);
  });

  testWidgets('con todo en 0 no se puede registrar', (tester) async {
    await montar(tester);
    await tester.tap(find.byTooltip('Quitar una unidad de Iluminador líquido'));
    await tester.tap(find.byTooltip('Quitar una unidad de Sombra de ojos líquida'));
    await tester.tap(find.byTooltip('Quitar una unidad de Sombra de ojos líquida'));
    await tester.pump();
    final boton = find.text('Registrar entrada (0)');
    expect(boton, findsOneWidget);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(peticiones.any((p) => p.url.path.contains('/movimiento')), isFalse);
  });

  testWidgets('si el servidor rechaza la foto, el motivo se ve aunque se recargue el inventario', (
    tester,
  ) async {
    final inventario = await montar(tester, rechazarFoto: true);
    // Al volver de la camara la app recarga datos que ponen `error` en null:
    // antes eso borraba el rechazo y la pantalla quedaba muda.
    await inventario.cargarHistorial();
    await tester.pump();
    expect(
      find.text('El servidor rechazo la foto: El archivo debe ser una imagen'),
      findsOneWidget,
    );
    expect(find.text('Revisa antes de registrar'), findsNothing);
  });
}
