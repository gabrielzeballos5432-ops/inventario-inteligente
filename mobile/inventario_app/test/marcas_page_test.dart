import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/utils/mensaje_error.dart';
import 'package:inventario_app/features/productos/presentation/marcas_dialog.dart';

/// Respuesta JSON como la manda FastAPI: application/json SIN charset, que
/// package:http decodificaria como latin-1 si se leyera `body`.
http.Response _json(Object datos, int codigo) => http.Response.bytes(
  utf8.encode(jsonEncode(datos)),
  codigo,
  headers: {'content-type': 'application/json'},
);

/// Con pump y no pumpAndSettle: el campo con foco del dialogo sigue
/// animando y pumpAndSettle no termina (igual que en proveedores_page_test).
Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _registrar(WidgetTester tester, String nombre) async {
  await tester.tap(find.text('Registrar'));
  await _esperar(tester);
  final dialogo = find.byType(AlertDialog);
  await tester.enterText(
    find.descendant(of: dialogo, matching: find.byType(TextFormField)),
    nombre,
  );
  await tester.tap(find.descendant(of: dialogo, matching: find.text('Registrar')));
  await _esperar(tester);
}

void main() {
  testWidgets('crear marca la muestra en la lista y avisa', (tester) async {
    final catalogo = <Map<String, dynamic>>[];
    var consultas = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MarcasPage())),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No hay marcas registradas'), findsOneWidget);

      await _registrar(tester, 'Revlon');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Revlon'), findsOneWidget);
      expect(find.text('Marca registrada: Revlon'), findsOneWidget);
      expect(consultas, 2);
      expect(tester.takeException(), isNull);
    }, () => MockClient((peticion) async {
      if (peticion.method == 'POST') {
        final marca = {
          ...jsonDecode(peticion.body) as Map<String, dynamic>,
          'id': 1,
          'activo': true,
        };
        catalogo.add(marca);
        return _json(marca, 201);
      }
      consultas++;
      return _json(catalogo, 200);
    }));
  });

  testWidgets('un rechazo deja el dialogo abierto con el motivo legible', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MarcasPage())),
      );
      await tester.pumpAndSettle();

      await _registrar(tester, 'Loreal');

      // Sigue abierto, con lo escrito y el mensaje con tildes intacto.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Loreal'), findsOneWidget);
      expect(
        find.text('Ya existe una marca activa con ese nombre (sin distinción)'),
        findsOneWidget,
      );
    }, () => MockClient((peticion) async {
      if (peticion.method == 'POST') {
        return _json({
          'detail': 'Ya existe una marca activa con ese nombre (sin distinción)',
        }, 400);
      }
      return _json(<Object>[], 200);
    }));
  });

  group('mensajes de error', () {
    test('422 de Pydantic sale como frase, no como mapa', () {
      final e = ApiException(422, jsonEncode({
        'detail': [
          {
            'type': 'less_than_equal',
            'loc': ['body', 'precio_compra'],
            'msg': 'Debe ser como máximo 99999999.99',
          },
        ],
      }));
      expect(e.detalle, 'Precio compra: Debe ser como máximo 99999999.99');
    });

    test('un 500 con HTML no muestra el HTML', () {
      final e = ApiException(502, '<html><body>Bad gateway</body></html>');
      expect(e.detalle, contains('El servidor tuvo un problema (502)'));
    });

    test('timeout y red caida se explican en castellano', () {
      expect(
        mensajeDeError(TimeoutException('x')),
        startsWith('El servidor no respondió a tiempo'),
      );
      expect(
        mensajeDeError(http.ClientException('Failed to fetch')),
        startsWith('No se pudo conectar con el servidor'),
      );
    });
  });
}
