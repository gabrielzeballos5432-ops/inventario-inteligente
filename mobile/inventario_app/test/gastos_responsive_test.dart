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

final _mesActual = DateTime.now();
final _fechaInicio = DateTime(_mesActual.year, _mesActual.month, 1);
final _fechaFin = DateTime(_mesActual.year, _mesActual.month + 1, 0);
final _fechaInicioTexto =
    '${_fechaInicio.year.toString().padLeft(4, '0')}-'
    '${_fechaInicio.month.toString().padLeft(2, '0')}-01';
final _fechaFinTexto =
    '${_fechaFin.year.toString().padLeft(4, '0')}-'
    '${_fechaFin.month.toString().padLeft(2, '0')}-'
    '${_fechaFin.day.toString().padLeft(2, '0')}';

final _gastos = [
  {
    'id': 1,
    'categoria': 'Wifi',
    'concepto': 'Internet mensual',
    'periodo_desde': _fechaInicioTexto,
    'periodo_hasta': _fechaFinTexto,
    'monto': '100.00',
    'monto_bob': '100.00',
    'saldo_pendiente_bob': '80.00',
    'moneda_codigo': 'BOB',
    'estado': 'pendiente',
    'pagos': [
      {'monto': '20.00', 'monto_bob': '20.00'},
    ],
  },
  {
    'id': 2,
    'categoria': 'Etiquetas',
    'concepto': 'Etiquetas para productos',
    'periodo_desde': null,
    'periodo_hasta': null,
    'monto': '50.00',
    'monto_bob': '50.00',
    'saldo_pendiente_bob': '0.00',
    'moneda_codigo': 'BOB',
    'estado': 'pagado',
    'pagos': [
      {'monto': '50.00', 'monto_bob': '50.00'},
    ],
  },
];

Future<List<Uri>> _montar(WidgetTester tester, Size tamano) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
  final uri = <Uri>[];
  final api = ApiClient(
    httpClient: MockClient((peticion) async {
      uri.add(peticion.url);
      if (peticion.url.path.endsWith('/categorias-gasto')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'nombre': 'Wifi',
              'periodicidad': 'mensual',
              'tipo_importe': 'fijo',
              'monto_habitual': '100.00',
              'activo': true,
            },
            {
              'id': 2,
              'nombre': 'Etiquetas',
              'periodicidad': 'sin_periodicidad',
              'tipo_importe': 'variable',
              'monto_habitual': null,
              'activo': true,
            },
          ]),
          200,
        );
      }
      return http.Response(jsonEncode(_gastos), 200);
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
  return uri;
}

void main() {
  for (final ancho in [320.0, 390.0, 600.0, 760.0, 1440.0]) {
    testWidgets('gastos legibles y sin overflow en ancho $ancho', (
      tester,
    ) async {
      final peticiones = await _montar(tester, Size(ancho, 900));
      expect(find.text('Total del mes'), findsOneWidget);
      expect(find.text('Pagado'), findsAtLeastNWidgets(1));
      expect(find.text('Pendiente'), findsAtLeastNWidgets(1));
      expect(find.text('Bs 150.00'), findsOneWidget);
      expect(find.text('Bs 70.00'), findsOneWidget);
      expect(find.text('Bs 80.00'), findsOneWidget);
      final consultaGastos = peticiones.firstWhere(
        (uri) => uri.path.endsWith('/gastos'),
      );
      expect(
        consultaGastos.queryParameters,
        containsPair('fecha_inicio', _fechaInicioTexto),
      );
      expect(
        consultaGastos.queryParameters,
        containsPair('fecha_fin', _fechaFinTexto),
      );
      expect(consultaGastos.queryParameters, containsPair('limite', '500'));
      expect(find.byType(DataTable).evaluate().isNotEmpty, ancho >= 760);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtros de categoría y estado y navegación por mes', (
    tester,
  ) async {
    final peticiones = await _montar(tester, const Size(390, 844));
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wifi').last);
    await tester.pumpAndSettle();
    expect(find.text('Internet mensual'), findsOneWidget);
    expect(find.text('Etiquetas para productos'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagados').last);
    await tester.pumpAndSettle();
    expect(find.text('Internet mensual'), findsNothing);
    expect(find.text('Etiquetas para productos'), findsOneWidget);
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    final mesAnterior = DateTime(_mesActual.year, _mesActual.month - 1, 1);
    final inicioAnterior =
        '${mesAnterior.year.toString().padLeft(4, '0')}-'
        '${mesAnterior.month.toString().padLeft(2, '0')}-01';
    final finAnterior = DateTime(mesAnterior.year, mesAnterior.month + 1, 0);
    final finAnteriorTexto =
        '${finAnterior.year.toString().padLeft(4, '0')}-'
        '${finAnterior.month.toString().padLeft(2, '0')}-'
        '${finAnterior.day.toString().padLeft(2, '0')}';
    final consultaAnterior = peticiones.lastWhere(
      (uri) => uri.path.endsWith('/gastos'),
    );
    expect(consultaAnterior.queryParameters['fecha_inicio'], inicioAnterior);
    expect(consultaAnterior.queryParameters['fecha_fin'], finAnteriorTexto);
    expect(tester.takeException(), isNull);
  });
}
