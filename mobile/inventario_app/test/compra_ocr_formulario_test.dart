import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/destino_app.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/features/contabilidad/presentation/finanzas_page.dart';
import 'package:provider/provider.dart';

void main() {
  for (final ancho in [390.0, 1440.0]) {
    testWidgets('foto llena borrador sin registrar stock en ancho $ancho', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(ancho, 1000);
      addTearDown(tester.view.reset);
      final temporal = Directory.systemTemp.createTempSync('prueba_compra_');
      final foto = File('${temporal.path}${Platform.pathSeparator}foto.jpg');
      foto.writeAsBytesSync([1, 2, 3]);
      addTearDown(() {
        foto.deleteSync();
        temporal.deleteSync();
      });
      const canal = MethodChannel('plugins.flutter.io/image_picker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
        (_) async => foto.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          canal,
          null,
        ),
      );
      final registros = <http.Request>[];
      final servicio = OperacionesService(
        ApiClient(
          httpClient: MockClient((peticion) async {
            Object respuesta;
            switch (peticion.url.path) {
              case '/api/compras/leer-comprobante':
                respuesta = {
                  'numero_factura': 'F-123',
                  'proveedor_nombre': 'Proveedor leído',
                  'proveedor_id': null,
                  'moneda_codigo': 'CLP',
                  'total_impreso': '7200',
                  'subtotal_calculado': '7200',
                  'detalles': [
                    {
                      'descripcion': 'KK-72 Decoración',
                      'producto_id': 1,
                      'cantidad': 12,
                      'costo_unitario_moneda': '600',
                    },
                  ],
                  'advertencias': ['Confirma las cantidades'],
                  'texto_detectado': '12x600 =7200',
                };
              case '/api/productos/':
                respuesta = [
                  {'id': 1, 'nombre': 'Decoración de uñas', 'activo': true},
                ];
              case '/api/monedas/':
                respuesta = [
                  {'codigo': 'CLP', 'nombre': 'Peso chileno', 'activa': true},
                  {'codigo': 'BOB', 'nombre': 'Boliviano', 'activa': true},
                ];
              case '/api/compras/':
                if (peticion.method == 'POST') {
                  registros.add(peticion);
                  respuesta = {
                    'id': 9,
                    'moneda_codigo': 'CLP',
                    'total_moneda': '7200',
                    'total_bob': '89.81',
                  };
                } else {
                  respuesta = [];
                }
              default:
                if (peticion.method == 'POST') registros.add(peticion);
                respuesta = [];
            }
            return http.Response(
              jsonEncode(respuesta),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(
        Provider.value(
          value: servicio,
          child: MaterialApp(
            theme: buildTemaNoche(),
            home: const Scaffold(
              body: FinanzasPage(seccion: DestinoApp.compras),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar compra'));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await tester.tap(find.text('Leer comprobante'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Usar datos del comprobante'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Usar borrador'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(CheckboxListTile),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((texto) => texto.data)
            .join('\n'),
      );
      expect(find.textContaining('Total impreso: 7200'), findsOneWidget);
      final campos = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(campos.any((campo) => campo.controller?.text == 'F-123'), isTrue);
      expect(campos.any((campo) => campo.controller?.text == '12'), isTrue);
      expect(campos.any((campo) => campo.controller?.text == '600'), isTrue);
      expect(find.byKey(const ValueKey('moneda-CLP')), findsOneWidget);
      expect(registros, isEmpty);
      await tester.tap(find.text('Registrar'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Revisa el borrador'), findsOneWidget);
      expect(registros, isEmpty);
      for (final (etiqueta, valor) in [
        ('CLP por USD', '971.57'),
        ('Bs por USD', '12.12'),
      ]) {
        final campo = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == etiqueta,
        );
        await tester.ensureVisible(campo);
        await tester.enterText(campo, valor);
      }
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Registrar'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(registros, hasLength(1));
      final datos = jsonDecode(registros.single.body) as Map<String, dynamic>;
      expect(datos['proveedor_id'], isNull);
      expect(datos['moneda_codigo'], 'CLP');
      expect(datos['tipo_cambio_ext'], '971.57');
      expect(datos['tipo_cambio_bob'], '12.12');
      expect(datos['detalles'][0]['producto_id'], 1);
      expect(datos['detalles'][0]['cantidad'], 12);
      expect(datos['detalles'][0]['costo_unitario_moneda'], '600');
      expect(tester.takeException(), isNull);
    });
  }
}
