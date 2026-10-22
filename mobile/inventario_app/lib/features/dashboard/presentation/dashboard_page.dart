import '../../../app/theme.dart';
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
        if (inventario.cargando && productos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Sin subtitulo: el nombre de la pestana ya esta en la AppBar y
          // una frase descriptiva encima de las cifras soloocupaba alto.
          _MetricRow(
            icon: Icons.inventory_2_outlined,
            label: 'Productos',
            value: '${productos.length}',
          ),
          _MetricRow(
            icon: Icons.warning_amber,
            label: 'Stock bajo',
            value: '${stockBajo.length}',
            color: stockBajo.isEmpty ? null : context.paleta.stockBajo,
          ),
          _MetricRow(
            icon: Icons.sell_outlined,
            label: 'Valorizado (costo)',
            value: valorizacion == null
                ? '-'
                : 'Bs. ${valorizacion.valorizadoCosto.toStringAsFixed(2)}',
          ),
          _MetricRow(
            icon: Icons.paid_outlined,
            label: 'Valorizado (venta)',
            value: valorizacion == null
                ? '-'
                : 'Bs. ${valorizacion.valorizadoVenta.toStringAsFixed(2)}',
          ),
          _MetricRow(
            icon: Icons.layers_outlined,
            label: 'Unidades en stock',
            value: valorizacion == null
                ? '-'
                : '${valorizacion.unidadesTotales}',
          ),
          _MetricRow(
            icon: Icons.trending_up,
            label: 'Utilidad potencial',
            value: valorizacion == null
                ? '-'
                : 'Bs. ${(valorizacion.valorizadoVenta - valorizacion.valorizadoCosto).toStringAsFixed(2)}',
            color: valorizacion == null
                ? null
                : context.paleta.info,
          ),
          if (valorizacion != null) ...[
            SizedBox(height: 8),
            Text(
              '${valorizacion.productosActivos} productos activos, '
              '${valorizacion.unidadesTotales} unidades en total.',
              style: TextStyle(color: context.textoSecundario, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alertas de stock bajo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (stockBajo.isEmpty)
                  const Text('No hay productos con stock bajo.')
                else
                  ...stockBajo.map(
                    (p) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              color: context.paleta.stockBajo, size: 20),
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
            SizedBox(height: 16),
            SectionCard(
              child: Text(
                inventario.error!,
                style: TextStyle(color: context.paleta.stockBajo),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tono = color ?? context.textoPrimario;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? context.textoSecundario),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: context.textoSecundario, fontSize: 14),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: tono,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

