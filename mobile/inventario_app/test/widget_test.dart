import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/app/inventario_app.dart';

void main() {
  testWidgets('renderiza la app principal', (WidgetTester tester) async {
    await tester.pumpWidget(const InventarioApp());
    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
