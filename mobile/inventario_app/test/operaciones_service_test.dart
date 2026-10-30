import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';

void main() {
  test('actualiza las tarifas de sueldo de un vendedor', () async {
    late http.Request solicitud;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        solicitud = request;
        return http.Response(
          jsonEncode({
            'id': 4,
            'pago_por_hora': '12.50',
            'porcentaje_comision': '5.00',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = OperacionesService(api);

    final actualizado = await service.actualizarTarifasVendedor(
      usuarioId: 4,
      pagoPorHora: '12.50',
      porcentajeComision: '5.00',
    );

    expect(solicitud.method, 'PUT');
    expect(solicitud.url.path, '/api/usuarios/4');
    expect(jsonDecode(solicitud.body), {
      'pago_por_hora': '12.50',
      'porcentaje_comision': '5.00',
    });
    expect(actualizado['pago_por_hora'], '12.50');
  });

  test('administra monedas y conserva los contratos del backend', () async {
    final solicitudes = <http.Request>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        solicitudes.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'codigo': 'BOB',
                'nombre': 'Boliviano',
                'simbolo': 'Bs',
                'pais': 'Bolivia',
                'decimales': 2,
                'activa': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'codigo': 'PEN',
              'nombre': 'Sol',
              'simbolo': 'S/',
              'pais': 'Perú',
              'decimales': 2,
              'activa': true,
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'codigo': 'PEN',
            'nombre': 'Sol',
            'simbolo': 'S/',
            'pais': 'Perú',
            'decimales': 2,
            'activa': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = OperacionesService(api);

    final monedas = await service.listarMonedas(incluirInactivas: true);
    final creada = await service.crearMoneda(
      codigo: 'pen',
      nombre: 'Sol',
      simbolo: 'S/',
      pais: 'Perú',
      decimales: 2,
    );
    final desactivada = await service.actualizarEstadoMoneda('PEN', false);

    expect(monedas.single['codigo'], 'BOB');
    expect(solicitudes[0].url.queryParameters['incluir_inactivas'], 'true');
    expect(solicitudes[1].url.path, '/api/monedas/');
    expect(jsonDecode(solicitudes[1].body)['codigo'], 'PEN');
    expect(creada['activa'], true);
    expect(solicitudes[2].method, 'PATCH');
    expect(solicitudes[2].url.path, '/api/monedas/PEN/estado');
    expect(jsonDecode(solicitudes[2].body), {'activa': false});
    expect(desactivada['activa'], false);
  });
}
