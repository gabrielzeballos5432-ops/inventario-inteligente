import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/app/destino_app.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/shared/widgets/menu_lateral.dart';

void main() {
  test('destinos por rol y atajos sin índices de posición', () {
    final vendedor = DestinoApp.disponibles(false);
    expect(
      vendedor,
      containsAll([
        DestinoApp.panel,
        DestinoApp.ventas,
        DestinoApp.caja,
        DestinoApp.productos,
        DestinoApp.movimientos,
        DestinoApp.deteccion,
        DestinoApp.jornadas,
      ]),
    );
    expect(vendedor.any((destino) => destino.soloAdmin), isFalse);
    expect(DestinoApp.disponibles(true), DestinoApp.values);
    expect(DestinoApp.jornadas.etiqueta(false), 'Mi jornada');
  });

  testWidgets('menú fijo agrupa destinos y no cierra la página al navegar', (
    tester,
  ) async {
    DestinoApp? seleccionado;
    var cerroSesion = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTemaClaro(),
        home: Scaffold(
          body: MenuLateral(
            permanente: true,
            elementos: DestinoApp.disponibles(true),
            seleccion: DestinoApp.productos,
            usuarioNombre: 'Administrador',
            rol: 'Administrador',
            esNoche: false,
            mostrarGestion: true,
            alNavegar: (destino) => seleccionado = destino,
            alAlternarTema: () {},
            alConfigurarServidor: () {},
            alCerrarSesion: () => cerroSesion = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ventas'));
    await tester.pumpAndSettle();
    expect(seleccionado, DestinoApp.ventas);
    expect(find.byType(MenuLateral), findsOneWidget);
    expect(find.text('OPERACIÓN'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Gastos'), 150);
    await tester.tap(find.text('Gastos'));
    expect(seleccionado, DestinoApp.gastos);
    await tester.scrollUntilVisible(find.text('Cerrar sesion'), 150);
    await tester.tap(find.text('Cerrar sesion'));
    expect(cerroSesion, isTrue);
    expect(find.byType(MenuLateral), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menú móvil navega al destino y cierra solo el drawer', (
    tester,
  ) async {
    DestinoApp? seleccionado;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTemaNoche(),
        home: Scaffold(
          appBar: AppBar(),
          drawer: MenuLateral(
            elementos: DestinoApp.disponibles(false),
            seleccion: DestinoApp.panel,
            usuarioNombre: 'Vendedor',
            rol: 'Vendedor',
            esNoche: true,
            mostrarGestion: false,
            alNavegar: (destino) => seleccionado = destino,
            alAlternarTema: () {},
            alConfigurarServidor: () {},
            alCerrarSesion: () {},
          ),
          body: const Text('Página principal'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Gestión'), findsNothing);
    expect(find.text('Usuarios'), findsNothing);
    await tester.tap(find.text('Ventas'));
    await tester.pumpAndSettle();
    expect(seleccionado, DestinoApp.ventas);
    expect(find.text('Página principal'), findsOneWidget);
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);
  });
}
