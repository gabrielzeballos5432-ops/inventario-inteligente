import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/models/sucursal.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/sucursal_controller.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/features/caja/presentation/caja_page.dart';

Future<void> _montar(WidgetTester tester, {required int activa}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  SucursalController.instance.fijarParaPruebas(
    sucursales: const [
      Sucursal(id: 1, nombre: 'Principal'),
      Sucursal(id: 2, nombre: 'Norte'),
    ],
    predeterminadaId: 1,
    activaId: activa,
  );
  addTearDown(() => SucursalController.instance.fijarParaPruebas());
  final api = ApiClient(
    httpClient: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'id': 5,
          'estado': 'abierta',
          'sucursal_id': 1,
          'monto_inicial': '20.00',
          'fecha_apertura': '2026-11-11T20:46:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
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
}

void main() {
  testWidgets('la caja abierta muestra su sucursal', (tester) async {
    await _montar(tester, activa: 1);
    expect(find.text('Sucursal: Principal'), findsOneWidget);
    expect(find.textContaining('no se suman a ella'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa si la caja abierta es de otra sucursal', (tester) async {
    await _montar(tester, activa: 2);
    expect(find.text('Sucursal: Principal'), findsOneWidget);
    expect(
      find.textContaining('Las ventas en efectivo de Norte no se suman a ella'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la hora de apertura se muestra en hora local, no en UTC', (
    tester,
  ) async {
    await _montar(tester, activa: 1);
    final local = DateTime.utc(2026, 11, 11, 20, 46).toLocal();
    final hora =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(find.textContaining('Abierta: '), findsOneWidget);
    expect(find.textContaining(hora), findsOneWidget);
  });
}
