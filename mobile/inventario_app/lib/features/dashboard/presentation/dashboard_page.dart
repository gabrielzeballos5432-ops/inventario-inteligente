import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../app/destino_app.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<DestinoApp> onNavegar;

  const DashboardPage({super.key, required this.onNavegar});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<InventarioProvider>();
      provider.cargarInventario();
      provider.cargarValorizacion();
    });
  }

  String _bs(double? valor) =>
      valor == null ? '—' : 'Bs ${valor.toStringAsFixed(2)}';

  String _saludo() {
    final hora = TimeOfDay.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final inventario = context.watch<InventarioProvider>();
    final productos = inventario.productos;
    final stockBajo = productos.where((p) => p.stockBajo).toList()
      ..sort(
        (a, b) => (a.stockActual - a.stockMinimo).compareTo(
          b.stockActual - b.stockMinimo,
        ),
      );
    final valorizacion = inventario.valorizacion;
    final utilidadPotencial = valorizacion == null
        ? null
        : valorizacion.valorizadoVenta - valorizacion.valorizadoCosto;
    final nombre = auth.usuario?.nombre.trim().split(' ').first ?? 'equipo';

    return RefreshIndicator(
      onRefresh: inventario.refrescarTodo,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _Bienvenida(
            saludo: _saludo(),
            nombre: nombre.isEmpty ? 'equipo' : nombre,
          ),
          const SizedBox(height: 18),
          _AccesoVenta(onTap: () => widget.onNavegar(DestinoApp.ventas)),
          const SizedBox(height: 22),
          Text(
            'Accesos rápidos',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnas = constraints.maxWidth >= 640 ? 3 : 1;
              final ancho =
                  (constraints.maxWidth - (columnas - 1) * 10) / columnas;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AccesoRapido(
                    ancho: ancho,
                    icono: Icons.point_of_sale_outlined,
                    titulo: 'Registrar venta',
                    detalle: 'Cobra en efectivo o QR',
                    tono: Theme.of(context).colorScheme.primary,
                    onTap: () => widget.onNavegar(DestinoApp.ventas),
                  ),
                  _AccesoRapido(
                    ancho: ancho,
                    icono: Icons.inventory_2_outlined,
                    titulo: 'Ver productos',
                    detalle: 'Consulta y organiza el stock',
                    tono: context.paleta.info,
                    onTap: () => widget.onNavegar(DestinoApp.productos),
                  ),
                  _AccesoRapido(
                    ancho: ancho,
                    icono: Icons.auto_awesome_outlined,
                    titulo: 'Contar productos',
                    detalle: 'Usa una foto para detectar',
                    tono: context.paleta.aviso,
                    onTap: () => widget.onNavegar(DestinoApp.deteccion),
                  ),
                  _AccesoRapido(
                    ancho: ancho,
                    icono: Icons.point_of_sale_outlined,
                    titulo: 'Control de caja',
                    detalle: 'Abre, consulta o cierra tu caja',
                    tono: context.paleta.positivo,
                    onTap: () => widget.onNavegar(DestinoApp.caja),
                  ),
                  if (context.watch<AuthProvider>().isAdmin)
                    _AccesoRapido(
                      ancho: ancho,
                      icono: Icons.account_balance_outlined,
                      titulo: 'Registrar compra',
                      detalle: 'Recibe productos del proveedor',
                      tono: context.paleta.info,
                      onTap: () => widget.onNavegar(DestinoApp.compras),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resumen de inventario',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar inventario',
                onPressed: inventario.cargando
                    ? null
                    : () {
                        inventario.cargarInventario();
                        inventario.cargarValorizacion();
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (inventario.cargando && productos.isEmpty)
            const _CargandoInventario()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columnas = constraints.maxWidth >= 850 ? 3 : 2;
                final metricas = <Widget>[
                  _MetricaTarjeta(
                    icono: Icons.inventory_2_outlined,
                    etiqueta: 'Productos activos',
                    valor:
                        '${valorizacion?.productosActivos ?? productos.length}',
                    tono: context.paleta.info,
                  ),
                  _MetricaTarjeta(
                    icono: Icons.warning_amber_rounded,
                    etiqueta: 'Por reponer',
                    valor: '${stockBajo.length}',
                    tono: stockBajo.isEmpty
                        ? context.paleta.positivo
                        : context.paleta.stockBajo,
                  ),
                  _MetricaTarjeta(
                    icono: Icons.layers_outlined,
                    etiqueta: 'Unidades disponibles',
                    valor: valorizacion == null
                        ? '—'
                        : '${valorizacion.unidadesTotales}',
                    tono: context.paleta.aviso,
                  ),
                  if (auth.isAdmin) ...[
                    _MetricaTarjeta(
                      icono: Icons.account_balance_wallet_outlined,
                      etiqueta: 'Inventario a costo',
                      valor: _bs(valorizacion?.valorizadoCosto),
                      tono: context.textoPrimario,
                    ),
                    _MetricaTarjeta(
                      icono: Icons.sell_outlined,
                      etiqueta: 'Inventario a precio de venta',
                      valor: _bs(valorizacion?.valorizadoVenta),
                      tono: context.paleta.positivo,
                    ),
                    _MetricaTarjeta(
                      icono: Icons.trending_up,
                      etiqueta: 'Margen potencial',
                      valor: _bs(utilidadPotencial),
                      tono: context.paleta.info,
                    ),
                  ],
                ];
                return GridView.count(
                  crossAxisCount: columnas,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: constraints.maxWidth < 380 ? 1.05 : 1.45,
                  children: metricas,
                );
              },
            ),
          if (auth.isAdmin && valorizacion != null) ...[
            const SizedBox(height: 8),
            Text(
              'Margen potencial estimado del inventario; no representa ventas '
              'ni utilidad realizada.',
              style: TextStyle(color: context.textoSecundario, fontSize: 12),
            ),
          ],
          if (inventario.error != null) ...[
            const SizedBox(height: 14),
            _AvisoError(
              mensaje: inventario.error!,
              onReintentar: inventario.cargarInventario,
            ),
          ],
          const SizedBox(height: 24),
          _AlertasStock(
            productos: stockBajo,
            onVerProductos: () => widget.onNavegar(DestinoApp.productos),
          ),
        ],
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  final String saludo;
  final String nombre;

  const _Bienvenida({required this.saludo, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$saludo, $nombre',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí tienes lo importante de tu salón hoy.',
          style: TextStyle(color: context.textoSecundario),
        ),
      ],
    );
  }
}

