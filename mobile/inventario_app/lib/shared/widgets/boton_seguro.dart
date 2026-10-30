import 'dart:async';

import 'package:flutter/material.dart';

enum VarianteBoton { filled, tonal, outlined, text }

/// Boton idempotente: ignora los toques mientras su accion esta en curso.
///
/// Un doble toque accidental sobre "Registrar" no debe crear dos compras ni
/// hacer dos `Navigator.pop` (el segundo cerraria la pagina de abajo). Mientras
/// el `Future` de [onPressed] no termina, el boton queda deshabilitado y
/// muestra un indicador; si la accion es sincrona (por ejemplo cerrar un
/// dialogo) se bloquea igual durante [bloqueoMinimo].
class BotonSeguro extends StatefulWidget {
  const BotonSeguro({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variante = VarianteBoton.filled,
    this.style,
    this.bloqueoMinimo = const Duration(milliseconds: 700),
  });

  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final Widget? icon;
  final VarianteBoton variante;
  final ButtonStyle? style;
  final Duration bloqueoMinimo;

  @override
  State<BotonSeguro> createState() => _BotonSeguroState();
}

/// Logica comun de [BotonSeguro] y [BotonIconoSeguro].
mixin _AccionUnica<T extends StatefulWidget> on State<T> {
  bool ocupado = false;
  Timer? _desbloqueo;

  @override
  void dispose() {
    _desbloqueo?.cancel();
    super.dispose();
  }

  Future<void> ejecutar(
    FutureOr<void> Function()? accion,
    Duration bloqueoMinimo,
  ) async {
    // Guardia sincrona: el segundo toque llega antes del rebuild que
    // deshabilita el boton, asi que no basta con poner onPressed en null.
    if (ocupado || accion == null) return;
    setState(() => ocupado = true);
    final inicio = DateTime.now();
    try {
      await accion();
    } finally {
      final resto = bloqueoMinimo - DateTime.now().difference(inicio);
      void liberar() {
        if (mounted) setState(() => ocupado = false);
      }

      // Timer y no Future.delayed: si el boton se desmonta (el dialogo se
      // cerro) se cancela en dispose en vez de quedar colgado.
      if (resto > Duration.zero) {
        _desbloqueo = Timer(resto, liberar);
      } else {
        liberar();
      }
    }
  }
}

/// Version de [BotonSeguro] para acciones de icono (confirmar, pagar, anular).
class BotonIconoSeguro extends StatefulWidget {
  const BotonIconoSeguro({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.bloqueoMinimo = const Duration(milliseconds: 700),
  });

  final FutureOr<void> Function()? onPressed;
  final Widget icon;
  final String? tooltip;
  final Duration bloqueoMinimo;

  @override
  State<BotonIconoSeguro> createState() => _BotonIconoSeguroState();
}

class _BotonIconoSeguroState extends State<BotonIconoSeguro>
    with _AccionUnica<BotonIconoSeguro> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onPressed == null || ocupado
          ? null
          : () => ejecutar(widget.onPressed, widget.bloqueoMinimo),
      icon: ocupado
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : widget.icon,
    );
  }
}

class _BotonSeguroState extends State<BotonSeguro>
    with _AccionUnica<BotonSeguro> {
  bool get _ocupado => ocupado;

  Future<void> _ejecutar() => ejecutar(widget.onPressed, widget.bloqueoMinimo);

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.onPressed != null && !_ocupado;
    final accion = habilitado ? _ejecutar : null;
    final icono = _ocupado
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : widget.icon;

    if (icono == null) {
      return switch (widget.variante) {
        VarianteBoton.filled => FilledButton(
          onPressed: accion,
          style: widget.style,
          child: widget.child,
        ),
        VarianteBoton.tonal => FilledButton.tonal(
          onPressed: accion,
          style: widget.style,
          child: widget.child,
        ),
        VarianteBoton.outlined => OutlinedButton(
          onPressed: accion,
          style: widget.style,
          child: widget.child,
        ),
        VarianteBoton.text => TextButton(
          onPressed: accion,
          style: widget.style,
          child: widget.child,
        ),
      };
    }
    return switch (widget.variante) {
      VarianteBoton.filled => FilledButton.icon(
        onPressed: accion,
        style: widget.style,
        icon: icono,
        label: widget.child,
      ),
      VarianteBoton.tonal => FilledButton.tonalIcon(
        onPressed: accion,
        style: widget.style,
        icon: icono,
        label: widget.child,
      ),
      VarianteBoton.outlined => OutlinedButton.icon(
        onPressed: accion,
        style: widget.style,
        icon: icono,
        label: widget.child,
      ),
      VarianteBoton.text => TextButton.icon(
        onPressed: accion,
        style: widget.style,
        icon: icono,
        label: widget.child,
      ),
    };
  }
}
