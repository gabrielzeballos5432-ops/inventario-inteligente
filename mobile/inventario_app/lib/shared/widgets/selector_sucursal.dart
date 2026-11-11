import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/sucursal_controller.dart';

/// Sucursal activa en la barra superior.
///
/// El administrador la cambia desde aquí (menú desplegable); el vendedor solo
/// la ve, porque siempre opera en la predeterminada de Configuración.
class SelectorSucursal extends StatelessWidget {
  const SelectorSucursal({
    super.key,
    required this.esAdmin,
    required this.alCambiar,
    this.compacto = false,
  });

  final bool esAdmin;

  /// Se llama después de cambiar de sucursal, para recargar lo que depende
  /// de ella (inventario, historial, valorización).
  final VoidCallback alCambiar;

  /// En pantallas angostas muestra solo el icono; el nombre va en el tooltip.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final control = context.watch<SucursalController>();
    final activa = control.activa;
    if (activa == null) return const SizedBox.shrink();

    final etiqueta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.storefront_outlined, size: 20),
        if (!compacto) ...[
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              activa.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (esAdmin && control.sucursales.length > 1)
          const Icon(Icons.arrow_drop_down, size: 20),
      ],
    );

    if (!esAdmin || control.sucursales.length < 2) {
      return Tooltip(
        message: esAdmin
            ? 'Sucursal: ${activa.nombre}'
            : 'Sucursal: ${activa.nombre} (la define el administrador)',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: etiqueta,
        ),
      );
    }

    return PopupMenuButton<int>(
      tooltip: 'Cambiar sucursal (actual: ${activa.nombre})',
      initialValue: activa.id,
      onSelected: (id) async {
        final cambio = await control.seleccionar(id);
        if (!cambio || !context.mounted) return;
        alCambiar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ahora trabajas en ${control.activa?.nombre}')),
        );
      },
      itemBuilder: (context) => [
        for (final sucursal in control.sucursales)
          PopupMenuItem(
            value: sucursal.id,
            child: Row(
              children: [
                Icon(
                  sucursal.id == activa.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(sucursal.nombre)),
                if (sucursal.predeterminada)
                  Text(
                    'Predeterminada',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: etiqueta,
      ),
    );
  }
}
