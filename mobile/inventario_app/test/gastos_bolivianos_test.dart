import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/destino_app.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/features/contabilidad/presentation/finanzas_page.dart';
import 'package:provider/provider.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

void main() {
  testWidgets('gastos en BOB sin consultar monedas ni pedir cotizaciones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    addTearDown(tester.view.reset);
    final rutas = <String>[];
    Map<String, dynamic>? enviado;
    final api = ApiClient(
      httpClient: MockClient((peticion) async {
        rutas.add(peticion.url.path);
        if (peticion.method == 'POST') {
          enviado = jsonDecode(peticion.body) as Map<String, dynamic>;
          return http.Response('{}', 201);
        }
        if (peticion.url.path.endsWith('/categorias-gasto')) {
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'nombre': 'Agua',
                'periodicidad': 'mensual',
                'tipo_importe': 'variable',
                'monto_habitual': null,
                'activo': true,
              },
              {
                'id': 2,
                'nombre': 'Wifi',
                'periodicidad': 'mensual',
                'tipo_importe': 'fijo',
                'monto_habitual': '100.00',
                'activo': true,
              },
              {
                'id': 3,
                'nombre': 'Scotch',
                'periodicidad': 'sin_periodicidad',
                'tipo_importe': 'variable',
                'monto_habitual': null,
                'activo': true,
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      Provider(
        create: (_) => OperacionesService(api),
        child: MaterialApp(
          theme: buildTemaNoche(),
          home: const Scaffold(body: FinanzasPage(seccion: DestinoApp.gastos)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rutas, [
      '/api/contabilidad/gastos',
      '/api/contabilidad/categorias-gasto',
    ]);
    await tester.tap(find.text('Nuevo gasto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Moneda'), findsNothing);
    expect(find.textContaining('Tipo de cambio'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Wifi').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(_campo('Importe (Bs)')).controller!.text,
      '100.00',
    );
    final desde = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Período desde',
    );
    expect(tester.widget<TextField>(desde).controller!.text, isNotEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Scotch').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(_campo('Importe (Bs)')).controller!.text,
      isEmpty,
    );
    expect(tester.widget<TextField>(desde).controller!.text, isEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Agua').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(_campo('Concepto'), 'Pago de agua');
    await tester.enterText(_campo('Importe (Bs)'), '30.123');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Usa hasta 2 decimales'), findsOneWidget);
    expect(enviado, isNull);
    await tester.enterText(_campo('Importe (Bs)'), '30.50');
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(enviado, isNotNull);
    expect(enviado!['moneda_codigo'], 'BOB');
    expect(enviado!['categoria_gasto_id'], 1);
    expect(enviado!['monto'], '30.5000');
    expect(enviado!['tipo_cambio_ext'], '1.000000');
    expect(enviado!['tipo_cambio_bob'], '1.000000');
    expect(rutas.any((ruta) => ruta.contains('monedas')), isFalse);
    expect(tester.takeException(), isNull);
  });
}
