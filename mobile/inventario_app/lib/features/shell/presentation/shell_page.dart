import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/destino_app.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/providers/sucursal_controller.dart';
import '../../../core/services/configuracion_service.dart';
import '../../../core/providers/theme_controller.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../../shared/widgets/menu_lateral.dart';
import '../../../shared/widgets/selector_sucursal.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../caja/presentation/caja_page.dart';
import '../../configuracion/presentation/configuracion_page.dart';
import '../../contabilidad/presentation/finanzas_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../deteccion/presentation/detection_page.dart';
import '../../historial/presentation/history_page.dart';
import '../../productos/presentation/products_page.dart';
import '../../productos/presentation/marcas_dialog.dart';
import '../../productos/presentation/proveedores_dialog.dart';
import '../../usuarios/presentation/users_page.dart';
import '../../ventas/presentation/sales_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  DestinoApp _seleccion = DestinoApp.panel;
  final _visitados = <DestinoApp>{DestinoApp.panel};
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarSucursales());
  }

  /// Sucursales y razones al entrar. Si el administrador había elegido otra
  /// sucursal en esta sesión, el inventario ya cargado es el de la
  /// predeterminada y hay que pedirlo de nuevo.
  Future<void> _cargarSucursales() async {
    if (!mounted) return;
    final control = context.read<SucursalController>();
    await control.cargar(
      context.read<ConfiguracionService>(),
      esAdmin: context.read<AuthProvider>().isAdmin,
    );
    if (!mounted) return;
    if (control.activaId != control.predeterminadaId) _alCambiarSucursal();
  }

  void _alCambiarSucursal() {
    context.read<InventarioProvider>().refrescarTodo();
  }

  Future<void> _cerrarSesion(AuthProvider auth) async {
    await context.read<SucursalController>().reiniciar();
    await auth.logout();
  }

  void _navegar(DestinoApp destino) {
    FocusManager.instance.primaryFocus?.unfocus();
    if ({
          DestinoApp.categorias,
          DestinoApp.marcas,
          DestinoApp.proveedores,
        }.contains(_seleccion) &&
        destino != _seleccion) {
      context.read<InventarioProvider>().cargarInventario();
    }
    setState(() {
      _seleccion = destino;
      _visitados.add(destino);
    });
  }

  Widget _pagina(DestinoApp destino, bool esAdmin) => switch (destino) {
    DestinoApp.panel => DashboardPage(onNavegar: _navegar),
    DestinoApp.productos => const ProductsPage(),
    DestinoApp.ventas => SalesPage(activa: _seleccion == DestinoApp.ventas),
    DestinoApp.deteccion => const DetectionPage(),
    DestinoApp.movimientos => const HistoryPage(),
    DestinoApp.caja => CajaPage(esAdmin: esAdmin),
    DestinoApp.usuarios => const UsersPage(),
    DestinoApp.categorias => CategoriasPage(
      service: context.read<InventarioProvider>().productService,
    ),
    DestinoApp.marcas => const MarcasPage(),
    DestinoApp.proveedores => const ProveedoresPage(),
    DestinoApp.configuracion => ConfiguracionPage(
      alCambiarSucursales: _cargarSucursales,
    ),
    _ => FinanzasPage(seccion: destino),
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final esNoche = context.watch<ThemeController>().esNoche;
    final destinos = DestinoApp.disponibles(auth.isAdmin);
    if (!destinos.contains(_seleccion)) _seleccion = DestinoApp.panel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final permanente = constraints.maxWidth >= 1100;
        Widget menu({required bool fijo}) => MenuLateral(
          elementos: destinos,
          seleccion: _seleccion,
          permanente: fijo,
          usuarioNombre: auth.usuario?.nombre ?? 'Invitado',
          rol: auth.isAdmin ? 'Administrador' : 'Vendedor',
          esNoche: esNoche,
          mostrarGestion: auth.isAdmin,
          alNavegar: _navegar,
          alAlternarTema: () => context.read<ThemeController>().alternar(),
          alConfigurarServidor: () => mostrarDialogoServidor(context),
          alCerrarSesion: () => _cerrarSesion(auth),
        );

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_seleccion.grupo.isNotEmpty)
                  Text(
                    _seleccion.grupo,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                Text(
                  _seleccion.etiqueta(auth.isAdmin),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              SelectorSucursal(
                esAdmin: auth.isAdmin,
                compacto: constraints.maxWidth < 420,
                alCambiar: _alCambiarSucursal,
              ),
              BotonIconoSeguro(
                tooltip: 'Actualizar inventario',
                onPressed: () =>
                    context.read<InventarioProvider>().refrescarTodo(),
                icon: const Icon(Icons.refresh),
              ),
              if (!permanente)
                IconButton(
                  tooltip: 'Menú y cuenta',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: permanente ? null : menu(fijo: false),
          body: SafeArea(
            child: Row(
              children: [
                if (permanente) ...[
                  menu(fijo: true),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      // Conserva capturas al cambiar de sección y no inicia
                      // peticiones de páginas que el usuario no ha abierto.
                      child: IndexedStack(
                        index: destinos.indexOf(_seleccion),
                        children: [
                          for (final destino in destinos)
                            TickerMode(
                              key: ValueKey(destino),
                              enabled: destino == _seleccion,
                              child: _visitados.contains(destino)
                                  ? _pagina(destino, auth.isAdmin)
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
