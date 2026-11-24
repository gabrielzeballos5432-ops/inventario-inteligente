import '../../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/product.dart';
import '../../../core/models/detection_record.dart';
import '../../../core/models/marca.dart';
import '../../../core/models/proveedor.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/providers/sucursal_controller.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/descarga_reporte.dart'
    if (dart.library.io) '../../../core/utils/descarga_reporte_io.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/section_card.dart';
import 'barcode_scanner_page.dart';
import 'movimiento_dialog.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../../core/utils/mensaje_error.dart';
import '../../../core/utils/formato_numero.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int _reloadTick = 0;
  final _searchController = TextEditingController();
  int? _filtroCategoria;
  /// Los filtros de categoria solo se muestran mientras hay texto de busqueda.
  bool _filtrosAbiertos = false;
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
    final query = _textoBusqueda.trim().toLowerCase();
    return productos.where((p) {
      // El buscador filtra por nombre y tambien por codigo de barras, de
      // forma que un escaneo con la camara encuentre el producto sin tener que
      // escribir su nombre ni la etiqueta.
      final matchTexto = query.isEmpty ||
          p.nombre.toLowerCase().contains(query) ||
          (p.sku != null && p.sku!.toLowerCase().contains(query)) ||
          (p.codigoBarras != null &&
              p.codigoBarras!.toLowerCase().contains(query));
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
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Acciones con etiqueta en vez de iconos desnudos: cada chip es
            // mas alto, se entiende sin tooltip y caben dos filas en el
            // telefono sin cortarse.
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isAdmin)
                    _AccionChip(
                      icono: Icons.add_box_outlined,
                      texto: 'Producto',
                      destacado: true,
                      alPresionar: () => _openProductDialog(context),
                    ),
                  _AccionChip(
                    icono: Icons.playlist_add,
                    texto: 'Movimiento',
                    alPresionar: () => _openLoteDialog(context),
                  ),
                  _AccionChip(
                    icono: Icons.qr_code_scanner,
                    texto: 'Escanear',
                    alPresionar: _escanearCodigo,
                  ),
                  _AccionChip(
                    icono: Icons.description_outlined,
                    texto: 'Reportes',
                    alPresionar: () => _openReportesDialog(context),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => inventario.cargarInventario(),
            ),
            // La gestion de catalogos (categorias/marcas/proveedores) se
            // mudo al sidebar (seccion Gestion): aqui duplicaba el menu de
            // tres puntos.
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() {
            _textoBusqueda = v;
            // Los filtros solo interesan cuando hay algo que filtrar: se
            // despliegan al escribir y se ocultan al vaciar el buscador.
            if (v.trim().isNotEmpty) _filtrosAbiertos = true;
          }),
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _textoBusqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _textoBusqueda = '';
                        _filtroCategoria = null;
                        _filtrosAbiertos = false;
                      });
                    },
                  )
                : null,
          ),
        ),
        if (_filtrosAbiertos) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: FutureBuilder<List<Categoria>>(
              future: context.read<InventarioProvider>().productService
                  .fetchCategorias(),
              builder: (context, snapshot) {
                // Si la peticion falla, FutureBuilder lo guarda en snapshot
                // .error. Sin este caso el error secia "Unhandled Exception"
                // si el widget se desmonta con la peticion en vuelo.
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Icon(Icons.cloud_off,
                          size: 16, color: context.paleta.stockBajo),
                      const SizedBox(width: 8),
                      Text(
                        'No se pudieron cargar las categorías.',
                        style: TextStyle(color: context.paleta.stockBajo, fontSize: 12),
                      ),
                    ],
                  );
                }
                final cats = snapshot.data ?? const <Categoria>[];
                // Carrusel horizontal: con muchas categorias los chips
                // ocupaban varias pantallas y empujaban la lista hacia abajo.
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _filtroCategoria == null,
                      onSelected: (_) =>
                          setState(() => _filtroCategoria = null),
                    ),
                    ...cats.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(c.nombre),
                          selected: _filtroCategoria == c.id,
                          onSelected: (_) =>
                              setState(() => _filtroCategoria = c.id),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (inventario.cargando && productos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columnas = constraints.maxWidth >= 900 ? 2 : 1;
              final ancho = (constraints.maxWidth - (columnas - 1) * 12) /
                  columnas;
              return Wrap(
                spacing: 12,
                children: _productosFiltrados(productos).map(
                  (p) => SizedBox(
                    width: ancho,
                    child: Padding(
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
                        // El menu va en la fila del titulo: antes estaba al
                        // final de la tarjeta y habia que bajar hasta el para
                        // encontrarlo.
                        if (isAdmin)
                          SizedBox(
                            height: 32,
                            child: PopupMenuButton<String>(
                              tooltip: 'Acciones',
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: const Icon(Icons.more_vert),
                              onSelected: (opcion) => _accionProducto(
                                context,
                                p,
                                opcion,
                              ),
                              itemBuilder: (context) =>
                                  _accionesProducto(isActivo: p.activo),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.stockBajo
                                ? context.paleta.stockBajo.withValues(alpha: 0.2)
                                : context.paleta.positivo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Stock: ${p.stockActual}',
                            style: TextStyle(
                              color: p.stockBajo
                                  ? context.paleta.stockBajo
                                  : context.paleta.positivo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      FormatoNumero.bs(p.precioVenta),
                      style: TextStyle(color: context.textoSecundario),
                    ),
                    if (p.categoria != null)
                      Text(
                        'Categoría: ${p.categoria!.nombre}',
                        style: TextStyle(
                          color: context.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    if (p.stockBajo)
                      Text(
                        'Stock mínimo: ${p.stockMinimo}',
                        style: TextStyle(
                          color: context.paleta.stockBajo,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                      ),
                    ),
                  ),
                ).toList(),
              );
            },
          ),
        if (inventario.error != null) ...[
          SizedBox(height: 16),
          _AvisoBanner(
            texto: inventario.error!,
            icono: Icons.cloud_off,
            color: context.paleta.stockBajo,
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
    final formKey = GlobalKey<FormState>();
    final nuevo = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Configurar stock mínimo'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: Validaciones.stockMinimo,
            decoration: const InputDecoration(
              labelText: 'Stock mínimo',
              helperText: '0 desactiva la alerta para este producto',
              helperMaxLines: 2,
              errorMaxLines: 2,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(int.tryParse(controller.text) ?? 0);
            },
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

  /// Recepcion de mercaderia por lote: varios productos del mismo tipo en un
  /// solo guardado. Sale sin fila precargada porque aqui el usuario ya llega
  /// queriendo cargar una lista, no un producto concreto.
  Future<void> _openLoteDialog(BuildContext context) async {
    final ok = await mostrarMovimientoLote(context);
    if (ok != true) return;
    _refresh();
    await context.read<InventarioProvider>().cargarInventario();
  }

  Future<void> _openMovimientoDialog(
      BuildContext context, ProductoConStock product) async {
    final ok = await mostrarMovimientoLote(context, producto: product);
    if (ok != true) return;
    _refresh();
    await context.read<InventarioProvider>().cargarInventario();
    if (!mounted) return;
    await _avisarSiQuedoBajo(context, product);
  }

  /// Alerta de stock minimo tras registrar un movimiento (RF-17 / HU-11).
  ///
  /// Se lee el estado ya recargado por el provider en vez de recalcular el
  /// stock en el cliente: el servidor es quien aplica el movimiento y decide
  /// el stock resultante, y duplicar esa regla aqui acabaria divergiendo.
  Future<void> _avisarSiQuedoBajo(
      BuildContext context, ProductoConStock antes) async {
    final inventario = context.read<InventarioProvider>().productos;
    ProductoConStock? despues;
    for (final p in inventario) {
      if (p.id == antes.id) {
        despues = p;
        break;
      }
    }
    if (despues == null || !despues.stockBajo) return;
    // Dart no promueve despues a no-null porque se asigna dentro del bucle;
    // el ! es seguro porque el return anterior ya lo garantiza.
    final ProductoConStock actual = despues!;

    // Solo se avisa de las operaciones que pueden bajar el stock. Una entrada
    // nunca deja el inventario mas corto.
    final eraBajo = antes.stockBajo;
    final faltante = actual.stockMinimo - actual.stockActual;
    final suggested = faltante > 0 ? faltante : actual.stockMinimo;

    final repone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        icon: Icon(Icons.warning_amber, color: context.paleta.stockBajo, size: 32),
        title: Text(eraBajo ? 'Sigue bajo el mínimo' : 'Stock bajo el mínimo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eraBajo
                  ? '"${actual.nombre}" continua con ${actual.stockActual} '
                      'unidades, por debajo del mínimo de '
                      '${actual.stockMinimo}.'
                  : '"${actual.nombre}" quedo en ${actual.stockActual} '
                      'unidades y su mínimo es ${actual.stockMinimo}.',
              style: const TextStyle(height: 1.4),
            ),
            if (faltante > 0) ...[
              SizedBox(height: 12),
              Text(
                'Faltan $faltante unidades para alcanzar el mínimo.',
                style: TextStyle(
                  color: context.paleta.stockBajo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Entendido'),
          ),
          BotonSeguro(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.add, size: 18),
            child: const Text('Registrar entrada'),
          ),
        ],
      ),
    );

    if (repone != true || !mounted) return;
    // Se abre la entrada con la cantidad que hace falta ya calculada: el
    // aviso sirve para actuar, no solo para informar. `despues` es el producto
    // ya actualizado del inventario, asi que se reutiliza tal cual.
    final ok2 = await mostrarMovimientoLote(
      context,
      producto: actual,
      tipoInicial: 'entrada',
      cantidadInicial: suggested,
    );
    if (ok2 == true && mounted) {
      _refresh();
      await context.read<InventarioProvider>().cargarInventario();
    }
  }

  Future<void> _confirmarBaja(BuildContext context, Product product) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Dar de baja producto'),
        content: Text('Se dara de baja "${product.nombre}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
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

  /// Abre el dialogo de reportes desde el chip de la cabecera.
  Future<void> _openReportesDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => _ReportesDialog(
        service: context.read<InventarioProvider>().productService,
      ),
    );
  }

  /// Acciones del menu de tres rayitas de cada producto.
  void _accionProducto(BuildContext context, ProductoConStock p, String opcion) {
    switch (opcion) {
      case 'movimiento':
        _openMovimientoDialog(context, p);
      case 'editar':
        _openProductDialog(context, product: p);
      case 'stock':
        _openStockMinimoDialog(context, p);
      case 'baja':
        _confirmarBaja(context, p);
    }
  }

  List<PopupMenuEntry<String>> _accionesProducto({required bool isActivo}) {
    return [
      const PopupMenuItem<String>(
        value: 'movimiento',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.swap_vert, size: 20),
          title: Text('Registrar movimiento'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'editar',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined, size: 20),
          title: Text('Editar producto'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'stock',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.notifications_outlined, size: 20),
          title: Text('Configurar stock mínimo'),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'baja',
        enabled: isActivo,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.delete_outline,
            size: 20,
            color: isActivo ? null : context.paleta.textoTerciario,
          ),
          title: Text(
            isActivo ? 'Dar de baja' : 'Producto dado de baja',
            style: TextStyle(color: isActivo ? null : context.paleta.textoTerciario),
          ),
        ),
      ),
    ];
  }

  Future<void> _escanearCodigo() async {
    // BarcodeScannerPage ya se cierra sola al detectar y devuelve el codigo
    // como resultado de la ruta, asi que no hace falta hacer nada en el
    // callback ni cerrar nada aqui.
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(onDetectado: (_) {}),
      ),
    );
    if (codigo == null || !mounted) return;
    setState(() {
      _searchController.text = codigo;
      _textoBusqueda = codigo;
      _filtrosAbiertos = true;
    });
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
  late final CatalogService _catalogService;
  late final Future<List<Categoria>> _futureCategorias;
  late final Future<List<Marca>> _futureMarcas;
  late final Future<List<Proveedor>> _futureProveedores;
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _precioCompraController;
  late final TextEditingController _precioVentaController;
  late final TextEditingController _precioMayorController;
  late final TextEditingController _codigoController;
  late final TextEditingController _stockMinimoController;
  late final TextEditingController _codigoBarrasController;
  // Solo al crear: stock con el que arranca en la sucursal activa.
  final _cantidadInicialController = TextEditingController();
  int? _categoriaId;
  // Marca y proveedor son catalogos OPCIONALES: null significa "sin asignar"
  // y es un valor legitimo, no un campo pendiente.
  int? _marcaId;
  int? _proveedorId;
  bool _saving = false;
  String? _error;
  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _catalogService = CatalogService(ApiClient());
    _futureCategorias = widget.service.fetchCategorias();
    _futureMarcas = _catalogService.fetchMarcas();
    _futureProveedores = _catalogService.fetchProveedores();
    final p = widget.product;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _precioCompraController = TextEditingController(
        text: p != null ? p.precioCompra.toStringAsFixed(2) : '');
    _precioVentaController = TextEditingController(
        text: p != null ? p.precioVenta.toStringAsFixed(2) : '');
    _precioMayorController = TextEditingController(
        text: p?.precioMayor?.toStringAsFixed(2) ?? '');
    _codigoController = TextEditingController(text: p?.sku ?? '');
    _stockMinimoController =
        TextEditingController(text: p != null ? '${p.stockMinimo}' : '5');
    _codigoBarrasController =
        TextEditingController(text: p?.codigoBarras ?? '');
    _categoriaId = p?.categoriaId;
    _marcaId = p?.marcaId;
    _proveedorId = p?.proveedorId;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioCompraController.dispose();
    _precioVentaController.dispose();
    _precioMayorController.dispose();
    _codigoController.dispose();
    _stockMinimoController.dispose();
    _codigoBarrasController.dispose();
    _cantidadInicialController.dispose();
    super.dispose();
  }

  /// Selector de marca. Opcional: "Sin marca" es un valor valido y es el
  /// estado por defecto de un producto nuevo.
  Widget _selectorMarca() {
    return FutureBuilder<List<Marca>>(
      future: _futureMarcas,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Marca (opcional)',
              errorText: 'No se pudieron cargar las marcas',
            ),
            child: Text('Sin conexión'),
          );
        }
        final marcas = snapshot.data ?? const <Marca>[];
        // Mismo guard que la categoria: un valor fuera de la lista hace que
        // DropdownButtonFormField lance un _AssertionError y Flutter pinte un
        // ErrorWidget rojo.
        final ids = marcas.map((m) => m.id).toSet();
        final valorValido = (_marcaId != null && ids.contains(_marcaId)) ? _marcaId : null;
        return DropdownButtonFormField<int?>(
          value: valorValido,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Sin marca')),
            ...marcas.map(
              (m) => DropdownMenuItem<int?>(
                value: m.id,
                child: Text(m.nombre, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _marcaId = v),
          decoration: const InputDecoration(labelText: 'Marca (opcional)'),
        );
      },
    );
  }

  /// Selector de proveedor. Opcional, con el mismo criterio que la marca.
  Widget _selectorProveedor() {
    return FutureBuilder<List<Proveedor>>(
      future: _futureProveedores,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Proveedor (opcional)',
              errorText: 'No se pudieron cargar los proveedores',
            ),
            child: Text('Sin conexión'),
          );
        }
        final proveedores = snapshot.data ?? const <Proveedor>[];
        final ids = proveedores.map((p) => p.id).toSet();
        final valorValido = (_proveedorId != null && ids.contains(_proveedorId))
            ? _proveedorId
            : null;
        return DropdownButtonFormField<int?>(
          value: valorValido,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Sin proveedor')),
            ...proveedores.map(
              (p) => DropdownMenuItem<int?>(
                value: p.id,
                child:
                    Text(p.nombre, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _proveedorId = v),
          decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
        );
      },
    );
  }

  /// Escanea el codigo de barras y lo coloca en el campo. Tercer camino de
  /// alta de producto: cuando la IA no esta disponible, el etiqueta del
  /// envase se registra a mano o escaneandola.
  Future<void> _escanearEnElFormulario() async {
    // El callback NO cierra la pagina: BarcodeScannerPage ya hace
    // Navigator.pop(codigo) al detectar. Si aqui tambien se hiciera pop, se
    // cerrarian dos rutas y el Navigator lanza
    // "debugLocked is not true". El valor vuelve por el await del push.
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(onDetectado: (_) {}),
      ),
    );
    if (codigo == null || !mounted) return;
    setState(() => _codigoBarrasController.text = codigo);
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
      'precio_mayor': double.tryParse(
          _precioMayorController.text.trim().replaceAll(',', '.')),
      // Codigo propio de la tienda (columna sku, UNIQUE): igual que el codigo
      // de barras, vacio se manda como null para no chocar entre productos.
      'sku': _codigoController.text.trim().isEmpty
          ? null
          : _codigoController.text.trim(),
      'stock_minimo': int.tryParse(_stockMinimoController.text) ?? 5,
      'categoria_id': _categoriaId,
      // Marca y proveedor son opcionales: null es "sin asignar". Se mandan
      // tal cual, sin cadena vacia, porque las columnas son claves foraneas.
      'marca_id': _marcaId,
      'proveedor_id': _proveedorId,
      // La columna codigo_barras es UNIQUE en PostgreSQL. Varios productos sin
      // codigo comparten el valor, asi que hay que enviar null y no cadena
      // vacia: "" se repetiria y el segundo alta fallaria con un error de
      // clave duplicada que no explicaria nada al usuario.
      'codigo_barras': _codigoBarrasController.text.trim().isEmpty
          ? null
          : _codigoBarrasController.text.trim(),
      // Al crear: si es > 0 el backend registra una entrada "Stock inicial"
      // en la sucursal activa. Vacio cuenta como 0.
      if (!_isEditing)
        'cantidad_inicial':
            int.tryParse(_cantidadInicialController.text.trim()) ?? 0,
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
    // En telefono el dialogo toma casi todo el ancho disponible (los campos
    // compactos de escritorio lo achatan); en escritorio se limita a 480
    // para que no se estire de mas. Con < 600 de ventana los selectores de
    // marca y proveedor van apilados: en media fila sus textos se cortan.
    final angosto = MediaQuery.of(context).size.width < 600;
    return AlertDialog(
      // Mismo insetPadding que el dialogo de movimiento: el default de 40 a
      // cada lado dejaba el modal angosto y partia los textos largos.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(_isEditing ? 'Editar producto' : 'Registrar producto'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // La etiqueta flotante del primer campo (Codigo) se dibuja por
            // encima del borde del campo. Sin este margen, el recorte del
            // scroll la cortaba al desplazarse y volver arriba.
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _codigoController,
                  textCapitalization: TextCapitalization.characters,
                  // Mismos topes que las columnas: por encima la base
                  // rechazaba el guardado con un error del servidor.
                  maxLength: 50,
                  validator: (v) => (v ?? '').trim().contains(' ')
                      ? 'El código no puede tener espacios'
                      : null,
                  decoration: const InputDecoration(
                    errorMaxLines: 2,
                    labelText: 'Código (opcional)',
                    helperText: 'Código propio de la tienda, se usa en ventas.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreController,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    errorMaxLines: 2,
                  ),
                  validator: Validaciones.nombreProducto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcionController,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripcion'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codigoBarrasController,
                  keyboardType: TextInputType.number,
                  maxLength: 50,
                  validator: (v) => (v ?? '').trim().contains(' ')
                      ? 'El código de barras no puede tener espacios'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Código de barras',
                    helperText: 'Opcional. Escanea la etiqueta para no escribirlo.',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      tooltip: 'Escanear código de barras',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _saving ? null : _escanearEnElFormulario,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  inputFormatters: FormatoNumero.decimal(decimales: 2),
                  controller: _precioCompraController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio compra (Bs.)',
                    errorMaxLines: 2,
                  ),
                  validator: (v) =>
                      Validaciones.precio(v, etiqueta: 'precio de compra'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  inputFormatters: FormatoNumero.decimal(decimales: 2),
                  controller: _precioVentaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio venta (Bs.)',
                    errorMaxLines: 2,
                  ),
                  validator: (v) =>
                      Validaciones.precio(v, etiqueta: 'precio de venta'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  inputFormatters: FormatoNumero.decimal(decimales: 2),
                  controller: _precioMayorController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio por mayor (Bs.) (opcional)',
                    errorMaxLines: 2,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? null
                      : Validaciones.precio(v, etiqueta: 'precio por mayor'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stock mínimo',
                    helperText: 'Se avisa cuando el stock cae por debajo de este valor',
                    errorMaxLines: 2,
                  ),
                  validator: Validaciones.stockMinimo,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cantidadInicialController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Cantidad inicial',
                      hintText: '0',
                      helperText: 'Se registra como entrada en '
                          '${SucursalController.instance.activa?.nombre ?? 'la sucursal activa'}.',
                      helperMaxLines: 2,
                      errorMaxLines: 2,
                    ),
                    validator: Validaciones.cantidadInicial,
                  ),
                ],
                const SizedBox(height: 12),
                FutureBuilder<List<Categoria>>(
                  future: _futureCategorias,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          errorText: 'No se pudieron cargar las categorías',
                        ),
                        child: Text('Sin conexión con el servidor'),
                      );
                    }
                    final categorias =
                        snapshot.data ?? const <Categoria>[];
                    // Si la categoria del producto no esta en la lista
                    // cargada (aun no llego la peticion, o la categoria esta
                    // desactivada), pasar ese valor a DropdownButtonFormField
                    // dispara un _AssertionError y Flutter reemplaza el
                    // widget por un ErrorWidget rojo. Se cae a null para que
                    // muestre "Sin categoria" en vez de romperse.
                    final idsDisponibles =
                        categorias.map((c) => c.id).toSet();
                    final valorValido = (_categoriaId != null &&
                            idsDisponibles.contains(_categoriaId))
                        ? _categoriaId
                        : null;

                    return DropdownButtonFormField<int?>(
                      // Ocupa el ancho del campo: un nombre largo se corta con
                      // … en vez de desbordar la fila en el telefono.
                      isExpanded: true,
                      value: valorValido,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin categoría'),
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
                const SizedBox(height: 12),
                if (angosto) ...[
                  _selectorMarca(),
                  const SizedBox(height: 12),
                  _selectorProveedor(),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _selectorMarca()),
                      const SizedBox(width: 12),
                      Expanded(child: _selectorProveedor()),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: context.paleta.negativo)),
                ],
                const SizedBox(height: 24),
                // Botones a lo ancho con 50 de alto: los actions del dialogo
                // quedan diminutos en el telefono y fuera del alcance del
                // pulgar. Viven dentro del contenido para heredar el ancho
                // real del dialogo en cada dispositivo.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BotonSeguro(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          // Padding 12: con el 24 del tema no cabe la mitad
                          // del dialogo y "Actualizar" se partia en dos.
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          _saving
                              ? 'Guardando...'
                              : (_isEditing ? 'Actualizar' : 'Registrar'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de accion con etiqueta para la barra superior de productos: ocupa el
/// lugar de los IconButton con tooltip (que en el telefono quedaban pequenos
/// y sin decir nada), con 42 dp de alto y texto claro. [destacado] pinta el
/// chip de la accion principal con el morado de marca; los demas van hundidos
/// en la superficie elevada, tono que sale de la paleta del modo activo.
class _AccionChip extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alPresionar;
  final bool destacado;

  const _AccionChip({
    required this.icono,
    required this.texto,
    required this.alPresionar,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: alPresionar,
      icon: Icon(icono, size: 18),
      label: Text(texto),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
        backgroundColor:
            destacado ? Theme.of(context).colorScheme.primary : context.superficieElevada,
        foregroundColor:
            destacado ? Colors.white : context.textoPrimario,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Banda de aviso con icono. Antes el mensaje de error era un bloque de color
/// plano, sin icono ni borde, que se leia como un hueco raro en la pantalla.
class _AvisoBanner extends StatelessWidget {  final String texto;
  final IconData icono;
  final Color color;

  const _AvisoBanner({
    required this.texto,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de error para los listados de los dialogos. Distingue el fallo de
/// red de la lista vacia legitima: mostrar ambas igual hace que un error de
/// conexion se lea como "el servidor no tiene datos".
class _ErrorFila extends StatelessWidget {
  const _ErrorFila({required this.mensaje, this.onReintentar});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off, size: 16, color: context.paleta.stockBajo),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            mensaje,
            style: TextStyle(color: context.paleta.stockBajo, fontSize: 12),
          ),
        ),
        if (onReintentar != null)
          TextButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
      ],
    );
  }
}

