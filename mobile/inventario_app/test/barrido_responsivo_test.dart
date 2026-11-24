// Barrido de responsividad: recorre todas las secciones del menu y abre sus
// formularios en varios tamaños (telefono chico, acostado, tablet,
// escritorio y letra grande del sistema), y falla si algo se desborda.
//
// Corre con el resto de la suite (~30 s). Solo este archivo:
//   flutter test test/barrido_responsivo_test.dart
// Si falla, el mensaje dice la seccion, el formulario y el archivo:linea del
// widget que se desborda.
//
// Los datos (test/fixtures/barrido_datos.json) salen del backend real con
// nombres, correos y telefonos reemplazados; cada lista se multiplica y el
// primer elemento lleva un nombre muy largo para forzar el peor caso.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventario_app/app/destino_app.dart';
import 'package:inventario_app/app/theme.dart';
import 'package:inventario_app/core/network/api_client.dart';
import 'package:inventario_app/core/providers/auth_provider.dart';
import 'package:inventario_app/core/providers/inventario_provider.dart';
import 'package:inventario_app/core/providers/sucursal_controller.dart';
import 'package:inventario_app/core/providers/theme_controller.dart';
import 'package:inventario_app/core/services/auth_service.dart';
import 'package:inventario_app/core/services/configuracion_service.dart';
import 'package:inventario_app/core/services/detection_service.dart';
import 'package:inventario_app/core/services/local_db_service.dart';
import 'package:inventario_app/core/services/operaciones_service.dart';
import 'package:inventario_app/core/services/product_service.dart';
import 'package:inventario_app/features/shell/presentation/shell_page.dart';
import 'package:inventario_app/shared/widgets/menu_lateral.dart';
import 'package:provider/provider.dart';

class _Admin extends AuthProvider {
  _Admin(ApiClient api) : super(AuthService(api));
  @override
  bool get isAdmin => true;
}

/// El SQLite real no existe en los tests.
class _DbMemoria extends LocalDbService {
  @override
  Future<void> cachearInventario(List<Map<String, dynamic>> productos) async {}
  @override
  Future<List<Map<String, dynamic>>> obtenerCacheInventario() async => [];
  @override
  Future<List<Map<String, dynamic>>> obtenerPendientes() async => [];
}

const _largo = ' Profesional Ultra Hidratante con Keratina 400 ml';

/// 8 copias (con id propio) de cada lista y un nombre largo en la primera.
Object? _estresar(Object? datos) {
  if (datos is! List || datos.isEmpty || datos.first is! Map) return datos;
  final conId = (datos.first as Map)['id'] is int;
  final copia = [
    for (var i = 0; i < (conId ? 8 : 1); i++)
      for (final e in datos)
        {
          ...Map<String, dynamic>.from(e as Map),
          if (conId && i > 0) 'id': (e['id'] as int) + 1000 * i,
        },
  ];
  for (final campo in ['nombre', 'concepto', 'producto_nombre']) {
    if (copia.first[campo] is String) copia.first[campo] += _largo;
  }
  return copia;
}

bool _dentroDeBoton(Element e) {
  var es = false;
  e.visitAncestorElements((a) {
    if (a.widget is ButtonStyleButton) es = true;
    return !es;
  });
  return es;
}

/// Botones que abren un formulario (no los que guardan o navegan).
final _abreFormulario = RegExp(
  r'^(Registrar|Nuev|Agregar|Abrir caja|Cerrar caja|Movimiento|Monedas)',
);

const _casos = [
  (Size(320, 640), 1.0), // telefono chico
  (Size(390, 844), 1.0), // telefono comun
  (Size(844, 390), 1.0), // telefono acostado
  (Size(768, 1024), 1.0), // tablet
  (Size(1024, 768), 1.0), // laptop chica (menu como cajon)
  (Size(1440, 900), 1.0), // escritorio (menu fijo)
  (Size(390, 844), 1.3), // letra del sistema grande
  (Size(360, 740), 1.5), // letra del sistema muy grande
];

