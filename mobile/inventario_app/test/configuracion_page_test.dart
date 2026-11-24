import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/configuracion_service.dart';
import 'package:inventario_app/features/configuracion/presentation/configuracion_page.dart';

Future<void> _montar(WidgetTester tester, {required bool claro}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.reset);
  final api = ApiClient(
    httpClient: MockClient((peticion) async {
      final cuerpo = switch (peticion.url.path) {
        '/api/configuracion/' => {'sucursal_predeterminada_id': 1},
        '/api/sucursales/' => [
          {'id': 1, 'nombre': 'Principal', 'activo': true, 'predeterminada': true},
          {'id': 2, 'nombre': 'Norte', 'activo': true},
          {'id': 3, 'nombre': 'Cerrada', 'activo': false},
        ],
        _ => [
          {'id': 1, 'nombre': 'Ingreso desde proveedor', 'tipo_movimiento': 'entrada'},
        ],
      };
      return http.Response(
        jsonEncode(cuerpo),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  await tester.pumpWidget(
    Provider(
      create: (_) => ConfiguracionService(api),
      child: MaterialApp(
        theme: claro ? buildTemaClaro() : buildTemaNoche(),
        home: Scaffold(body: ConfiguracionPage(alCambiarSucursales: () async {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final claro in [false, true]) {
    testWidgets('la predeterminada muestra "Siempre activa", no un interruptor (claro=$claro)', (
      tester,
    ) async {
      await _montar(tester, claro: claro);
      expect(tester.takeException(), isNull);

      // Solo una etiqueta, en la fila de la predeterminada.
      expect(find.text('Siempre\nactiva'), findsOneWidget);
      final filaPrincipal = find.ancestor(
        of: find.text('Principal'),
        matching: find.byType(Row),
      ).first;
      expect(
        find.descendant(of: filaPrincipal, matching: find.byType(Switch)),
        findsNothing,
      );

      // Las demás sucursales sí tienen interruptor, con su estado real.
      Switch interruptorDe(String nombre) => tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(of: find.text(nombre), matching: find.byType(Row)).first,
          matching: find.byType(Switch),
        ),
      );
      expect(interruptorDe('Norte').value, isTrue);
      expect(interruptorDe('Norte').onChanged, isNotNull);
      expect(interruptorDe('Cerrada').value, isFalse);
    });
  }
}
