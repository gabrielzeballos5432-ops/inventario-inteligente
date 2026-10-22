import '../../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final historial = inventario.historial;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El titulo de la pestana ya lo muestra la AppBar.
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => inventario.cargarHistorial(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (inventario.cargando && historial.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (historial.isEmpty)
          const SectionCard(child: Text('Aun no hay movimientos registrados.'))
        else
          ...historial.map(
            (m) {
              final esEntrada = m.tipo == 'entrada';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  // Antes cada movimiento ocupaba cinco lineas (tipo,
                  // cantidad, stock, origen y fecha). Con una sola fila cabe
                  // el doble de movimientos en la misma pantalla.
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (esEntrada ? context.paleta.positivo : context.paleta.negativo)
                              .withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          esEntrada ? Icons.south_west : Icons.north_east,
                          size: 17,
                          color: esEntrada ? context.paleta.positivo : context.paleta.negativo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.productoNombre ?? 'Producto #${m.productoId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${esEntrada ? 'Entrada' : 'Salida'} de ${m.cantidad} '
                              '· stock ${m.stockResultante}'
                              '${m.origen != null ? ' · ${m.origen}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textoSecundario,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (m.creadoEn != null) ...[
                        SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM HH:mm')
                              .format(DateTime.parse(m.creadoEn!).toLocal()),
                          style: TextStyle(
                            color: context.textoTerciario,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
