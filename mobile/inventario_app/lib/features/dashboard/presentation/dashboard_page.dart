import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventarioProvider>();
      provider.cargarInventario();
      provider.cargarValorizacion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final productos = inventario.productos;
    final stockBajo = productos.where((p) => p.stockBajo).toList();
    final valorizacion = inventario.valorizacion;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Resumen operativo del sistema de inventario inteligente.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        if (inventario.cargando && productos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _MetricTile(label: 'Productos', value: '${productos.length}'),
              _MetricTile(label: 'Stock bajo', value: '${stockBajo.length}'),
              _MetricTile(
                label: 'Valorizado (costo)',
                value: valorizacion == null
                    ? '-'
                    : 'Bs. ${valorizacion.valorizadoCosto.toStringAsFixed(2)}',
              ),
              _MetricTile(
                label: 'Valorizado (venta)',
                value: valorizacion == null
                    ? '-'
                    : 'Bs. ${valorizacion.valorizadoVenta.toStringAsFixed(2)}',
              ),
            ],
          ),
          if (valorizacion != null) ...[
            const SizedBox(height: 8),
            Text(
              '${valorizacion.productosActivos} productos activos, '
              '${valorizacion.unidadesTotales} unidades en total.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertas de stock bajo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (stockBajo.isEmpty)
                  const Text('No hay productos con stock bajo.')
                else
                  ...stockBajo.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.nombre} - Stock: ${p.stockActual} (min: ${p.stockMinimo})',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (inventario.error != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              child: Text(
                inventario.error!,
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