class CategoriasPage extends StatefulWidget {
  final ProductService service;
  const CategoriasPage({super.key, required this.service});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
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
    final error = Validaciones.nombreSinNumeros(_nombreController.text);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final nombre = _nombreController.text.trim();
    try {
      await widget.service.createCategoria({'nombre': nombre});
      _nombreController.clear();
      _reload();
    } catch (e) {
      // Sin esto, un fallo de red al crear deja la excepcion sin manejar.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la categoría: ${_motivo(e)}')),
      );
    }
  }

  /// Traduce la excepcion a la frase del backend. Mostrar el JSON crudo
  /// deja al usuario leyendo {"detail":"..."} en vez de la causa.
  static String _motivo(Object e) => mensajeDeError(e);

  /// Renombra una categoria. Es la unica correccion posible sobre una
  /// categoria: el borrado es logico, asi que un nombre mal tecleado se
  /// repara en lugar de quedar guardado asi para siempre.
  Future<void> _editar(Categoria c) async {
    final controller = TextEditingController(text: c.nombre);
    final formKey = GlobalKey<FormState>();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Renombrar categoría'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            validator: Validaciones.nombreSinNumeros,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              errorMaxLines: 2,
            ),
            onFieldSubmitted: (v) {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(v.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(controller.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Se libera en el siguiente frame: tras el pop todavia queda un frame de
    // animacion de salida que referencia el controlador del campo.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (nombre == null || nombre.isEmpty || nombre == c.nombre) return;
    try {
      await widget.service.actualizarCategoria(c.id, nombre: nombre);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo renombrar: ${_motivo(e)}')),
      );
    }
  }

  /// El backend no borra: marca la categoria como inactiva, para que los
  /// productos que ya la referencien no queden con una categoria huerfana.
  Future<void> _desactivar(BuildContext context, Categoria c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Desactivar categoría'),
        content: Text(
          'La categoría "${c.nombre}" dejará de aparecer al registrar o editar '
          'productos. Los productos que ya la usan no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.desactivarCategoria(c.id);
      _reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo desactivar: ${_motivo(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Categoria>>(
      future: _future,
      builder: (context, snapshot) {
        final categorias = snapshot.data ?? const <Categoria>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(child: Text('Administra las categorías del inventario.', style: TextStyle(color: context.textoSecundario))),
              BotonSeguro(onPressed: _abrirCrear, icon: const Icon(Icons.add), child: const Text('Registrar')),
            ]),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              SectionCard(child: Row(children: [
                Icon(Icons.cloud_off, color: context.paleta.stockBajo),
                const SizedBox(width: 10),
                const Expanded(child: Text('No se pudieron cargar las categorías.')),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ]))
            else if (categorias.isEmpty)
              const SectionCard(child: Text('No hay categorías registradas.'))
            else ...[
              SectionCard(child: Text('Total de categorías: ${categorias.length}', style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 12),
              ...categorias.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(child: Row(children: [
                  const Icon(Icons.category_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.nombre)),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (op) { if (op == 'editar') _editar(c); if (op == 'desactivar') _desactivar(context, c); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'desactivar', child: Text('Desactivar')),
                    ],
                  ),
                ])),
              )),
            ],
            const SizedBox(height: 8),
            Text('Desactivar no borra el nombre: al registrar nuevamente una categoría desactivada, se reactiva.', style: TextStyle(color: context.textoTerciario, fontSize: 12)),
          ],
        );
      },
    );
  }

  Future<void> _abrirCrear() async {
    final formKey = GlobalKey<FormState>();
    _nombreController.clear();
    final crear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Registrar categoría'),
        content: Form(key: formKey, child: TextFormField(
          controller: _nombreController,
          autofocus: true,
          maxLength: 100,
          validator: Validaciones.nombreSinNumeros,
          decoration: const InputDecoration(labelText: 'Nombre', errorMaxLines: 2),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          BotonSeguro(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Registrar')),
        ],
      ),
    );
    if (crear == true) await _crear();
  }
}

