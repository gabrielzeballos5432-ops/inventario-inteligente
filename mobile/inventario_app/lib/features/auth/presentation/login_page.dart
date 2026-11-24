import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/server_config_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@zoom.com');
  final _passwordController = TextEditingController(text: 'Admin12345');
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthProvider>().login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final esNoche = context.paleta.fondo == AppPaleta.oscuro.fondo;
    final degradado = esNoche
        ? const [Color(0xFF07131C), Color(0xFF10304A)]
        : const [Color(0xFF2E1065), AppColors.morado];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: degradado,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Acceso al sistema',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Inicia sesión para gestionar inventario y detecciones.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                errorMaxLines: 2,
                              ),
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validaciones.correo,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Contrasena',
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorMaxLines: 2,
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _showPassword = !_showPassword),
                                  icon: Icon(_showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                ),
                              ),
                              validator: (v) => v != null && v.length >= 4
                                  ? null
                                  : 'La contraseña debe tener al menos 4 caracteres',
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: auth.status == AuthStatus.loading ? null : _submit,
                                icon: auth.status == AuthStatus.loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.login),
                                label: Text(
                                  auth.status == AuthStatus.loading
                                      ? 'Ingresando...'
                                      : 'Iniciar sesión',
                                ),
                              ),
                            ),
                            if (auth.errorMsg != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                auth.errorMsg!,
                                style: TextStyle(color: context.paleta.negativo),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => mostrarDialogoServidor(context),
                                icon: const Icon(Icons.dns_outlined, size: 18),
                                label: const Text('Configurar servidor'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
