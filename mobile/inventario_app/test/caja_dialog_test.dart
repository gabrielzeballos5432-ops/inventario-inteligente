import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/features/caja/presentation/caja_page.dart';
import 'package:provider/provider.dart';

void main() {
  for (final cerrar in [false, true]) {
    for (final confirmar in [false, true]) {
      testWidgets(
        '${cerrar ? 'cerrar' : 'abrir'} caja y ${confirmar ? 'confirmar' : 'cancelar'} sin assertion',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.reset);
          final abierta = {
            'id': 1,
            'estado': 'abierta',
            'monto_inicial': '20.00',
            'fecha_apertura': '2026-11-01T12:00:00',
          };
          Map<String, dynamic>? sesion = cerrar ? abierta : null;
          final peticiones = <Map<String, dynamic>>[];
          final api = ApiClient(
            httpClient: MockClient((peticion) async {
              if (peticion.method == 'POST') {
                peticiones.add(
                  jsonDecode(peticion.body) as Map<String, dynamic>,
                );
                sesion = cerrar ? null : abierta;
                if (cerrar) {
                  return http.Response(
                    '{"monto_diferencia_cierre":"0.00"}',
                    200,
                  );
                }
              }
              return http.Response(
                jsonEncode(sesion),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          await tester.pumpWidget(
            Provider(
              create: (_) => OperacionesService(api),
              child: MaterialApp(
                theme: buildTemaNoche(),
                home: const Scaffold(body: CajaPage(esAdmin: false)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(cerrar ? 'Contar y cerrar caja' : 'Abrir caja'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pump(const Duration(milliseconds: 400));
          if (confirmar) {
            await tester.enterText(find.byType(TextFormField).first, '-1');
            final confirmarBoton = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(cerrar ? 'Cerrar caja' : 'Abrir caja'),
            );
            await tester.tap(confirmarBoton.last);
            await tester.pump(const Duration(milliseconds: 800));
            expect(find.text('Ingresa un monto válido'), findsOneWidget);
            expect(peticiones, isEmpty);
            await tester.enterText(find.byType(TextFormField).first, '20');
            if (cerrar) {
              await tester.enterText(
                find.byType(TextFormField).last,
                'Cierre de prueba',
              );
            }
          }
          final accion = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              confirmar ? (cerrar ? 'Cerrar caja' : 'Abrir caja') : 'Cancelar',
            ),
          );
          await tester.ensureVisible(accion.last);
          await tester.tap(accion.last);
          await tester.pump();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            peticiones,
            confirmar
                ? [
                    cerrar
                        ? {
                            'monto_efectivo_contado': '20.00',
                            'observacion_cierre': 'Cierre de prueba',
                          }
                        : {'monto_inicial': '20.00'},
                  ]
                : isEmpty,
          );
        },
      );
    }
  }
}
