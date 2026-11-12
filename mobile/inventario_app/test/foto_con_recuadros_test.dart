import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventario_app/core/models/detection_record.dart';
import 'package:inventario_app/features/deteccion/presentation/foto_con_recuadros.dart';

/// Foto blanca de 2x1 px: sirve para comprobar que se respeta la proporcion.
final _png2x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGP8//8/AwMDAA7/Av+4xZ6ZAAAAAElFTkSuQmCC',
);

void main() {
  test('la respuesta del servidor trae un recuadro por unidad', () {
    final r = ResultadoInferencia.fromJson({
      'detecciones': [
        {
          'producto_id': 21,
          'producto_nombre': 'Iluminador líquido',
          'confianza': 0.81,
          'cantidad': 2,
          'cajas': [
            {'x1': 0.1, 'y1': 0.2, 'x2': 0.4, 'y2': 0.9, 'confianza': 0.81},
            {'x1': 0.5, 'y1': 0.2, 'x2': 0.8, 'y2': 0.9, 'confianza': 0.62},
          ],
        },
        // Un servidor anterior no envia cajas: no debe fallar.
        {'producto_id': 22, 'producto_nombre': 'Sombra', 'confianza': 0.7, 'cantidad': 1},
      ],
      'total_productos': 2,
    });
    final ilum = r.detecciones.first;
    expect(ilum.cajas, hasLength(2));
    expect(ilum.cajas[1].x1, 0.5);
    expect(ilum.cajas[1].confianza, 0.62);
    expect(r.detecciones[1].cajas, isEmpty);
  });

  testWidgets('muestra la foto entera con sus recuadros y su proporcion', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final detecciones = [
      Deteccion(
        productoId: 21,
        productoNombre: 'Iluminador líquido',
        confianza: 0.81,
        cantidad: 2,
        cajas: const [
          Caja(x1: 0.1, y1: 0.2, x2: 0.4, y2: 0.9, confianza: 0.81),
          Caja(x1: 0.5, y1: 0.2, x2: 0.8, y2: 0.9, confianza: 0.62),
        ],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [FotoConRecuadros(bytes: _png2x1, detecciones: detecciones)],
          ),
        ),
      ),
    );
    // La decodificacion de la imagen es asincrona de verdad: se espera hasta
    // que aparezca la foto (con la maquina ocupada tarda mas de 200 ms).
    for (var i = 0; i < 30 && find.byType(AspectRatio).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    final pintor = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<PintorRecuadros>()
        .single;
    expect(pintor.detecciones.single.cajas, hasLength(2));
    expect(find.bySemanticsLabel('Foto con 2 recuadro(s) de deteccion'), findsOneWidget);

    // Foto 2:1 a lo ancho de 400 px -> 200 px de alto, sin recortar.
    final tamano = tester.getSize(find.byType(AspectRatio));
    expect(tamano.width, 400);
    expect(tamano.height, 200);
    expect(tester.takeException(), isNull);
  });

  test('cada producto tiene siempre el mismo color, distinto al del otro', () {
    expect(colorDeDeteccion(21), isNot(colorDeDeteccion(22)));
    expect(colorDeDeteccion(21), colorDeDeteccion(21));
    expect(colorDeDeteccion(21 + coloresRecuadro.length), colorDeDeteccion(21));
  });
}