class _ReportesDialog extends StatefulWidget {
  final ProductService service;
  const _ReportesDialog({required this.service});

  @override
  State<_ReportesDialog> createState() => _ReportesDialogState();
}

class _ReportesDialogState extends State<_ReportesDialog> {
  // Filtro de los reportes: arranca en la sucursal activa; null = todas.
  int? _sucursalId = SucursalController.instance.activaId;
  late Future<List<ProductoConStock>> _futureStock;
  late Future<List<Movimiento>> _futureMovs;
  String? _mensaje;
  // El mensaje de exportacion necesita su propio color: pintado en verde, el
  // fallo No se pudo exportar se leia como si el archivo se hubiera generado.
  bool _mensajeEsError = false;

  @override
  void initState() {
    super.initState();
    _futureStock = widget.service.reporteStock(sucursalId: _sucursalId);
    _futureMovs = widget.service.reporteMovimientos(sucursalId: _sucursalId);
  }

  void _reload() {
    setState(() {
      _futureStock = widget.service.reporteStock(sucursalId: _sucursalId);
      _futureMovs = widget.service.reporteMovimientos(sucursalId: _sucursalId);
    });
  }

  /// Selector de sucursal del reporte. Con una sola sucursal no aporta nada.
  Widget _filtroSucursal() {
    final sucursales = SucursalController.instance.sucursales;
    if (sucursales.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<int?>(
        initialValue: _sucursalId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sucursal'),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Todas las sucursales'),
          ),
          for (final s in sucursales)
            DropdownMenuItem<int?>(value: s.id, child: Text(s.nombre)),
        ],
        onChanged: (id) {
          _sucursalId = id;
          _reload();
        },
      ),
    );
  }

  Future<void> _exportar(
    Future<List<int>> Function() obtenerBytes,
    String nombreBase,
    String formato,
  ) async {
    try {
      final bytes = await obtenerBytes();
      final mimeType = formato == 'xlsx'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv';
      final ruta =
          await descargarReporte(bytes, '$nombreBase.$formato', mimeType);
      _mostrarMensaje(ruta == null
          ? 'Reporte $nombreBase.$formato listo para compartir.'
          : 'Reporte guardado en: $ruta');
    } catch (e) {
      _mostrarMensaje('No se pudo exportar: $e', esError: true);
    }
  }

  Future<void> _exportarStock(String formato) {
    return _exportar(
      () => widget.service.exportarStock(
        formato: formato,
        sucursalId: _sucursalId,
      ),
      'reporte_stock',
      formato,
    );
  }

  Future<void> _exportarMovimientos(String formato) {
    return _exportar(
      () => widget.service.exportarMovimientos(
        formato: formato,
        sucursalId: _sucursalId,
      ),
      'reporte_movimientos',
      formato,
    );
  }

  void _mostrarMensaje(String msg, {bool esError = false}) {
    if (!mounted) return;
    setState(() {
      _mensaje = msg;
      _mensajeEsError = esError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // insetPadding propio, igual que producto y lote: el default de 40 por
      // lado dejaba los dos listados apretados en el telefono.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Reportes'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recargar a la vista, arriba de todo: antes era un tercer icono
            // perdido entre los dos de exportar, y nadie lo asociaba con
            // "refrescar el reporte".
            Align(
              alignment: Alignment.centerRight,
              child: _AccionChip(
                icono: Icons.refresh,
                texto: 'Actualizar',
                alPresionar: _reload,
              ),
            ),
            const SizedBox(height: 8),
            _filtroSucursal(),
            Row(
              children: [
                const Text('Stock actual',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                // Exportar con etiqueta: "CSV" y "Excel" se entienden solos,
                // los dos iconos iguales con tooltip los confundian.
                _AccionChip(
                  icono: Icons.description_outlined,
                  texto: 'CSV',
                  alPresionar: () => _exportarStock('csv'),
                ),
                const SizedBox(width: 4),
                _AccionChip(
                  icono: Icons.table_chart_outlined,
                  texto: 'Excel',
                  alPresionar: () => _exportarStock('xlsx'),
                ),
              ],
            ),
            FutureBuilder<List<ProductoConStock>>(
              future: _futureStock,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Sin este caso el fallo de red se presenta como Sin datos, y
                // en un reporte de inventario eso se lee como que no hay
                // existencias: conclusion falsa a partir de un error.
                if (snapshot.hasError) {
                  return _ErrorFila(
                    mensaje: 'No se pudo cargar el reporte de stock.',
                    onReintentar: _reload,
                  );
                }
                final items = snapshot.data ?? const <ProductoConStock>[];
                if (items.isEmpty) return const Text('Sin datos.');
                return Flexible(
                  child: SizedBox(
                    height: 200,
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
                                        ? context.paleta.stockBajo
                                        : context.paleta.positivo,
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
                _AccionChip(
                  icono: Icons.description_outlined,
                  texto: 'CSV',
                  alPresionar: () => _exportarMovimientos('csv'),
                ),
                const SizedBox(width: 4),
                _AccionChip(
                  icono: Icons.table_chart_outlined,
                  texto: 'Excel',
                  alPresionar: () => _exportarMovimientos('xlsx'),
                ),
              ],
            ),
            FutureBuilder<List<Movimiento>>(
              future: _futureMovs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorFila(
                    mensaje: 'No se pudo cargar el reporte de movimientos.',
                    onReintentar: _reload,
                  );
                }
                final items = snapshot.data ?? const <Movimiento>[];
                if (items.isEmpty) return const Text('Sin movimientos.');
                return Flexible(
                  child: SizedBox(
                    height: 200,
                    child: ListView(
                      shrinkWrap: true,
                      children: items
                          .map((m) => ListTile(
                                dense: true,
                                title: Text(
                                    '${m.productoNombre ?? "P#${m.productoId}"}'),
                                subtitle: Text(
                                    '${m.tipo} x${m.cantidad} -> ${m.stockResultante}'
                                    '${m.razonNombre != null ? ' · ${m.razonNombre}' : ''}'
                                    '${_sucursalId == null && m.sucursalNombre != null ? ' · ${m.sucursalNombre}' : ''}'),
                                trailing: Text(m.origen ?? ''),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            if (_mensaje != null) ...[
              SizedBox(height: 8),
              Text(
                _mensaje!,
                style: TextStyle(
                  color: _mensajeEsError ? context.paleta.stockBajo : context.paleta.positivo,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
