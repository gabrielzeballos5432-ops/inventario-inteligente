import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/shared/widgets/boton_seguro.dart';

Widget _envolver(Widget hijo) =>
    MaterialApp(home: Scaffold(body: Center(child: hijo)));

void main() {
  testWidgets('doble toque con accion asincrona ejecuta una sola vez', (
    tester,
  ) async {
    var llamadas = 0;
    final pendiente = Completer<void>();
    await tester.pumpWidget(
      _envolver(
        BotonSeguro(
          onPressed: () {
            llamadas++;
            return pendiente.future;
          },
          child: const Text('Registrar'),
        ),
      ),
    );

    await tester.tap(find.text('Registrar'));
    await tester.tap(find.text('Registrar'), warnIfMissed: false);
    await tester.pump();

    expect(llamadas, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendiente.complete();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Registrar'));
    await tester.pump(const Duration(seconds: 1));
    expect(llamadas, 2);
  });

  testWidgets('doble toque sobre un pop sincrono no cierra dos rutas', (
    tester,
  ) async {
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navegador,
        home: const Scaffold(body: Text('Pagina base')),
      ),
    );
    unawaited(
      showDialog<void>(
        context: navegador.currentContext!,
        builder: (context) => AlertDialog(
          actions: [
            BotonSeguro(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceptar'));
    await tester.tap(find.text('Aceptar'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Pagina base'), findsOneWidget);
    expect(navegador.currentState!.canPop(), isFalse);
  });

  testWidgets('BotonIconoSeguro ignora el segundo toque', (tester) async {
    var llamadas = 0;
    final pendiente = Completer<void>();
    await tester.pumpWidget(
      _envolver(
        BotonIconoSeguro(
          tooltip: 'Confirmar',
          onPressed: () {
            llamadas++;
            return pendiente.future;
          },
          icon: const Icon(Icons.check),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pump();

    expect(llamadas, 1);
    pendiente.complete();
    await tester.pump(const Duration(seconds: 1));
  });
}
