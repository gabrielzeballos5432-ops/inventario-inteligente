import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/servidor_controller.dart';

/// Envuelve toda la app para dos cosas relacionadas con la conexion:
///
/// 1. Al volver del segundo plano (por ejemplo, la laptop desperto de una
///    suspension) comprueba el servidor en el acto, sin esperar al siguiente
///    ciclo del [ServidorController].
/// 2. Muestra una franja de aviso cuando el backend no responde, con un boton
///    para reintentar a mano.
///
/// La franja no se muestra mientras el estado es `comprobando`, asi que al
/// arrancar no parpadea.
class ServidorGuard extends StatefulWidget {
  const ServidorGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ServidorGuard> createState() => _ServidorGuardState();
}

class _ServidorGuardState extends State<ServidorGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ServidorController>().verificar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AvisoSinServidor(),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _AvisoSinServidor extends StatelessWidget {
  const _AvisoSinServidor();

  @override
  Widget build(BuildContext context) {
    final servidor = context.watch<ServidorController>();
    if (servidor.estado != EstadoServidor.desconectado) {
      return const SizedBox.shrink();
    }
    return Material(
      color: context.superficieElevada,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 18, color: context.paleta.negativo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin conexion con el servidor. Se reintenta solo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.paleta.negativo,
                  ),
                ),
              ),
              TextButton(
                onPressed: servidor.verificar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
