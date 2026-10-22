import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/servidor_controller.dart';

/// El controlador decide si el backend responde. Se prueba con un cliente
/// simulado para no depender de que el servidor real este levantado.
void main() {
  test('arranca en comprobando y pasa a conectado si /api/health responde',
      () async {
    final api = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response('{"estado":"ok"}', 200),
      ),
    );
    final controlador = ServidorController(api);

    expect(controlador.estado, EstadoServidor.comprobando);
    await controlador.verificar();
    expect(controlador.estado, EstadoServidor.conectado);
  });

  test('pasa a desconectado si el servidor no responde', () async {
    final api = ApiClient(
      httpClient: MockClient((_) async => throw Exception('sin red')),
    );
    final controlador = ServidorController(api);

    await controlador.verificar();
    expect(controlador.estado, EstadoServidor.desconectado);
  });

  test('avisa una sola vez cuando el servidor vuelve', () async {
    var disponible = false;
    final api = ApiClient(
      httpClient: MockClient((_) async {
        if (!disponible) throw Exception('sin red');
        return http.Response('{"estado":"ok"}', 200);
      }),
    );
    var reconexiones = 0;
    final controlador = ServidorController(
      api,
      onReconectado: () => reconexiones++,
    );

    await controlador.verificar();
    expect(controlador.estado, EstadoServidor.desconectado);
    expect(reconexiones, 0);

    disponible = true;
    await controlador.verificar();
    expect(controlador.estado, EstadoServidor.conectado);
    expect(reconexiones, 1);

    // Ya conectado, otro chequeo no vuelve a avisar.
    await controlador.verificar();
    expect(reconexiones, 1);
  });
}
