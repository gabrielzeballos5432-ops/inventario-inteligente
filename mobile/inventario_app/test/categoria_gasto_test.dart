import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/models/categoria_gasto.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/features/contabilidad/presentation/categorias_gasto_dialog.dart';
import 'package:provider/provider.dart';

Finder _campo(String etiqueta) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == etiqueta,
);

Finder _selector(String etiqueta) => find
    .ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator && widget.decoration.labelText == etiqueta,
      ),
      matching: find.byType(DropdownButtonFormField<String>),
    )
    .first;

Future<void> _esperar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _elegir(WidgetTester tester, String etiqueta, String valor) async {
  await tester.tap(_selector(etiqueta));
  await _esperar(tester);
  await tester.tap(find.text(valor).last);
  await _esperar(tester);
}

void main() {
  test(
    'nombres antiguos se muestran legibles y nombres con espacios se conservan',
    () {
      for (final nombre in [
        'insumo_limpieza',
        'Papel para tickets',
        'Wifi hogar',
      ]) {
        final categoria = CategoriaGasto.fromJson({
          'id': 1,
          'nombre': nombre,
          'periodicidad': 'sin_periodicidad',
          'tipo_importe': 'variable',
          'monto_habitual': null,
          'activo': true,
        });
        expect(
          categoria.nombre,
          nombre == 'insumo_limpieza' ? 'Insumos de limpieza' : nombre,
        );
        expect(
          nombreCategoriaGasto(nombre),
          nombre == 'insumo_limpieza' ? 'Insumos de limpieza' : nombre,
        );
      }
    },
  );
  for (final caso in [
    (
      'mensual',
      DateTime(2028, 2, 20),
      DateTime(2028, 2),
      DateTime(2028, 2, 29),
    ),
    (
      'semanal',
      DateTime(2026, 11, 1),
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 1),
    ),
    ('anual', DateTime(2026, 11, 1), DateTime(2026), DateTime(2026, 12, 31)),
  ]) {
    test('periodo ${caso.$1} cubre limites del calendario', () {
      final categoria = CategoriaGasto(
        id: 1,
        nombre: 'Prueba',
        periodicidad: caso.$1,
        tipoImporte: 'variable',
        activo: true,
      );
      expect(categoria.periodoSugerido(caso.$2), (
        desde: caso.$3,
        hasta: caso.$4,
      ));
    });
  }
  test('sin periodicidad no sugiere fechas y lee Decimal como string', () {
    final categoria = CategoriaGasto.fromJson({
      'id': 1,
      'nombre': 'Scotch',
      'periodicidad': 'sin_periodicidad',
      'tipo_importe': 'fijo',
      'monto_habitual': '15.50',
      'activo': true,
    });
    expect(categoria.montoHabitual, 15.50);
    expect(categoria.periodoSugerido(DateTime(2026, 11, 1)), isNull);
  });

  testWidgets(
    'tabla permite añadir editar eliminar y reactivar sin crear gastos',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 1000);
      addTearDown(tester.view.reset);
      final filas = <Map<String, dynamic>>[];
      final rutas = <String>[];
      var rechazar = true;
      final api = ApiClient(
        httpClient: MockClient((peticion) async {
          rutas.add(peticion.url.path);
          if (peticion.method == 'POST' && rechazar) {
            rechazar = false;
            return http.Response(
              '{"detail":"No se pudo guardar la categoría de prueba."}',
              400,
            );
          }
          if (peticion.method == 'POST') {
            final datos = {
              ...jsonDecode(peticion.body) as Map<String, dynamic>,
              'id': 1,
              'activo': true,
            };
            if (filas.isEmpty) {
              filas.add(datos);
            } else {
              filas[0] = datos;
            }
          } else if (peticion.method == 'PUT') {
            filas[0] = {
              ...jsonDecode(peticion.body) as Map<String, dynamic>,
              'id': 1,
            };
          } else if (peticion.method == 'DELETE') {
            filas[0]['activo'] = false;
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode(
              peticion.method == 'GET'
                  ? filas.where((fila) => fila['activo'] == true).toList()
                  : filas.last,
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const CategoriasGastoDialog(),
                  ),
                  child: const Text('Abrir gestor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir gestor'));
      await _esperar(tester);
      await tester.tap(find.text('Añadir categoría'));
      await _esperar(tester);
      await tester.enterText(_campo('Nombre'), 'Wifi hogar');
      await _elegir(tester, 'Periodicidad', 'Mensual');
      await _elegir(tester, 'Tipo de importe', 'Fijo');
      await tester.enterText(_campo('Monto habitual (Bs, opcional)'), '100');
      await tester.tap(find.text('Guardar categoría'));
      await _esperar(tester);
      expect(
        find.text('No se pudo guardar la categoría de prueba.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Guardar categoría'));
      await _esperar(tester);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('100.00'), findsOneWidget);
      expect(filas.single['nombre'], 'Wifi hogar');
      expect(find.text('Wifi hogar'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Editar Wifi hogar'));
      await tester.tap(find.byTooltip('Editar Wifi hogar'));
      await _esperar(tester);
      await tester.enterText(_campo('Monto habitual (Bs, opcional)'), '120');
      await tester.tap(find.text('Guardar categoría'));
      await _esperar(tester);
      expect(filas.single['monto_habitual'], '120.00');
      await tester.ensureVisible(find.byTooltip('Eliminar Wifi hogar'));
      await tester.tap(find.byTooltip('Eliminar Wifi hogar'));
      await _esperar(tester);
      await tester.tap(find.text('Eliminar').last);
      await _esperar(tester);
      expect(find.text('Wifi hogar'), findsNothing);
      expect(find.text('Inactiva'), findsNothing);
      expect(filas.single['activo'], isFalse);
      await tester.tap(find.text('Añadir categoría'));
      await _esperar(tester);
      await tester.enterText(_campo('Nombre'), 'Wifi hogar');
      await _elegir(tester, 'Periodicidad', 'Mensual');
      await tester.tap(find.text('Guardar categoría'));
      await _esperar(tester);
      expect(filas.single['activo'], isTrue);
      expect(filas.single['periodicidad'], 'mensual');
      expect(filas, hasLength(1));
      expect(find.text('Wifi hogar'), findsOneWidget);
      expect(rutas.every((ruta) => ruta.contains('categorias-gasto')), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
