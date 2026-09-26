import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/product.dart';
import '../../../core/models/detection_record.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/services/product_service.dart';
import '../../../core/session/session_controller.dart';
import '../../../shared/widgets/section_card.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int _reloadTick = 0;
  final _searchController = TextEditingController();
  int? _filtroCategoria;
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarInventario();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _reloadTick++);
  }

  List<ProductoConStock> _productosFiltrados(List<ProductoConStock> productos) {
    return productos.where((p) {
      final matchTexto = _textoBusqueda.isEmpty ||
          p.nombre.toLowerCase().contains(_textoBusqueda.toLowerCase());
      final matchCategoria = _filtroCategoria == null ||
          p.categoriaId == _filtroCategoria;
      return matchTexto && matchCategoria;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final productos = inventario.productos;
    final isAdmin = SessionController.instance.isAdmin;

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
                    'Productos',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Catalogo de productos con stock actual.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => inventario.cargarInventario(),
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Reportes',
              onPressed: () => _openReportesDialog(context),
            ),
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'Gestionar categorias',
                onPressed: () => _openCategoriasDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Registrar producto',
                onPressed: () => _openProductDialog(context),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _textoBusqueda = v),
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _textoBusqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _textoBusqueda = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Categoria>>(
          future: context.read<InventarioProvider>().productService
              .fetchCategorias(),
          builder: (context, snapshot) {
            final cats = snapshot.data ?? const <Categoria>[];
            return Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtroCategoria == null,
                  onSelected: (_) => setState(() => _filtroCategoria = null),
                ),
                ...cats.map(
                  (c) => ChoiceChip(
                    label: Text(c.nombre),
                    selected: _filtroCategoria == c.id,
                    onSelected: (_) =>
                        setState(() => _filtroCategoria = c.id),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (inventario.cargando && productos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ..._productosFiltrados(productos).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.stockBajo
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stock: ${p.stockActual}',
                            style: TextStyle(
                              color: p.stockBajo
                                  ? Colors.orange
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bs. ${p.precioVenta.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (p.categoria != null)
                      Text(
                        'Categoria: ${p.categoria!.nombre}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    if (p.stockBajo)
                      Text(
                        'Stock minimo: ${p.stockMinimo}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
if (isAdmin) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openMovimientoDialog(
                              context,
                              p,
                            ),
                            icon: const Icon(Icons.swap_vert, size: 18),
                            label: const Text('Movimiento'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openProductDialog(
                              context,
                              product: p,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openStockMinimoDialog(
                              context,
                              p,
                            ),
                            icon: const Icon(Icons.notifications_outlined,
                                size: 18),
                            label: Text('Min: ${p.stockMinimo}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _confirmarBaja(context, p),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Dar de baja'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
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
    );
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    Product? product,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ProductFormDialog(
        service: context.read<InventarioProvider>().productService,
        product: product,
      ),
    );
    if (saved == true) {
      _refresh();
      context.read<InventarioProvider>().cargarInventario();
    }
  }

  Future<void> _openStockMinimoDialog(
      BuildContext context, Product product) async {
    final controller =
        TextEditingController(text: '${product.stockMinimo}');
    final nuevo = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar stock minimo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Stock minimo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text) ?? 0),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
if (nuevo != null) {
      await context
          .read<InventarioProvider>()
          .actualizarStockMinimo(product.id, nuevo);
      _refresh();
    }
  }

  Future<void> _openMovimientoDialog(
      BuildContext context, ProductoConStock product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _MovimientoDialog(product: product),
    );
    if (ok == true) {
      _refresh();
      context.read<InventarioProvider>().cargarInventario();
    }
  }

  Future<void> _confirmarBaja(BuildContext context, Product product) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar de baja producto'),
        content: Text('Se dara de baja "${product.nombre}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await context
          .read<InventarioProvider>()
          .desactivarProducto(product.id);
      _refresh();
    }
  }

Future<void> _openCategoriasDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => _CategoriasDialog(service: context.read<InventarioProvider>().productService),
    );
    _refresh();
  }

  Future<void> _openReportesDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => _ReportesDialog(
        service: context.read<InventarioProvider>().productService,
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final ProductService service;
  final Product? product;

  const _ProductFormDialog({required this.service, this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _precioCompraController;
  late final TextEditingController _precioVentaController;
  late final TextEditingController _stockMinimoController;
  int? _categoriaId;
  bool _saving = false;
  String? _error;
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraController = TextEditingController(
        text: p != null ? p.precioCompra.toStringAsFixed(2) : '');
    _precioVentaController = TextEditingController(
        text: p != null ? p.precioVenta.toStringAsFixed(2) : '');
    _stockMinimoController =
        TextEditingController(text: p != null ? '${p.stockMinimo}' : '5');
    _categoriaId = p?.categoriaId;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'nombre': _nombreController.text.trim(),
      'descripcion': _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      'precio_compra':
          double.tryParse(_precioCompraController.text.replaceAll(',', '.')) ??
              0,
      'precio_venta':
          double.tryParse(_precioVentaController.text.replaceAll(',', '.')) ??
              0,
      'stock_minimo': int.tryParse(_stockMinimoController.text) ?? 5,
      'categoria_id': _categoriaId,
    };

    final ok = _isEditing
        ? await context
            .read<InventarioProvider>()
            .actualizarProducto(widget.product!.id, payload)
        : await context
            .read<InventarioProvider>()
            .crearProducto(payload);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el producto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar producto' : 'Registrar producto'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _precioCompraController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio compra (Bs.)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _precioVentaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio venta (Bs.)'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Stock minimo'),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Categoria>>(
                  future: widget.service.fetchCategorias(),
                  builder: (context, snapshot) {
                    final categorias =
                        snapshot.data ?? const <Categoria>[];
                    return DropdownButtonFormField<int?>(
                      value: _categoriaId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin categoria'),
                        ),
                        ...categorias.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _categoriaId = v),
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined),
          label: Text(_saving
              ? 'Guardando...'
              : (_isEditing ? 'Actualizar' : 'Registrar')),
        ),
      ],
    );
  }
}

