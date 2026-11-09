import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/product.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/services/operaciones_service.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';

/// Registro rapido de ventas pensado para teclado.
///
/// Tab avanza entre campos; Enter registra la venta incluyendo la captura
/// pendiente. Agregar acumula productos y Esc limpia la captura actual.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key, this.activa = true});

  /// La pagina vive dentro de un IndexedStack: cuando pasa a ser la visible
  /// se enfoca el campo Codigo para empezar a escribir sin tocar nada.
  final bool activa;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  static final _formatoDinero = RegExp(r'^\d*([.,]\d{0,2})?$');

  final _codigoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _montoController = TextEditingController();
  final _efectivoController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _codigoFocus = FocusNode();
  final _cantidadFocus = FocusNode();
  final _montoFocus = FocusNode();

  final List<_ItemVenta> _items = [];
  bool _montoEditado = false;
  String? _errorCaptura;
  String _tipoVenta = 'minorista';
  int? _clienteId;
  bool _pagoEfectivo = true;
  bool _pagoQr = false;
  bool _guardando = false;
  String? _claveIdempotencia;

  bool _cargandoVentas = true;
  List<Map<String, dynamic>> _ventas = [];
  List<Map<String, dynamic>> _clientes = [];
  String? _errorVentas;
  String? _errorClientes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventarioProvider>().cargarInventario();
      _cargarOpcionesVenta();
      _cargarVentas();
      if (widget.activa) _codigoFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant SalesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enfocar(_codigoFocus, _codigoController);
      });
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _cantidadController.dispose();
    _montoController.dispose();
    _efectivoController.dispose();
    _referenciaController.dispose();
    _codigoFocus.dispose();
    _cantidadFocus.dispose();
    _montoFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dinero en centavos: evita los errores de redondeo de double.
  // ---------------------------------------------------------------------------

  static int? _aCentavos(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    final partes = limpio.split('.');
    if (partes.length > 2) return null;
    final entero = int.tryParse(partes.first.isEmpty ? '0' : partes.first);
    final fraccion = partes.length == 1
        ? 0
        : int.tryParse(partes[1].isEmpty ? '0' : partes[1].padRight(2, '0'));
    if (entero == null || fraccion == null) return null;
    return entero * 100 + fraccion;
  }

  static String _bs(int centavos) =>
      '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

  static int _deDouble(double valor) => (valor * 100).round();

  int get _totalCentavos =>
      _items.fold(0, (total, item) => total + item.totalCentavos);

  // ---------------------------------------------------------------------------
  // Captura del producto
  // ---------------------------------------------------------------------------

  /// Busca por el codigo propio de la tienda (sku); si no hay coincidencia,
  /// prueba con el codigo de barras para que tambien funcione un lector.
  ProductoConStock? _productoActual() {
    final codigo = _codigoController.text.trim().toLowerCase();
    if (codigo.isEmpty) return null;
    final productos = context.read<InventarioProvider>().productos;
    for (final p in productos) {
      if (p.activo && p.sku?.trim().toLowerCase() == codigo) return p;
    }
    for (final p in productos) {
      if (p.activo && p.codigoBarras?.trim().toLowerCase() == codigo) return p;
    }
    return null;
  }

  int _precioListaCentavos(Product producto) {
    final precio = _tipoVenta == 'mayorista' && producto.precioMayor != null
        ? producto.precioMayor!
        : producto.precioVenta;
    return _deDouble(precio);
  }

  int _unidadesEnVenta(int productoId) => _items
      .where((item) => item.producto.id == productoId)
      .fold(0, (total, item) => total + item.cantidad);

  /// Mientras el usuario no escriba el monto a mano, se mantiene en
  /// cantidad x precio de lista.
  void _recalcularMonto() {
    if (_montoEditado) return;
    final producto = _productoActual();
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    _montoController.text = producto == null || cantidad <= 0
        ? ''
        : _bs(_precioListaCentavos(producto) * cantidad);
  }

  void _alCambiarCodigo(String _) {
    setState(() {
      _errorCaptura = null;
      _montoEditado = false;
      _recalcularMonto();
    });
  }

  void _enfocar(FocusNode nodo, TextEditingController controller) {
    nodo.requestFocus();
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  /// Valida la captura y la pasa a la lista de productos de la venta.
  bool _agregarItem() {
    final producto = _productoActual();
    String? error;
    FocusNode? foco;
    TextEditingController? campo;
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    final monto = _aCentavos(_montoController.text);
    if (producto == null) {
      error = _codigoController.text.trim().isEmpty
          ? 'Escribe el código del producto.'
          : 'No existe un producto con ese código.';
      foco = _codigoFocus;
      campo = _codigoController;
    } else if (cantidad <= 0) {
      error = 'La cantidad debe ser mayor a 0.';
      foco = _cantidadFocus;
      campo = _cantidadController;
    } else if (cantidad >
        producto.stockActual - _unidadesEnVenta(producto.id)) {
      final disponible = producto.stockActual - _unidadesEnVenta(producto.id);
      error = 'No hay stock suficiente: disponible $disponible.';
      foco = _cantidadFocus;
      campo = _cantidadController;
    } else if (monto == null) {
      error = 'Escribe el monto total de este producto.';
      foco = _montoFocus;
      campo = _montoController;
    }
    if (error != null) {
      setState(() => _errorCaptura = error);
      _enfocar(foco!, campo!);
      return false;
    }
    setState(() {
      _items.add(
        _ItemVenta(
          producto: producto!,
          cantidad: cantidad,
          totalCentavos: monto!,
        ),
      );
      _limpiarCaptura();
      _cambio();
    });
    _codigoFocus.requestFocus();
    return true;
  }

  void _limpiarCaptura() {
    _codigoController.clear();
    _cantidadController.text = '1';
    _montoController.clear();
    _montoEditado = false;
    _errorCaptura = null;
  }

  void _cambio() => _claveIdempotencia = null;

  void _quitarItem(_ItemVenta item) {
    setState(() {
      _items.remove(item);
      _cambio();
    });
    _codigoFocus.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Registro
  // ---------------------------------------------------------------------------

  /// Arma los pagos o devuelve el motivo por el que no se puede.
  (List<Map<String, dynamic>>, String?) _armarPagos(int total) {
    if (total == 0) return (const [], null);
    if (!_pagoEfectivo && !_pagoQr) {
      return (const [], 'Marca si el pago es en efectivo, QR o ambos.');
    }
    final referencia = _referenciaController.text.trim();
    Map<String, dynamic> qr(int monto) => {
      'metodo_pago': 'qr',
      'monto': _bs(monto),
      if (referencia.isNotEmpty) 'referencia': referencia,
    };
    if (_pagoEfectivo && _pagoQr) {
      final efectivo = _aCentavos(_efectivoController.text);
      if (efectivo == null || efectivo <= 0 || efectivo >= total) {
        return (
          const [],
          'En un pago mixto, el efectivo debe ser mayor a 0 y menor al total '
              '(Bs ${_bs(total)}).',
        );
      }
      return (
        [
          {'metodo_pago': 'efectivo', 'monto': _bs(efectivo)},
          qr(total - efectivo),
        ],
        null,
      );
    }
    if (_pagoQr) return ([qr(total)], null);
    return (
      [
        {'metodo_pago': 'efectivo', 'monto': _bs(total)},
      ],
      null,
    );
  }

  Future<void> _registrar() async {
    // Guardia sincronica: un segundo Enter o doble clic mientras se guarda no
    // dispara otra peticion (el boton deshabilitado no frena el teclado).
    if (_guardando) return;
    if (_codigoController.text.trim().isNotEmpty) {
      if (!_agregarItem()) return;
    }
    if (_items.isEmpty) {
      _mostrarMensaje('Agrega al menos un producto a la venta.');
      _codigoFocus.requestFocus();
      return;
    }
    final total = _totalCentavos;
    final (pagos, errorPago) = _armarPagos(total);
    if (errorPago != null) {
      _mostrarMensaje(errorPago);
      return;
    }

    final detalles = [
      for (final item in _items)
        {
          'producto_id': item.producto.id,
          'cantidad': item.cantidad,
          'precio_unitario_negociado': _bs(item.precioUnitarioCentavos),
          'total_linea': _bs(item.totalCentavos),
          if (item.promocion) 'tipo_promocion': item.tipoPromocion,
        },
    ];

    setState(() => _guardando = true);
    try {
      await context.read<InventarioProvider>().registrarVenta({
        'tipo_venta': _tipoVenta,
        if (_clienteId != null) 'cliente_id': _clienteId,
        'clave_idempotencia': _claveIdempotencia ??= DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        'detalles': detalles,
        'pagos': pagos,
      });
      if (!mounted) return;
      _mostrarMensaje('Venta registrada por Bs ${_bs(total)}.');
      _limpiarTodo();
      unawaited(_cargarVentas());
    } on ApiException catch (error) {
      if (mounted) _mostrarMensaje(error.detalle);
    } on TimeoutException {
      if (mounted) {
        _mostrarMensaje('La solicitud tardó demasiado. Revisa la conexión.');
      }
    } on http.ClientException {
      if (mounted) _mostrarMensaje('No hay conexión con el servidor.');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
        _codigoFocus.requestFocus();
      }
    }
  }

  /// Deja la pagina como recien abierta para que no quede nada que se pueda
  /// volver a registrar por error.
  void _limpiarTodo() {
    setState(() {
      _items.clear();
      _limpiarCaptura();
      _efectivoController.clear();
      _referenciaController.clear();
      _pagoEfectivo = true;
      _pagoQr = false;
      _clienteId = null;
      _tipoVenta = 'minorista';
      _claveIdempotencia = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Datos auxiliares
  // ---------------------------------------------------------------------------

  Future<void> _cargarOpcionesVenta() async {
    try {
      final clientes = await context
          .read<OperacionesService>()
          .listarClientes();
      if (mounted) setState(() => _clientes = clientes);
    } catch (error) {
      if (mounted) setState(() => _errorClientes = _detalleError(error));
    }
  }

  Future<void> _cargarVentas() async {
    setState(() {
      _cargandoVentas = true;
      _errorVentas = null;
    });
    try {
      final ventas = await context.read<OperacionesService>().listarVentas();
      if (mounted) {
        setState(() {
          _ventas = ventas;
          _cargandoVentas = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorVentas = _detalleError(error);
          _cargandoVentas = false;
        });
      }
    }
  }

  Future<void> _anularVenta(Map<String, dynamic> venta) async {
    final motivo = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Anular venta #${venta['id']}'),
        content: TextField(
          controller: motivo,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 250,
          decoration: const InputDecoration(
            labelText: 'Motivo (mínimo 3 caracteres)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () {
              if (motivo.text.trim().length < 3) {
                _mostrarMensaje('Escribe un motivo de al menos 3 caracteres.');
                return;
              }
              Navigator.pop(context, motivo.text.trim());
            },
            child: const Text('Confirmar anulación'),
          ),
        ],
      ),
    );
    motivo.dispose();
    if (texto == null || !mounted) return;
    try {
      await context.read<OperacionesService>().anularVenta(
        venta['id'] as int,
        texto,
      );
      if (!mounted) return;
      await context.read<InventarioProvider>().cargarInventario();
      await _cargarVentas();
    } catch (error) {
      if (mounted) _mostrarMensaje(_detalleError(error));
    }
  }

  String _detalleError(Object error) {
    if (error is ApiException) return error.detalle;
    return error.toString();
  }

  String _fechaVenta(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (fecha == null) return 'Fecha no disponible';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year} · '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _dineroVenta(dynamic valor) =>
      (valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0)
          .toStringAsFixed(2);

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final esAdmin = context.watch<AuthProvider>().isAdmin;
    final producto = _productoActual();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _registrar,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            _registrar,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          setState(_limpiarCaptura);
          _codigoFocus.requestFocus();
        },
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 760;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              Focus(
                canRequestFocus: false,
                onKeyEvent: (_, evento) {
                  if (!widget.activa) return KeyEventResult.ignored;
                  if (evento.logicalKey == LogicalKeyboardKey.enter ||
                      evento.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    if (evento is KeyDownEvent) unawaited(_registrar());
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _encabezado(),
                    if (inventario.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        inventario.error!,
                        style: TextStyle(color: context.paleta.aviso),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _seccionProducto(producto, ancho),
                    const SizedBox(height: 12),
                    _seccionCantidad(producto, ancho),
                    const SizedBox(height: 12),
                    _seccionItems(),
                    const SizedBox(height: 12),
                    _seccionPago(ancho),
                    const SizedBox(height: 12),
                    _barraRegistro(ancho),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ..._historial(esAdmin),
            ],
          );
        },
      ),
    );
  }

  Widget _encabezado() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          'Registrar venta',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        // Tipo de venta en un selector corto: no merece una fila completa.
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            minimumSize: WidgetStatePropertyAll(Size(0, 40)),
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
          ),
          segments: const [
            ButtonSegment(value: 'minorista', label: Text('Minorista')),
            ButtonSegment(value: 'mayorista', label: Text('Mayorista')),
          ],
          selected: {_tipoVenta},
          onSelectionChanged: (seleccion) => setState(() {
            _tipoVenta = seleccion.first;
            _recalcularMonto();
            _cambio();
          }),
        ),
      ],
    );
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, size: 20, color: context.textoSecundario),
          const SizedBox(width: 8),
          Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Campo de solo lectura: no recibe foco (Tab lo salta) y tiene un fondo
  /// distinto al de los campos editables.
  Widget _lectura(String etiqueta, String valor, {Color? color}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: context.paleta.fondo,
        suffixIcon: Icon(
          Icons.lock_outline,
          size: 16,
          color: context.paleta.textoTerciario,
        ),
      ),
      child: Text(
        valor.isEmpty ? '—' : valor,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _seccionProducto(ProductoConStock? producto, bool ancho) {
    final codigo = TextField(
      controller: _codigoController,
      focusNode: _codigoFocus,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Código',
        prefixIcon: Icon(Icons.qr_code_2),
      ),
      onChanged: _alCambiarCodigo,
      onEditingComplete: () {},
      onSubmitted: (_) => _registrar(),
    );
    final descripcion = _lectura(
      'Descripción',
      producto == null
          ? ''
          : [
              producto.nombre,
              if ((producto.descripcion ?? '').trim().isNotEmpty)
                producto.descripcion!.trim(),
            ].join(' · '),
    );
    final publico = _lectura(
      'P. público',
      producto == null ? '' : 'Bs ${producto.precioVenta.toStringAsFixed(2)}',
    );
    final mayor = _lectura(
      'P. mayor',
      producto?.precioMayor == null
          ? ''
          : 'Bs ${producto!.precioMayor!.toStringAsFixed(2)}',
    );
    final saldo = _lectura(
      'Saldo',
      producto == null
          ? ''
          : '${producto.stockActual - _unidadesEnVenta(producto.id)}',
      color: producto != null && producto.stockBajo
          ? context.paleta.stockBajo
          : null,
    );

    final noEncontrado =
        producto == null && _codigoController.text.trim().isNotEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion('Producto', Icons.search),
          if (ancho)
            Row(
              children: [
                Expanded(flex: 3, child: codigo),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: descripcion),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: publico),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: mayor),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: saldo),
              ],
            )
          else ...[
            codigo,
            const SizedBox(height: 12),
            descripcion,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: publico),
                const SizedBox(width: 8),
                Expanded(child: mayor),
                const SizedBox(width: 8),
                Expanded(child: saldo),
              ],
            ),
          ],
          if (noEncontrado) ...[
            const SizedBox(height: 8),
            Text(
              'No existe un producto activo con el código '
              '"${_codigoController.text.trim()}".',
              style: TextStyle(color: context.paleta.negativo),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionCantidad(ProductoConStock? producto, bool ancho) {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    final monto = _aCentavos(_montoController.text);
    final unitario = cantidad > 0 && monto != null
        ? 'P. unitario: Bs ${_bs((monto / cantidad).round())}'
        : null;

    final campoCantidad = TextField(
      controller: _cantidadController,
      focusNode: _cantidadFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Cantidad'),
      onChanged: (_) => setState(() {
        _errorCaptura = null;
        _recalcularMonto();
      }),
      onEditingComplete: () {},
      onSubmitted: (_) => _registrar(),
    );
    final campoMonto = TextField(
      controller: _montoController,
      focusNode: _montoFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        TextInputFormatter.withFunction(
          (anterior, nuevo) =>
              _formatoDinero.hasMatch(nuevo.text) ? nuevo : anterior,
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Monto total (Bs)',
        helperText: unitario,
        suffixIcon: _montoEditado && producto != null
            ? IconButton(
                tooltip: 'Volver al precio de lista',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => setState(() {
                  _montoEditado = false;
                  _recalcularMonto();
                }),
              )
            : null,
      ),
      onChanged: (_) => setState(() {
        _montoEditado = true;
        _errorCaptura = null;
      }),
      onEditingComplete: () {},
      onSubmitted: (_) => _registrar(),
    );
    final botonAgregar = FilledButton.tonalIcon(
      onPressed: _agregarItem,
      icon: const Icon(Icons.add_shopping_cart),
      label: const Text('Agregar'),
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion('Cantidad y monto', Icons.calculate_outlined),
          if (ancho)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: campoCantidad),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: campoMonto),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(height: 56, child: botonAgregar),
                ),
              ],
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: campoCantidad),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: campoMonto),
              ],
            ),
            const SizedBox(height: 12),
            botonAgregar,
          ],
          if (_errorCaptura != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorCaptura!,
              style: TextStyle(color: context.paleta.negativo),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccionItems() {
    final unidades = _items.fold(0, (total, item) => total + item.cantidad);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
            'Productos de la venta (${_items.length})',
            Icons.receipt_long_outlined,
          ),
          // La misma tabla en web y en movil: por debajo de 560 px se juntan
          // codigo, nombre y precio unitario en una celda para no tener que
          // desplazarse de lado.
          LayoutBuilder(
            builder: (context, restricciones) =>
                _tablaItems(compacta: restricciones.maxWidth < 560),
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$unidades ${unidades == 1 ? 'unidad' : 'unidades'} · '
              'Subtotal Bs ${_bs(_totalCentavos)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: context.textoSecundario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tablaItems({required bool compacta}) {
    final paleta = context.paleta;
    final relleno = EdgeInsets.symmetric(
      horizontal: compacta ? 6 : 10,
      vertical: compacta ? 4 : 6,
    );
    final estiloCabecera = TextStyle(
      color: context.textoSecundario,
      fontWeight: FontWeight.w700,
      fontSize: compacta ? 12 : 13,
    );

    Widget celda(Widget hijo, {bool derecha = false}) => TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: relleno,
        child: Align(
          alignment: derecha ? Alignment.centerRight : Alignment.centerLeft,
          child: hijo,
        ),
      ),
    );
    Widget cabecera(String texto, {bool derecha = false}) =>
        celda(Text(texto, style: estiloCabecera), derecha: derecha);
    Widget numero(String texto, {bool fuerte = false}) => celda(
      Text(
        texto,
        style: TextStyle(
          fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      derecha: true,
    );
    Widget checkboxPromo(_ItemVenta item) => Checkbox(
      value: item.promocion,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: (valor) => setState(() {
        item.promocion = valor ?? false;
        _cambio();
      }),
    );
    Widget quitar(_ItemVenta item) => IconButton(
      tooltip: 'Quitar producto',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.close, color: paleta.negativo, size: 20),
      onPressed: () => _quitarItem(item),
    );

    final cabeceras = compacta
        ? [
            cabecera('Producto'),
            cabecera('Cant.', derecha: true),
            cabecera('Total', derecha: true),
            cabecera('Promo'),
            const SizedBox.shrink(),
          ]
        : [
            cabecera('Código'),
            cabecera('Producto'),
            cabecera('Cant.', derecha: true),
            cabecera('P. unit.', derecha: true),
            cabecera('Total', derecha: true),
            cabecera('Promoción'),
            const SizedBox.shrink(),
          ];

    final columnas = compacta
        ? const <int, TableColumnWidth>{
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: FixedColumnWidth(48),
            4: FixedColumnWidth(40),
          }
        : const <int, TableColumnWidth>{
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(5),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(3.5),
            6: FixedColumnWidth(48),
          };

    final filas = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: paleta.superficieElevada),
        children: cabeceras,
      ),
    ];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      // Filas alternadas para seguir la fila con la vista en tablas largas.
      final fondo = i.isOdd
          ? BoxDecoration(
              color: paleta.superficieElevada.withValues(alpha: 0.4),
            )
          : null;
      if (compacta) {
        filas.add(
          TableRow(
            decoration: fondo,
            children: [
              celda(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${item.producto.sku ?? 'Sin código'} · '
                      'P.u. ${_bs(item.precioUnitarioCentavos)}',
                      style: TextStyle(
                        color: context.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                    if (item.promocion) _selectorPromocion(item, chico: true),
                  ],
                ),
              ),
              numero('${item.cantidad}'),
              numero(_bs(item.totalCentavos), fuerte: true),
              celda(checkboxPromo(item)),
              celda(quitar(item)),
            ],
          ),
        );
      } else {
        filas.add(
          TableRow(
            decoration: fondo,
            children: [
              celda(Text(item.producto.sku ?? '—')),
              celda(
                Text(
                  item.producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              numero('${item.cantidad}'),
              numero(_bs(item.precioUnitarioCentavos)),
              numero(_bs(item.totalCentavos), fuerte: true),
              celda(
                Row(
                  children: [
                    checkboxPromo(item),
                    const SizedBox(width: 4),
                    if (item.promocion)
                      Expanded(child: _selectorPromocion(item))
                    else
                      Text(
                        'No',
                        style: TextStyle(color: context.textoSecundario),
                      ),
                  ],
                ),
              ),
              celda(quitar(item)),
            ],
          ),
        );
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: paleta.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Table(
            columnWidths: columnas,
            border: TableBorder(
              horizontalInside: BorderSide(color: paleta.borde),
            ),
            children: filas,
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Escribe un código. Usa Agregar para acumular productos '
                'o Enter para registrar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textoSecundario),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectorPromocion(_ItemVenta item, {bool chico = false}) {
    return DropdownButton<String>(
      value: item.tipoPromocion,
      isDense: true,
      isExpanded: !chico,
      underline: const SizedBox.shrink(),
      style: chico
          ? Theme.of(context).textTheme.bodySmall
          : Theme.of(context).textTheme.bodyMedium,
      items: const [
        DropdownMenuItem(value: 'oferta', child: Text('Oferta')),
        DropdownMenuItem(value: 'combo', child: Text('Combo')),
        DropdownMenuItem(value: 'liquidacion', child: Text('Liquidación')),
      ],
      onChanged: (valor) => setState(() {
        if (valor != null) item.tipoPromocion = valor;
        _cambio();
      }),
    );
  }

  Widget _checkPago(String etiqueta, bool valor, ValueChanged<bool> cambiar) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => cambiar(!valor),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: valor, onChanged: (v) => cambiar(v ?? false)),
            Text(etiqueta, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _seccionPago(bool ancho) {
    final total = _totalCentavos;
    final efectivo = _aCentavos(_efectivoController.text) ?? 0;
    final mixto = _pagoEfectivo && _pagoQr;

    final cliente = DropdownButtonFormField<int?>(
      initialValue: _clienteId,
      key: ValueKey(_clienteId == null ? 'sin-cliente' : 'cliente'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Cliente (opcional)',
        errorText: _errorClientes == null
            ? null
            : 'No se cargaron los clientes',
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Venta sin cliente'),
        ),
        ..._clientes.map(
          (c) => DropdownMenuItem<int?>(
            value: c['id'] as int,
            child: Text(c['nombre'] as String, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (valor) => setState(() {
        _clienteId = valor;
        _cambio();
      }),
    );

    final checks = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _checkPago(
          'Efectivo',
          _pagoEfectivo,
          (v) => setState(() {
            _pagoEfectivo = v;
            _cambio();
          }),
        ),
        _checkPago(
          'QR',
          _pagoQr,
          (v) => setState(() {
            _pagoQr = v;
            _cambio();
          }),
        ),
      ],
    );

    final campoEfectivo = TextField(
      controller: _efectivoController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        TextInputFormatter.withFunction(
          (anterior, nuevo) =>
              _formatoDinero.hasMatch(nuevo.text) ? nuevo : anterior,
        ),
      ],
      decoration: const InputDecoration(labelText: 'Monto en efectivo (Bs)'),
      onChanged: (_) => setState(_cambio),
      onSubmitted: (_) => _registrar(),
    );
    final campoReferencia = TextField(
      controller: _referenciaController,
      maxLength: 100,
      decoration: const InputDecoration(
        labelText: 'Referencia QR (opcional)',
        counterText: '',
      ),
      onChanged: (_) => _cambio(),
      onSubmitted: (_) => _registrar(),
    );

    final camposPago = <Widget>[
      if (mixto) ...[
        campoEfectivo,
        _lectura(
          'Monto por QR',
          total - efectivo > 0 ? 'Bs ${_bs(total - efectivo)}' : '',
        ),
      ],
      if (_pagoQr) campoReferencia,
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion('Pago', Icons.payments_outlined),
          if (ancho)
            Row(
              children: [
                Expanded(flex: 3, child: checks),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: cliente),
              ],
            )
          else ...[
            checks,
            const SizedBox(height: 8),
            cliente,
          ],
          if (camposPago.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (ancho)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < camposPago.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: camposPago[i]),
                  ],
                ],
              )
            else
              for (var i = 0; i < camposPago.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                camposPago[i],
              ],
          ],
        ],
      ),
    );
  }

  Widget _barraRegistro(bool ancho) {
    final total = Text(
      'Total: Bs ${_bs(_totalCentavos)}',
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
    final limpiar = OutlinedButton.icon(
      onPressed: _guardando
          ? null
          : () {
              _limpiarTodo();
              _codigoFocus.requestFocus();
            },
      icon: const Icon(Icons.cleaning_services_outlined),
      label: const Text('Limpiar'),
    );
    final registrar = BotonSeguro(
      onPressed:
          _guardando ||
              (_items.isEmpty && _codigoController.text.trim().isEmpty)
          ? null
          : _registrar,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.point_of_sale),
      child: Text(_guardando ? 'Registrando…' : 'Registrar venta'),
    );
    final ayuda = Text(
      'Tab avanza entre campos · Enter registra · Esc limpia la captura',
      style: TextStyle(color: context.textoSecundario, fontSize: 13),
    );

    return SectionCard(
      child: ancho
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [total, const SizedBox(height: 4), ayuda],
                  ),
                ),
                limpiar,
                const SizedBox(width: 12),
                registrar,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                total,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: limpiar),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: registrar),
                  ],
                ),
              ],
            ),
    );
  }

  List<Widget> _historial(bool esAdmin) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Ventas recientes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar ventas',
            onPressed: _cargandoVentas ? null : _cargarVentas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_cargandoVentas)
        const Center(child: CircularProgressIndicator())
      else if (_errorVentas != null)
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No se pudo cargar el historial: $_errorVentas'),
              TextButton(
                onPressed: _cargarVentas,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        )
      else if (_ventas.isEmpty)
        const SectionCard(child: Text('Aún no hay ventas registradas.'))
      else
        ..._ventas.map(
          (venta) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Venta #${venta['id']} · '
                          '${venta['tipo_venta'] == 'mayorista' ? 'Mayorista' : 'Minorista'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Bs ${_dineroVenta(venta['total'])}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_fechaVenta(venta['fecha_creacion'])} · '
                    '${venta['estado'] == 'anulada' ? 'Anulada' : 'Completada'}',
                    style: TextStyle(color: context.textoSecundario),
                  ),
                  if (venta['motivo_anulacion'] != null)
                    Text('Motivo: ${venta['motivo_anulacion']}'),
                  if (esAdmin && venta['estado'] == 'completada')
                    Align(
                      alignment: Alignment.centerRight,
                      child: BotonSeguro(
                        variante: VarianteBoton.text,
                        onPressed: () => _anularVenta(venta),
                        icon: const Icon(Icons.undo),
                        child: const Text('Anular venta'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}

class _ItemVenta {
  _ItemVenta({
    required this.producto,
    required this.cantidad,
    required this.totalCentavos,
  });

  final ProductoConStock producto;
  final int cantidad;
  final int totalCentavos;
  bool promocion = false;
  String tipoPromocion = 'oferta';

  /// El monto de la linea manda; el precio unitario es el que lo explica,
  /// redondeado a centavos.
  int get precioUnitarioCentavos => (totalCentavos / cantidad).round();
}
