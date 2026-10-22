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

  String _bs(double? valor) =>
      valor == null ? '-' : 'Bs. ${valor.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final productos = inventario.productos;
    final stockBajo = productos.where((p) => p.stockBajo).toList();
    final valorizacion = inventario.valorizacion;
    final utilidad = valorizacion == null
        ? null
        : valorizacion.valorizadoVenta - valorizacion.valorizadoCosto;

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
          // Las cifras clave en una grilla de tarjetas: antes eran filas
          // planas y la pantalla se leia como una tabla de consola.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _MetricaTarjeta(
                icono: Icons.inventory_2_outlined,
                etiqueta: 'Productos',
                valor: '${productos.length}',
                tono: context.paleta.info,
              ),
              _MetricaTarjeta(
                icono: Icons.warning_amber,
                etiqueta: 'Stock bajo',
                valor: stockBajo.isEmpty ? '0' : '${stockBajo.length}',
                tono: stockBajo.isEmpty
                    ? context.paleta.positivo
                    : context.paleta.stockBajo,
              ),
              _MetricaTarjeta(
                icono: Icons.sell_outlined,
                etiqueta: 'Valorizado (costo)',
                valor: _bs(valorizacion?.valorizadoCosto),
                tono: context.textoPrimario,
              ),
              _MetricaTarjeta(
                icono: Icons.paid_outlined,
                etiqueta: 'Valorizado (venta)',
                valor: _bs(valorizacion?.valorizadoVenta),
                tono: context.paleta.positivo,
              ),
              _MetricaTarjeta(
                icono: Icons.layers_outlined,
                etiqueta: 'Unidades en stock',
                valor: valorizacion == null
                    ? '-'
                    : '${valorizacion.unidadesTotales}',
                tono: context.paleta.aviso,
              ),
              _MetricaTarjeta(
                icono: Icons.trending_up,
                etiqueta: 'Utilidad potencial',
                valor: _bs(utilidad),
                tono: context.paleta.info,
              ),
            ],
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

class _MetricaTarjeta extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color tono;

  const _MetricaTarjeta({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.tono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.superficie,
        border: Border.all(color: context.colorBorde),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tono.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icono, size: 19, color: tono),
          ),
          const Spacer(),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 12.5, color: context.textoSecundario),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: tono,
            ),
          ),
        ],
      ),
    );
  }
}
