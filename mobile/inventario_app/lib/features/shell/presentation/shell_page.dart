import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/providers/theme_controller.dart';
import '../../../shared/widgets/menu_lateral.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../deteccion/presentation/detection_page.dart';
import '../../historial/presentation/history_page.dart';
import '../../productos/presentation/products_page.dart';
import '../../usuarios/presentation/users_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Solo celular (Android/iOS nativo) tiene camara; laptop y web usan archivo.
  bool get _esDispositivoMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  List<_ShellTab> _buildTabs() {
    final auth = context.read<AuthProvider>();
    final tabs = <_ShellTab>[
      const _ShellTab(
        title: 'Zoomventory',
        page: DashboardPage(),
        destination: NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Panel',
        ),
      ),
      const _ShellTab(
        title: 'Productos',
        page: ProductsPage(),
        destination: NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Productos',
        ),
      ),
      _ShellTab(
        title: 'Deteccion',
        page: const DetectionPage(),
        destination: NavigationDestination(
          icon: Icon(_esDispositivoMovil
              ? Icons.photo_camera_back_outlined
              : Icons.image_search_outlined),
          label: 'Deteccion',
        ),
      ),
      const _ShellTab(
        title: 'Historial',
        page: HistoryPage(),
        destination: NavigationDestination(
          icon: Icon(Icons.history),
          label: 'Historial',
        ),
      ),
    ];

    // Usuarios se movio a la seccion Gestion del sidebar (junto a los
    // catalogos): un solo hogar para la administracion, sin tab propio.
    return tabs;
  }

  /// Etiqueta del rol, para el sidebar.
  String _rol(AuthProvider auth) =>
      auth.isAdmin ? 'Administrador' : 'Vendedor';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Se lee fuera del builder del drawer: dentro, context.watch queda fuera
    // del arbol y salta "Tried to listen... from outside of the widget tree".
    final esNoche = context.watch<ThemeController>().esNoche;
    final tabs = _buildTabs();
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    final inicial = (auth.usuario?.nombre.trim().isNotEmpty ?? false)
        ? auth.usuario!.nombre.trim()[0].toUpperCase()
        : 'Z';

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(tabs[_currentIndex].title),
        // Con el drawer montado la hamburguesa sale sola a la izquierda; los
        // ajustes de cuenta (tema, servidor, sesion) migraron al sidebar.
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: () => context.read<InventarioProvider>().refrescarTodo(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _AvatarBoton(
              inicial: inicial,
              alPresionar: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: MenuLateral(
        elementos: tabs.map((tab) => tab.destination).toList(),
        seleccion: _currentIndex,
        usuarioNombre: auth.usuario?.nombre ?? 'Invitado',
        rol: _rol(auth),
        esNoche: esNoche,
        mostrarGestion: auth.isAdmin,
        alNavegar: (indice) => setState(() => _currentIndex = indice),
        alAlternarTema: () => context.read<ThemeController>().alternar(),
        alConfigurarServidor: () => mostrarDialogoServidor(context),
        alCerrarSesion: () => auth.logout(),
        // Los catalogos se citan con el contexto del shell (ruta raiz): si
        // colgaran del drawer, el dialogo moriria al cerrarse el menu.
        alAbrirCatalogo: (cual) => abrirCatalogoDesdeMenu(context, cual),
        alAbrirUsuarios: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UsersPage()),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs.map((tab) => tab.page).toList(),
        ),
      ),
    );
  }
}

/// Boton avatar de la app bar: reemplaza al menu de tres puntos. Al tocarlo
/// abre el mismo sidebar, donde vive la cuenta completa.
class _AvatarBoton extends StatelessWidget {
  final String inicial;
  final VoidCallback alPresionar;

  const _AvatarBoton({required this.inicial, required this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPresionar,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: Text(
              inicial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTab {
  final String title;
  final Widget page;
  final NavigationDestination destination;

  const _ShellTab({
    required this.title,
    required this.page,
    required this.destination,
  });
}
