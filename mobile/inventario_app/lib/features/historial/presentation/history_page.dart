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
                  Text(
                    'Historial',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Movimientos de inventario registrados.',
                    style: TextStyle(color: Colors.white70),
                  ),
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
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          m.tipo == 'entrada'
                              ? Icons.login
                              : Icons.logout,
                          color: m.tipo == 'entrada'
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.productoNombre ?? 'Producto #${m.productoId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Tipo: ${m.tipo == 'entrada' ? 'Entrada' : 'Salida'}'),
                    Text('Cantidad: ${m.cantidad}'),
                    Text('Stock resultante: ${m.stockResultante}'),
                    if (m.origen != null) Text('Origen: ${m.origen}'),
                    if (m.creadoEn != null)
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(
                          DateTime.parse(m.creadoEn!).toLocal(),
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
