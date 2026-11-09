import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';

void main() {
  test('envía la foto al lector sin registrar una compra', () async {
    final peticiones = <http.Request>[];
    final servicio = OperacionesService(
      ApiClient(
        httpClient: MockClient((peticion) async {
          peticiones.add(peticion);
          expect(peticion.url.path, '/api/compras/leer-comprobante');
          expect(
            peticion.headers['content-type'],
            contains('multipart/form-data'),
          );
          expect(peticion.body, contains('name="imagen"'));
          expect(peticion.body, contains('filename="factura.jpg"'));
          return http.Response(
            jsonEncode({
              'numero_factura': 'F-1',
              'moneda_codigo': null,
              'total_impreso': '7200',
              'subtotal_calculado': '7200',
              'detalles': [
                {
                  'descripcion': 'Uñas postizas',
                  'producto_id': null,
                  'cantidad': 12,
                  'costo_unitario_moneda': '600',
                },
              ],
              'advertencias': ['Confirma la moneda'],
              'texto_detectado': '12x600 =7200',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    final lectura = await servicio.leerComprobante(
      bytes: [1, 2, 3],
      nombre: 'factura.jpg',
    );
    expect(lectura['numero_factura'], 'F-1');
    expect(lectura['moneda_codigo'], isNull);
    expect(peticiones, hasLength(1));
  });

  test(
    'muestra el rechazo del lector sin simular una lectura exitosa',
    () async {
      final servicio = OperacionesService(
        ApiClient(
          httpClient: MockClient(
            (_) async =>
                http.Response('{"detail":"PaddleOCR no está instalado"}', 503),
          ),
        ),
      );
      await expectLater(
        servicio.leerComprobante(bytes: [1], nombre: 'foto.jpg'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'estado', 503)),
      );
    },
  );
}
