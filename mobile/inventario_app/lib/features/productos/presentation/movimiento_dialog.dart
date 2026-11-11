import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sucursal.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../core/providers/sucursal_controller.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/boton_seguro.dart';

typedef ItemMovimiento = ({int productoId, int cantidad});
typedef GuardarMovimiento =
    Future<int> Function({
      required String tipo,
      required List<ItemMovimiento> items,
      required int razonId,
      int? sucursalDestinoId,
    });

Future<bool?> mostrarMovimientoLote(
  BuildContext context, {
  ProductoConStock? producto,
  String? tipoInicial,
  int? cantidadInicial,
}) {
  final inventario = context.read<InventarioProvider>();
  final sucursales = context.read<SucursalController>();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MovimientoDialog(
      productos: inventario.productos.where((p) => p.activo).toList(),
      enviar: inventario.registrarLote,
      razones: sucursales.razones,
      sucursales: sucursales.sucursales,
      sucursalActualId: sucursales.activaId,
      productoInicial: producto,
      tipoInicial: tipoInicial ?? 'entrada',
      cantidadInicial: cantidadInicial,
    ),
  );
}

class MovimientoDialog extends StatefulWidget {
  const MovimientoDialog({
    super.key,
    required this.productos,
    required this.enviar,
    this.productoInicial,
    this.tipoInicial = 'entrada',
    this.cantidadInicial,
    this.razones = const [],
    this.sucursales = const [],
    this.sucursalActualId,
  });

  final List<ProductoConStock> productos;
  final GuardarMovimiento enviar;

  /// Razones activas elegibles a mano (de todos los tipos); se filtran por el
  /// tipo elegido.
  final List<RazonMovimiento> razones;

  /// Sucursales activas, para elegir el destino de un traspaso.
  final List<Sucursal> sucursales;
  final int? sucursalActualId;
  final ProductoConStock? productoInicial;
  final String tipoInicial;
  final int? cantidadInicial;

  @override
  State<MovimientoDialog> createState() => _MovimientoDialogState();
}

class _FilaMovimiento {
  final buscador = TextEditingController();
  final cantidad = TextEditingController();
  final focoProducto = FocusNode();
  final focoCantidad = FocusNode();
  int? productoId;

  void dispose() {
    buscador.dispose();
    cantidad.dispose();
    focoProducto.dispose();
    focoCantidad.dispose();
  }
}

class _MovimientoDialogState extends State<MovimientoDialog> {
  final _filas = <_FilaMovimiento>[];
  late String _tipo;
  int? _razonId;
  int? _destinoId;
  bool _guardando = false;
  bool _validar = false;
  String? _error;

