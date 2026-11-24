import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/models/sucursal.dart';
import 'package:inventario_app/core/providers/sucursal_controller.dart';
import 'package:inventario_app/core/services/product_service.dart';

// El lote es la pieza de recepcion de mercaderia: si el payload llega mal
// (tipos, nombres de campos) el backend lo rechaza y el usuario pierde la
// carga completa. Aqui se comprueba el contrato por encima de un cliente falso.
void main() {
  test('registrarLote envia tipo y las filas con producto_id y cantidad', () async {
    Uri? uriCapturada;
    Map<String, dynamic>? cuerpoCapturado;

    final api = ApiClient(
      httpClient: MockClient((request) async {
        uriCapturada = request.url;
        cuerpoCapturado =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'tipo': 'entrada', 'guardados': 2, 'resultados': []}),
          201,
        );
      }),
    );

    final resultado = await ProductService(api).registrarLote(
      tipo: 'entrada',
      razonId: 4,
      items: const [
        (productoId: 7, cantidad: 10),
        (productoId: 9, cantidad: 3),
      ],
    );

    expect(resultado.guardados, 2);
    expect(
      uriCapturada.toString(),
      contains('/api/inventario/movimientos/lote'),
    );
    expect(cuerpoCapturado!['tipo'], 'entrada');
    expect(cuerpoCapturado!['razon_movimiento_id'], 4);
    // Sin traspaso no se manda destino.
    expect(cuerpoCapturado!.containsKey('sucursal_destino_id'), isFalse);
    expect(cuerpoCapturado!['items'], [
      {'producto_id': 7, 'cantidad': 10},
      {'producto_id': 9, 'cantidad': 3},
    ]);
  });

  test('registrarLote propaga el rechazo fila a fila en ApiException.detalle',
      () async {
    final api = ApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'Fila 2 (Esmalte Rojo 30): no hay stock suficiente: disponible 3',
          }),
          400,
        );
      }),
    );

    Future<String> detalle() async {
      try {
        await ProductService(api).registrarLote(
          tipo: 'salida',
          razonId: 5,
          items: const [
            (productoId: 7, cantidad: 2),
            (productoId: 9, cantidad: 999),
          ],
        );
        return '';
      } on ApiException catch (e) {
        return e.detalle;
      }
    }

    final texto = await detalle();
    expect(texto, contains('Fila 2 (Esmalte Rojo 30)'));
    expect(texto, contains('disponible 3'));
  });

  test('traspaso manda la sucursal destino y el encabezado de la sucursal activa',
      () async {
    Map<String, dynamic>? cuerpo;
    Map<String, String>? encabezados;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
        encabezados = request.headers;
        return http.Response(
          jsonEncode({'tipo': 'salida', 'guardados': 1, 'resultados': []}),
          201,
        );
      }),
    );
    SucursalController.instance.fijarParaPruebas(
      sucursales: const [Sucursal(id: 1, nombre: 'Principal'), Sucursal(id: 2, nombre: 'Norte')],
      predeterminadaId: 1,
      activaId: 1,
    );
    addTearDown(() => SucursalController.instance.fijarParaPruebas());

    await ProductService(api).registrarLote(
      tipo: 'salida',
      razonId: 12,
      sucursalDestinoId: 2,
      items: const [(productoId: 7, cantidad: 4)],
    );

    expect(cuerpo!['razon_movimiento_id'], 12);
    expect(cuerpo!['sucursal_destino_id'], 2);
    // La operacion se registra en la sucursal activa (el backend la respeta
    // solo si el usuario es administrador).
    expect(encabezados!['X-Sucursal-Id'], '1');
  });

  test('sin sucursal activa no se manda el encabezado', () async {
    Map<String, String>? encabezados;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        encabezados = request.headers;
        return http.Response('[]', 200);
      }),
    );
    SucursalController.instance.fijarParaPruebas();
    await ProductService(api).reporteStock();
    expect(encabezados!.containsKey('X-Sucursal-Id'), isFalse);
  });
}
