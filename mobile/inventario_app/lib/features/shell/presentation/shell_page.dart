import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
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
        title: 'Dashboard',
        page: DashboardPage(),
        destination: NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
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
      ),      const _ShellTab(
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = _buildTabs();
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_currentIndex].title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                auth.usuario?.nombre ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
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
