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
  for (final metodo in ['efectivo', 'qr', 'ambos']) {
    testWidgets('abono parcial $metodo en movil', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      Map<String, dynamic>? enviado;
      final api = ApiClient(
        httpClient: MockClient((peticion) async {
          if (peticion.method == 'POST') {
            expect(peticion.url.path, '/api/contabilidad/gastos/1/pagos/mixto');
            enviado = jsonDecode(peticion.body) as Map<String, dynamic>;
            return http.Response('[]', 201);
          }
          return http.Response(
            jsonEncode(
              peticion.url.path.endsWith('/categorias-gasto')
                  ? []
                  : [
                      {
                        'id': 1,
                        'concepto': 'Wifi',
                        'categoria': 'Wifi',
                        'estado': 'pendiente',
                        'moneda_codigo': 'BOB',
                        'monto': '100.00',
                        'saldo_pendiente_bob': '100.00',
                        'pagos': [],
                      },
                    ],
            ),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        Provider(
          create: (_) => OperacionesService(api),
          child: MaterialApp(
            theme: buildTemaNoche(),
            home: const Scaffold(
              body: FinanzasPage(seccion: DestinoApp.gastos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar pago'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Transferencia'), findsNothing);
      expect(find.text('Otro'), findsNothing);
      final confirmar = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Registrar pago'),
          )
          .last;
      await tester.enterText(_campo('Importe a pagar (BOB)'), '50');
      if (metodo != 'efectivo') {
        await tester.tap(find.text('QR'));
        await tester.pump();
      }
      if (metodo == 'qr') {
        await tester.tap(find.text('Efectivo'));
        await tester.pump();
      }
      if (metodo == 'ambos') {
        await tester.enterText(_campo('Parte en efectivo'), '50');
        await tester.ensureVisible(confirmar);
        await tester.tap(confirmar);
        await tester.pump(const Duration(milliseconds: 800));
        expect(enviado, isNull);
        await tester.enterText(_campo('Parte en efectivo'), '20');
        await tester.pump();
        expect(find.text('Parte por QR: BOB 30.00'), findsOneWidget);
      }
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(enviado!['pagos'], [
        if (metodo != 'qr')
          {
            'metodo_pago': 'efectivo',
            'monto': metodo == 'ambos' ? '20.00' : '50.00',
            // Sin caja abierta, el efectivo se registra pagado aparte.
            'desde_caja': false,
          },
        if (metodo != 'efectivo')
          {'metodo_pago': 'qr', 'monto': metodo == 'ambos' ? '30.00' : '50.00'},
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final marcar in [false, true]) {
    testWidgets('con caja abierta, el efectivo sale de la caja solo si se marca: $marcar', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      Map<String, dynamic>? enviado;
      final api = ApiClient(
        httpClient: MockClient((peticion) async {
          if (peticion.method == 'POST') {
            enviado = jsonDecode(peticion.body) as Map<String, dynamic>;
            return http.Response('[]', 201);
          }
          final ruta = peticion.url.path;
          final cuerpo = ruta.endsWith('/sesiones/actual')
              ? {'id': 9, 'estado': 'abierta', 'sucursal_id': 1}
              : ruta.endsWith('/categorias-gasto')
              ? []
              : [
                  {
                    'id': 1,
                    'concepto': 'Scotch',
                    'categoria': 'Scotch',
                    'estado': 'pendiente',
                    'sucursal_id': 1,
                    'moneda_codigo': 'BOB',
                    'monto': '10.00',
                    'saldo_pendiente_bob': '10.00',
                    'pagos': [],
                  },
                ];
          return http.Response(jsonEncode(cuerpo), 200);
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
      await tester.tap(find.text('Registrar pago'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final casilla = find.text('Se pagó con dinero de la caja');
      expect(casilla, findsOneWidget);
      if (marcar) {
        await tester.tap(casilla);
        await tester.pump();
      }
      final confirmar = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Registrar pago'),
          )
          .last;
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(enviado!['pagos'], [
        {'metodo_pago': 'efectivo', 'monto': '10.00', 'desde_caja': marcar},
      ]);
      expect(tester.takeException(), isNull);
    });
  }
}