  String _etiqueta(ProductoConStock producto) =>
      '${producto.sku ?? '#${producto.id}'} · ${producto.nombre}';

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    _razonPorDefecto();
    final fila = _nuevaFila();
    if (widget.productoInicial case final producto?) {
      fila.productoId = producto.id;
      fila.buscador.text = _etiqueta(producto);
      fila.cantidad.text = widget.cantidadInicial?.toString() ?? '';
    }
    _filas.add(fila);
  }

  List<RazonMovimiento> get _razonesTipo => widget.razones
      .where((r) => r.tipoMovimiento == _tipo && r.activo && !r.sistema)
      .toList();

  RazonMovimiento? get _razon {
    for (final razon in _razonesTipo) {
      if (razon.id == _razonId) return razon;
    }
    return null;
  }

  List<Sucursal> get _destinos => widget.sucursales
      .where((s) => s.activo && s.id != widget.sucursalActualId)
      .toList();

  /// Con una sola razón posible (por ejemplo el ajuste) no tiene sentido
  /// obligar a elegirla; con varias hay que elegir a conciencia.
  void _razonPorDefecto() {
    final razones = _razonesTipo;
    _razonId = razones.length == 1 ? razones.first.id : null;
    _destinoId = null;
  }

  String? get _errorRazon {
    final razon = _razon;
    if (razon == null) {
      return _razonesTipo.isEmpty
          ? 'No hay razones activas para este tipo. Créalas en Configuración.'
          : 'Elige la razón del movimiento.';
    }
    if (razon.requiereSucursalDestino &&
        !_destinos.any((s) => s.id == _destinoId)) {
      return _destinos.isEmpty
          ? 'No hay otra sucursal activa a la cual enviar.'
          : 'Elige la sucursal destino.';
    }
    return null;
  }

  _FilaMovimiento _nuevaFila() {
    final fila = _FilaMovimiento();
    fila.cantidad.addListener(_actualizar);
    fila.buscador.addListener(_actualizar);
    return fila;
  }

  void _actualizar() {
    if (!mounted) return;
    // DropdownMenu sincroniza el controlador al construir su selección inicial.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final fila in _filas) {
      fila.dispose();
    }
    super.dispose();
  }

  ProductoConStock? _producto(_FilaMovimiento fila) {
    for (final producto in widget.productos) {
      if (producto.id == fila.productoId &&
          fila.buscador.text == _etiqueta(producto)) {
        return producto;
      }
    }
    return null;
  }

  String? _errorFila(_FilaMovimiento fila) {
    final producto = _producto(fila);
    if (producto == null) return 'Elige un producto del buscador.';
    final repetida = _filas.indexWhere((f) => _producto(f)?.id == producto.id);
    if (_filas.indexOf(fila) != repetida) {
      return 'El producto ya está en la fila ${repetida + 1}.';
    }
    return Validaciones.cantidad(
      fila.cantidad.text,
      tipo: _tipo,
      stockDisponible: producto.stockActual,
    );
  }

  void _agregar() {
    if (_guardando) return;
    final fila = _nuevaFila();
    setState(() => _filas.add(fila));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filas.contains(fila)) fila.focoProducto.requestFocus();
    });
  }

  void _quitar(_FilaMovimiento fila) {
    if (_guardando || _filas.length == 1) return;
    setState(() => _filas.remove(fila));
    WidgetsBinding.instance.addPostFrameCallback((_) => fila.dispose());
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _validar = true;
      _error = null;
    });
    if (_errorRazon != null || _filas.any((fila) => _errorFila(fila) != null)) {
      return;
    }
    setState(() => _guardando = true);
    try {
      final razon = _razon!;
      final guardados = await widget.enviar(
        tipo: _tipo,
        razonId: razon.id,
        sucursalDestinoId: razon.requiereSucursalDestino ? _destinoId : null,
        items: [
          for (final fila in _filas)
            (
              productoId: _producto(fila)!.id,
              cantidad: int.parse(fila.cantidad.text.trim()),
            ),
        ],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$guardados movimiento(s) guardado(s)')),
      );
      // PopScope también protege el gesto Atrás durante la petición.
      setState(() => _guardando = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.detalle;
          _guardando = false;
        });
      }
    } catch (error, stack) {
      debugPrint('registrar movimiento por lote: $error\n$stack');
      if (mounted) {
        setState(() {
          _error =
              'No se pudo confirmar el registro. Revisa la conexión y el historial antes de reintentar.';
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final movil = pantalla.width < 600;
    final contenido = PopScope(
      canPop: !_guardando,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _guardar,
        },
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Movimiento por lote',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: _guardando
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final selector = SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'entrada',
                              label: Text('Entrada'),
                            ),
                            ButtonSegment(
                              value: 'salida',
                              label: Text('Salida'),
                            ),
                            ButtonSegment(
                              value: 'ajuste',
                              label: Text('Ajuste'),
                            ),
                          ],
                          selected: {_tipo},
                          onSelectionChanged: _guardando
                              ? null
                              : (seleccion) => setState(() {
                                  _tipo = seleccion.first;
                                  _razonPorDefecto();
                                }),
                        );
                        return constraints.maxWidth < 300
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: selector,
                              )
                            : selector;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (_tipo) {
                        'ajuste' =>
                          'Fija el stock final de cada producto; admite 0.',
                        'salida' =>
                          'Retira unidades sin registrar una venta. Para cobrar, usa Ventas.',
                        _ =>
                          'Añade unidades al stock. Si tienes factura y costos, usa Compras.',
                      },
                      style: TextStyle(
                        color: context.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _selectorRazon(),
                    const SizedBox(height: 4),
                    for (var i = 0; i < _filas.length; i++) _fila(_filas[i], i),
                    BotonSeguro(
                      variante: VarianteBoton.outlined,
                      onPressed: _guardando ? null : _agregar,
                      icon: const Icon(Icons.add),
                      child: const Text('Agregar producto'),
                    ),
                    if (widget.productos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'No hay productos activos. Registra uno desde Productos.',
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: context.paleta.negativo),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_filas.length} producto(s) · Guardado completo o ninguno',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: BotonSeguro(
                          variante: VarianteBoton.outlined,
                          onPressed: _guardando
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BotonSeguro(
                          onPressed: _guardando || widget.productos.isEmpty
                              ? null
                              : _guardar,
                          child: Text(
                            _guardando ? 'Guardando…' : 'Guardar lote',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (movil) {
      return Dialog.fullscreen(child: SafeArea(child: contenido));
    }
    final alturaMaxima =
        (pantalla.height - MediaQuery.viewInsetsOf(context).bottom - 48).clamp(
          0.0,
          720.0,
        );
    final altura = (460.0 +
            (_razon?.requiereSucursalDestino == true ? 80 : 0) +
            _filas.length * 90)
        .clamp(0.0, alturaMaxima);
    return Dialog(
      child: SizedBox(width: 820, height: altura, child: contenido),
    );
  }

  /// Razón (obligatoria) y, si la razón envía a otra sucursal, el destino.
  Widget _selectorRazon() {
    final razones = _razonesTipo;
    final razon = _razon;
    final error = _validar ? _errorRazon : null;
    final pideDestino = razon?.requiereSucursalDestino == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          // La clave por tipo reconstruye el campo al cambiar de tipo: el
          // valor anterior podría no estar entre las razones nuevas.
          key: ValueKey('razon-$_tipo'),
          initialValue: razon?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Razón del movimiento',
            errorText: razon == null ? error : null,
            errorMaxLines: 2,
          ),
          items: [
            for (final r in razones)
              DropdownMenuItem(value: r.id, child: Text(r.nombre)),
          ],
          onChanged: _guardando
              ? null
              : (id) => setState(() {
                  _razonId = id;
                  _destinoId = null;
                }),
        ),
        if (pideDestino) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('destino-${razon!.id}'),
            initialValue: _destinoId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sucursal destino',
              helperText: 'La entrada se registra sola en la sucursal destino.',
              errorText: error,
              errorMaxLines: 2,
            ),
            items: [
              for (final s in _destinos)
                DropdownMenuItem(value: s.id, child: Text(s.nombre)),
            ],
            onChanged: _guardando
                ? null
                : (id) => setState(() => _destinoId = id),
          ),
        ],
      ],
    );
  }

  Widget _fila(_FilaMovimiento fila, int indice) {
    final producto = _producto(fila);
    final cantidad = int.tryParse(fila.cantidad.text);
    final resultante = producto == null || cantidad == null
        ? null
        : switch (_tipo) {
            'entrada' => producto.stockActual + cantidad,
            'salida' => producto.stockActual - cantidad,
            _ => cantidad,
          };
    final error = _validar ? _errorFila(fila) : null;
    return Container(
      key: ObjectKey(fila),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 580;
          final buscador = DropdownMenu<int>(
            controller: fila.buscador,
            focusNode: fila.focoProducto,
            initialSelection: fila.productoId,
            expandedInsets: EdgeInsets.zero,
            enableFilter: true,
            requestFocusOnTap: true,
            enabled: !_guardando,
            menuHeight: 220,
            label: Text('Producto ${indice + 1}'),
            hintText: 'Código o nombre',
            inputDecorationTheme: Theme.of(context).inputDecorationTheme,
            dropdownMenuEntries: [
              for (final producto in widget.productos)
                DropdownMenuEntry(
                  value: producto.id,
                  label: _etiqueta(producto),
                ),
            ],
            onSelected: (id) {
              setState(() => fila.productoId = id);
              if (id != null) fila.focoCantidad.requestFocus();
            },
          );
          final campoCantidad = TextField(
            controller: fila.cantidad,
            focusNode: fila.focoCantidad,
            enabled: !_guardando,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _tipo == 'ajuste' ? 'Stock final' : 'Cantidad',
            ),
            onSubmitted: (_) {
              if (_guardando) return;
              if (fila == _filas.last) {
                _agregar();
              } else {
                _filas[_filas.indexOf(fila) + 1].focoProducto.requestFocus();
              }
            },
          );
          final saldo = Text(
            producto == null
                ? 'Elige un producto para ver su saldo'
                : 'Stock ${producto.stockActual} → ${resultante ?? '—'}',
            style: TextStyle(
              color: resultante != null && resultante < 0
                  ? context.paleta.negativo
                  : context.textoSecundario,
              fontSize: 12,
            ),
          );
          final quitar = IconButton(
            tooltip: 'Quitar fila ${indice + 1}',
            onPressed: _guardando || _filas.length == 1
                ? null
                : () => _quitar(fila),
            icon: const Icon(Icons.delete_outline, size: 20),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ancho)
                Row(
                  children: [
                    Expanded(child: buscador),
                    const SizedBox(width: 8),
                    SizedBox(width: 106, child: campoCantidad),
                    const SizedBox(width: 12),
                    SizedBox(width: 132, child: saldo),
                    quitar,
                  ],
                )
              else ...[
                buscador,
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(width: 106, child: campoCantidad),
                    const SizedBox(width: 10),
                    Expanded(child: saldo),
                    quitar,
                  ],
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Fila ${indice + 1}: $error',
                    style: TextStyle(
                      color: context.paleta.negativo,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