class _AccesoVenta extends StatelessWidget {
  final VoidCallback onTap;

  const _AccesoVenta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.primary,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atiende a tu próximo cliente',
                      style: TextStyle(
                        color: colores.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Registra una venta en pocos pasos.',
                      style: TextStyle(
                        color: colores.onPrimary.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: onTap,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Nueva venta'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.point_of_sale_outlined,
                size: 52,
                color: colores.onPrimary.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccesoRapido extends StatelessWidget {
  final double ancho;
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color tono;
  final VoidCallback onTap;

  const _AccesoRapido({
    required this.ancho,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.tono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Material(
        color: context.superficie,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: context.colorBorde),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tono.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icono, color: tono, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detalle,
                        style: TextStyle(
                          color: context.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.textoTerciario),
              ],
            ),
          ),
        ),
      ),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.textoSecundario),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tono,
            ),
          ),
        ],
      ),
    );
  }
}

class _CargandoInventario extends StatelessWidget {
  const _CargandoInventario();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _AvisoError({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.paleta.negativo),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje)),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _AlertasStock extends StatelessWidget {
  final List<ProductoConStock> productos;
  final VoidCallback onVerProductos;

  const _AlertasStock({required this.productos, required this.onVerProductos});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productos por reponer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (productos.isNotEmpty)
                TextButton(
                  onPressed: onVerProductos,
                  child: const Text('Ver inventario'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (productos.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: context.paleta.positivo,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Todo bien: no hay productos bajo el mínimo.'),
                ),
              ],
            )
          else
            ...productos
                .take(5)
                .map(
                  (producto) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: context.paleta.stockBajo,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            producto.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${producto.stockActual} / ${producto.stockMinimo}',
                          style: TextStyle(
                            color: context.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          if (productos.length > 5) ...[
            const SizedBox(height: 4),
            Text(
              'Y ${productos.length - 5} productos más necesitan atención.',
              style: TextStyle(color: context.textoSecundario, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
