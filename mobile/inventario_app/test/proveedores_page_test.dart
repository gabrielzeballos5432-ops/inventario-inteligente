import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/features/productos/presentation/proveedores_dialog.dart';

void main() {
  testWidgets('crear proveedor actualiza la lista sin mostrar un error', (
    tester,
  ) async {
    final catalogo = <Map<String, dynamic>>[];
    var consultas = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProveedoresPage())),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No hay proveedores registrados'),
          findsOneWidget,
        );

        await tester.tap(find.text('Registrar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final dialogo = find.byType(AlertDialog);
        await tester.enterText(
          find
              .descendant(of: dialogo, matching: find.byType(TextFormField))
              .first,
          'Distribuidora Andina',
        );
        await tester.tap(
          find.descendant(of: dialogo, matching: find.text('Registrar')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(catalogo, hasLength(1));
        expect(consultas, 2);
        expect(find.text('Distribuidora Andina'), findsOneWidget);
        expect(find.textContaining('No se pudo crear'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((peticion) async {
        expect(peticion.url.path, '/api/proveedores/');
        if (peticion.method == 'POST') {
          final datos = jsonDecode(peticion.body) as Map<String, dynamic>;
          final proveedor = {...datos, 'id': 1, 'activo': true};
          catalogo.add(proveedor);
          return http.Response(jsonEncode(proveedor), 201);
        }
        expect(peticion.method, 'GET');
        consultas++;
        return http.Response(jsonEncode(catalogo), 200);
      }),
    );
  });
}
