import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/movimiento_pendiente.dart';
import '../../core/providers/cola_movimientos_controller.dart';

/// Franja que avisa que hay movimientos guardados en el telefono esperando
/// conexion (o rechazados por el servidor), con acceso a la lista.
///
/// Tambien muestra el aviso de sincronizacion completada (RF-20). No pinta
/// nada si la cola esta vacia o si la app se monto sin cola (tests).
class AvisoMovimientosPendientes extends StatefulWidget {
  const AvisoMovimientosPendientes({super.key});

  @override
  State<AvisoMovimientosPendientes> createState() =>
      _AvisoMovimientosPendientesState();
}

class _AvisoMovimientosPendientesState
    extends State<AvisoMovimientosPendientes> {
  ColaMovimientosController? _cola;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cola = context.read<ColaMovimientosController?>();
    if (!identical(cola, _cola)) {
      _cola?.removeListener(_alCambiar);
      _cola = cola?..addListener(_alCambiar);
    }
  }

  @override
  void dispose() {
    _cola?.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    final aviso = _cola?.tomarAviso();
    if (aviso == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(aviso.mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final cola = context.watch<ColaMovimientosController?>();
    if (cola == null || (cola.pendientes == 0 && cola.rechazados == 0)) {
      return const SizedBox.shrink();
    }
    final hayRechazados = cola.rechazados > 0;
    final color = hayRechazados
        ? context.paleta.negativo
        : context.paleta.stockBajo;
    final texto = [
      if (cola.pendientes > 0)
        '${cola.pendientes} movimiento(s) pendiente(s) de enviar',
      if (hayRechazados) '${cola.rechazados} rechazado(s) por el servidor',
    ].join(' · ');
    return Material(
      color: context.superficieElevada,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Icon(
              hayRechazados ? Icons.error_outline : Icons.cloud_upload_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto, style: TextStyle(fontSize: 12, color: color)),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ChangeNotifierProvider.value(
                  value: cola,
                  child: const MovimientosPendientesDialog(),
                ),
              ),
              child: const Text('Ver'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de movimientos en la cola: que se registro, cuando y, si el
/// servidor lo rechazo, por que.
class MovimientosPendientesDialog extends StatelessWidget {
  const MovimientosPendientesDialog({super.key});

  static String _tipo(String tipo) => switch (tipo) {
    'entrada' => 'Entrada',
    'salida' => 'Salida',
    _ => 'Ajuste',
  };

  static String _fecha(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)} ${dos(f.hour)}:${dos(f.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cola = context.watch<ColaMovimientosController>();
    final movimientos = cola.movimientos;
    return AlertDialog(
      title: const Text('Movimientos pendientes'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se registraron sin conexión y están guardados en este '
                'dispositivo. Se envian solos cuando vuelve el servidor.',
                style: TextStyle(color: context.textoSecundario),
              ),
              const SizedBox(height: 12),
              if (movimientos.isEmpty)
                const Text('No queda ningún movimiento pendiente.'),
              for (final m in movimientos) _fila(context, cola, m),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: cola.sincronizando || cola.pendientes == 0
                          ? null
                          : cola.sincronizar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      child: Text(
                        cola.sincronizando ? 'Enviando...' : 'Enviar ahora',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(
    BuildContext context,
    ColaMovimientosController cola,
    MovimientoPendiente m,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tipo(m.tipo)} · ${m.razonNombre} · ${_fecha(m.creadoEn)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final i in m.items)
                  Text(
                    '${i.cantidad} × ${i.nombre}',
                    style: TextStyle(color: context.textoSecundario),
                  ),
                if (m.rechazado)
                  Text(
                    'Rechazado: ${m.detalle ?? 'sin detalle'}',
                    style: TextStyle(color: context.paleta.negativo),
                  ),
              ],
            ),
          ),
          if (m.rechazado)
            IconButton(
              tooltip: 'Reintentar el envío',
              onPressed: cola.sincronizando
                  ? null
                  : () => cola.reintentar(m.clave),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Descartar este movimiento',
            onPressed: cola.sincronizando
                ? null
                : () => _confirmarDescarte(context, cola, m),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarDescarte(
    BuildContext context,
    ColaMovimientosController cola,
    MovimientoPendiente m,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar movimiento'),
        content: Text(
          'Se borrara de este dispositivo sin enviarse: '
          '${_tipo(m.tipo).toLowerCase()} de ${m.unidades} unidad(es). '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Conservar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmar == true) await cola.descartar(m.clave);
  }
}
