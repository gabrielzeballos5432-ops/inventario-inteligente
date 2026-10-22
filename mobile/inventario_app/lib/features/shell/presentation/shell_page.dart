import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/providers/theme_controller.dart';
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

    if (auth.isAdmin) {
      tabs.add(
        const _ShellTab(
          title: 'Usuarios',
          page: UsersPage(),
          destination: NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Usuarios',
          ),
        ),
      );
    }

    return tabs;
  }

  /// Etiqueta del rol, para el menu de usuario.
  String _rol(AuthProvider auth) =>
      auth.isAdmin ? 'Administrador' : 'Vendedor';

  void _accionDelMenu(BuildContext context, AuthProvider auth, String opcion) {
    switch (opcion) {
      case 'servidor':
        mostrarDialogoServidor(context);
      case 'tema':
        context.read<ThemeController>().alternar();
      case 'cerrar':
        auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Se lee fuera del itemBuilder: dentro del PopupMenu, context.watch queda
    // fuera del arbol y salta "Tried to listen... from outside of the widget tree".
    final esNoche = context.watch<ThemeController>().esNoche;
    final tabs = _buildTabs();
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_currentIndex].title),
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: () => context.read<InventarioProvider>().refrescarTodo(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu de usuario',
            onSelected: (opcion) => _accionDelMenu(context, auth, opcion),
            itemBuilder: (ctx) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        auth.usuario?.nombre ?? 'Invitado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textoPrimario,
                        ),
                      ),
                      Text(
                        _rol(auth),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'tema',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      esNoche ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    ),
                    title: Text(esNoche ? 'Modo claro' : 'Modo noche'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'servidor',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.dns_outlined),
                    title: Text('Configurar servidor'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'cerrar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout),
                    title: Text('Cerrar sesion'),
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs.map((tab) => tab.page).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: tabs.map((tab) => tab.destination).toList(),
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
