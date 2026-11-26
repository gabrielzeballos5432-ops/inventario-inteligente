import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/theme_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/shell/presentation/shell_page.dart';
import '../shared/widgets/servidor_guard.dart';
import 'theme.dart';

class InventarioApp extends StatelessWidget {
  const InventarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final modo = context.watch<ThemeController>().modo;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventario Inteligente',
      theme: buildTemaClaro(),
      darkTheme: buildTemaNoche(),
      themeMode: modo,
      // Toda la app esta en castellano: sin esto los textos de Flutter
      // (calendario "Select date", "Cancel", "OK", copiar/pegar) salian en
      // ingles.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          ServidorGuard(child: child ?? const SizedBox.shrink()),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.status == AuthStatus.initial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return auth.isAuthenticated ? const ShellPage() : const LoginPage();
        },
      ),
    );
  }
}