class _CategoriasDialog extends StatefulWidget {
  final ProductService service;
  const _CategoriasDialog({required this.service});

  @override
  State<_CategoriasDialog> createState() => _CategoriasDialogState();
}

class _CategoriasDialogState extends State<_CategoriasDialog> {
  late Future<List<Categoria>> _future;
  final _nombreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchCategorias();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.service.fetchCategorias();
    });
  }

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) return;
    await widget.service.createCategoria({'nombre': nombre});
    _nombreController.clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar categorias'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nombreController,
                    decoration:
                        const InputDecoration(labelText: 'Nueva categoria'),
                  ),
                ),
                IconButton(
                  onPressed: _crear,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Categoria>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final cats = snapshot.data ?? const <Categoria>[];
                if (cats.isEmpty) {
                  return const Text('No hay categorias.');
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: cats
                        .map((c) => ListTile(
                              dense: true,
                              title: Text(c.nombre),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  // Nota: la baja de categorias via API esta disponible;
                                  // se mantiene simple mostrando el nombre.
                                },
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _MovimientoDialog extends StatefulWidget {
  final ProductoConStock product;
  const _MovimientoDialog({required this.product});

  @override
  State<_MovimientoDialog> createState() => _MovimientoDialogState();
}

class _MovimientoDialogState extends State<_MovimientoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  String _tipo = 'entrada';
  bool _saving = false;
  String? _error;
  bool get _esAjuste => _tipo == 'ajuste';

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    final ok = await context
        .read<InventarioProvider>()
        .registrarMovimiento(
          productoId: widget.product.id,
          tipo: _tipo,
          cantidad: cantidad,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = 'No se pudo registrar el movimiento';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return AlertDialog(
      title: const Text('Registrar movimiento'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.nombre,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Stock actual: ${p.stockActual}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'entrada',
                    label: Text('Entrada'),
                    icon: Icon(Icons.login),
                  ),
                  ButtonSegment(
                    value: 'salida',
                    label: Text('Salida'),
                    icon: Icon(Icons.logout),
                  ),
                  ButtonSegment(
                    value: 'ajuste',
                    label: Text('Ajuste'),
                    icon: Icon(Icons.tune),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _esAjuste
                      ? 'Nuevo stock (ajuste)'
                      : 'Cantidad',
                  helperText: _esAjuste
                      ? 'Establece el stock exacto del producto'
                      : null,
                ),
                validator: (v) {
                  final val = int.tryParse(v ?? '');
                  if (val == null || val <= 0) {
                    return 'Ingresa un valor mayor a 0';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _guardar,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : 'Registrar'),
        ),
      ],
    );
  }
}

class _ReportesDialog extends StatefulWidget {
  final ProductService service;
  const _ReportesDialog({required this.service});

  @override
  State<_ReportesDialog> createState() => _ReportesDialogState();
}

class _ReportesDialogState extends State<_ReportesDialog> {
  late Future<List<ProductoConStock>> _futureStock;
  late Future<List<Movimiento>> _futureMovs;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _futureStock = widget.service.reporteStock();
    _futureMovs = widget.service.reporteMovimientos();
  }

  void _reload() {
    setState(() {
      _futureStock = widget.service.reporteStock();
      _futureMovs = widget.service.reporteMovimientos();
    });
  }

  Future<void> _exportarStock() async {
    final csv = await widget.service.exportarStock();
    _mostrarMensaje('Reporte de stock exportado (CSV).');
  }

  Future<void> _exportarMovimientos() async {
    final csv = await widget.service.exportarMovimientos();
    _mostrarMensaje('Reporte de movimientos exportado (CSV).');
  }

  void _mostrarMensaje(String msg) {
    if (!mounted) return;
    setState(() => _mensaje = msg);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportes'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Stock actual',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Exportar CSV',
                  onPressed: _exportarStock,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reload,
                ),
              ],
            ),
            FutureBuilder<List<ProductoConStock>>(
              future: _futureStock,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <ProductoConStock>[];
                if (items.isEmpty) return const Text('Sin datos.');
                return Flexible(
                  child: SizedBox(
                    height: 160,
                    child: ListView(
                      shrinkWrap: true,
                      children: items
                          .map((p) => ListTile(
                                dense: true,
                                title: Text(p.nombre),
                                subtitle: Text(
                                    'Stock: ${p.stockActual} (min ${p.stockMinimo})'),
                                trailing: Text(
                                  p.stockBajo ? 'BAJO' : 'NORMAL',
                                  style: TextStyle(
                                    color: p.stockBajo
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            Row(
              children: [
                const Text('Movimientos',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Exportar CSV',
                  onPressed: _exportarMovimientos,
                ),
              ],
            ),
            FutureBuilder<List<Movimiento>>(
              future: _futureMovs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Movimiento>[];
                if (items.isEmpty) return const Text('Sin movimientos.');
                return Flexible(
                  child: SizedBox(
                    height: 160,
                    child: ListView(
                      shrinkWrap: true,
                      children: items
                          .map((m) => ListTile(
                                dense: true,
                                title: Text(
                                    '${m.productoNombre ?? "P#${m.productoId}"}'),
                                subtitle: Text(
                                    '${m.tipo} x${m.cantidad} -> ${m.stockResultante}'),
                                trailing: Text(m.origen ?? ''),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            if (_mensaje != null) ...[
              const SizedBox(height: 8),
              Text(_mensaje!,
                  style: const TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