void main() {
  final datos =
      jsonDecode(File('test/fixtures/barrido_datos.json').readAsStringSync())
          as Map<String, dynamic>;
  datos['/api/contabilidad/reporte-financiero'] = {
    'costo_historico_completo': true,
    'detalles_sin_costo_historico': 0,
    'ventas_netas_bob': '1234567.89',
    'costo_ventas_bob': '765432.10',
    'ganancia_bruta_bob': '469135.79',
    'gastos_operativos_bob': '120000.00',
    'sueldos_y_bonos_bob': '40000.00',
    'cargos_adicionales_bob': '0.00',
    'utilidad_operativa_bob': '309135.79',
    'utilidad_neta_estimada_bob': '309135.79',
    'nota': 'Estimación de prueba.',
  };

  for (final (tamano, escala) in _casos) {
    final nombre =
        '${tamano.width.toInt()}x${tamano.height.toInt()} letra $escala';
    testWidgets('sin desbordes: $nombre', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = tamano;
      addTearDown(tester.view.reset);

      // Se anota cada error de Flutter con la seccion y el archivo:linea del
      // widget que lo causo; al final el test falla si hubo alguno.
      final hallazgos = <String>{};
      var donde = 'inicio';
      var formularios = 0;
      final original = FlutterError.onError;
      FlutterError.onError = (detalle) {
        final texto = '$detalle\n${detalle.stack}';
        final lineas = RegExp(r'lib/([\w/]+\.dart):(\d+)')
            .allMatches(texto)
            .map((m) => '${m.group(1)}:${m.group(2)}')
            .toSet()
            .take(3)
            .join(' ');
        final mensaje = detalle.exceptionAsString().split('\n').first;
        hallazgos.add('[$donde] $mensaje @ $lineas');
      };

      final mock = MockClient((p) async {
        final cuerpo = datos[p.url.path] ??
            (p.method == 'GET' ? <Object>[] : <String, Object>{});
        return http.Response.bytes(
          utf8.encode(jsonEncode(_estresar(cuerpo))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(httpClient: mock);

      // runWithClient: las paginas que crean su propio ApiClient() tambien
      // usan el mock.
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(create: (_) => _Admin(api)),
              ChangeNotifierProvider<InventarioProvider>(
                create: (_) => InventarioProvider(
                  ProductService(api),
                  DetectionService(api),
                  _DbMemoria(),
                )..refrescarTodo(),
              ),
              ChangeNotifierProvider(
                create: (_) => ThemeController.inicial(ThemeMode.dark),
              ),
              Provider(create: (_) => OperacionesService(api)),
              ChangeNotifierProvider.value(value: SucursalController.instance),
              Provider(create: (_) => ConfiguracionService(api)),
            ],
            child: MaterialApp(
              theme: buildTemaNoche(),
              builder: (context, hijo) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(escala)),
                child: hijo!,
              ),
              home: const ShellPage(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        for (final destino in DestinoApp.disponibles(true)) {
          donde = destino.name;
          await _abrirSeccion(tester, destino, tamano);
          if (find
              .descendant(
                of: find.byType(AppBar),
                matching: find.text(destino.etiqueta(true)),
              )
              .evaluate()
              .isEmpty) {
            hallazgos.add('[$donde] no se pudo abrir la seccion');
            continue;
          }
          formularios += await _probarFormularios(tester, tamano, (etiqueta) {
            donde = '${destino.name} > $etiqueta';
          });
        }
      }, () => mock);

      // Antes de cualquier expect: el binding exige el manejador original.
      FlutterError.onError = original;
      debugPrint('$nombre: ${DestinoApp.disponibles(true).length} secciones, '
          '$formularios formularios');
      expect(formularios, greaterThan(10), reason: 'no se abrieron formularios');
      expect(hallazgos, isEmpty, reason: hallazgos.join('\n'));
    });
  }
}

Future<void> _esperar(WidgetTester tester, [int veces = 4]) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _abrirSeccion(
  WidgetTester tester,
  DestinoApp destino,
  Size tamano,
) async {
  // Por debajo de 1100 px el menu es un cajon que hay que abrir.
  if (tamano.width < 1100) {
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await _esperar(tester, 2);
  }
  final menu = find.byType(MenuLateral);
  final item = find.descendant(
    of: menu,
    matching: find.text(destino.etiqueta(true)),
  );
  // El menu construye sus filas al desplazarse: primero hay que llegar.
  await tester.scrollUntilVisible(
    item,
    120,
    scrollable: find.descendant(of: menu, matching: find.byType(Scrollable)).first,
    maxScrolls: 40,
  );
  await tester.ensureVisible(item.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(item.first, warnIfMissed: false);
  await _esperar(tester, 6);
}

/// Abre cada formulario de la seccion, lo mide con el teclado abierto y lo
/// cierra.
Future<int> _probarFormularios(
  WidgetTester tester,
  Size tamano,
  void Function(String) alAbrir,
) async {
  final pagina = find.byType(IndexedStack);
  final etiquetas = <String>{
    for (final e
        in find.descendant(of: pagina, matching: find.byType(Text)).evaluate())
      if (_abreFormulario.hasMatch((e.widget as Text).data ?? '') &&
          _dentroDeBoton(e))
        (e.widget as Text).data!,
  };
  var abiertos = 0;
  for (final etiqueta in etiquetas) {
    final boton = find.descendant(of: pagina, matching: find.text(etiqueta));
    if (boton.evaluate().isEmpty) continue;
    alAbrir(etiqueta);
    await tester.ensureVisible(boton.first);
    await tester.tap(boton.first, warnIfMissed: false);
    await _esperar(tester);
    if (find.byType(Dialog).evaluate().isEmpty &&
        find.byType(AlertDialog).evaluate().isEmpty) {
      continue;
    }
    abiertos++;
    // Teclado realista: la mitad del alto, como mucho 300 px.
    tester.view.viewInsets = FakeViewPadding(
      bottom: (tamano.height / 2).clamp(0, 300).toDouble(),
    );
    await tester.pump(const Duration(milliseconds: 300));
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 100));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((ruta) => ruta.isFirst);
    await _esperar(tester, 3);
  }
  return abiertos;
}
