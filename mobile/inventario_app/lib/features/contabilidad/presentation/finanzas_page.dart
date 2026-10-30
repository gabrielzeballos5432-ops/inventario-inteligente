import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../app/destino_app.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/operaciones_service.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../../shared/widgets/section_card.dart';

class FinanzasPage extends StatelessWidget {
  const FinanzasPage({super.key, required this.seccion});

  final DestinoApp seccion;

  @override
  Widget build(BuildContext context) {
    return switch (seccion) {
      DestinoApp.clientes => const _ClientesTab(
        key: PageStorageKey('clientes'),
      ),
      DestinoApp.compras => const _ComprasTab(key: PageStorageKey('compras')),
      DestinoApp.jornadas => const _SueldosTab(key: PageStorageKey('sueldos')),
      DestinoApp.bonos => const _BonosTab(key: PageStorageKey('bonos')),
      DestinoApp.gastos => const _GastosTab(key: PageStorageKey('gastos')),
      DestinoApp.resultados => const _ReporteTab(
        key: PageStorageKey('reporte'),
      ),
      _ => throw ArgumentError.value(
        seccion,
        'seccion',
        'No es una sección financiera',
      ),
    };
  }
}

class _ClientesTab extends StatefulWidget {
  const _ClientesTab({super.key});

  @override
  State<_ClientesTab> createState() => _ClientesTabState();
}

class _ClientesTabState extends State<_ClientesTab> {
  List<Map<String, dynamic>> _clientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final clientes = await context
          .read<OperacionesService>()
          .listarClientes();
      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _crear() async {
    final form = await showDialog<_ClienteFormulario>(
      context: context,
      builder: (_) => const _ClienteDialog(),
    );
    if (form == null || !mounted) return;
    try {
      await context.read<OperacionesService>().crearCliente(
        nombre: form.nombre,
        telefono: form.telefono,
        email: form.email,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _EncabezadoSeccion(
            titulo: 'Clientes',
            descripcion:
                'Guarda los datos de las personas que compran en el salón.',
            accion: BotonSeguro(
              onPressed: _crear,
              icon: const Icon(Icons.person_add_alt_1),
              child: const Text('Nuevo cliente'),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else if (_clientes.isEmpty)
            const SectionCard(
              child: Text(
                'Todavía no hay clientes. Registra uno para asociarlo a una venta.',
              ),
            )
          else
            ..._clientes.map(
              (cliente) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          (cliente['nombre'] as String? ?? 'C')
                              .trim()
                              .characters
                              .first
                              .toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente['nombre'] as String? ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (cliente['telefono'] != null)
                              Text('Tel. ${cliente['telefono']}'),
                            if (cliente['email'] != null)
                              Text(cliente['email'] as String),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClienteFormulario {
  final String nombre;
  final String? telefono;
  final String? email;

  const _ClienteFormulario(this.nombre, this.telefono, this.email);
}

class _ClienteDialog extends StatefulWidget {
  const _ClienteDialog();

  @override
  State<_ClienteDialog> createState() => _ClienteDialogState();
}

class _ClienteDialogState extends State<_ClienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo cliente'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el nombre'
                    : null,
              ),
              TextFormField(
                controller: _telefono,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                ),
              ),
              TextFormField(
                controller: _email,
                maxLength: 150,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ClienteFormulario(
                _nombre.text.trim(),
                _telefono.text.trim(),
                _email.text.trim(),
              ),
            );
          },
          child: const Text('Guardar cliente'),
        ),
      ],
    );
  }
}

class _ComprasTab extends StatefulWidget {
  const _ComprasTab({super.key});

  @override
  State<_ComprasTab> createState() => _ComprasTabState();
}

class _ComprasTabState extends State<_ComprasTab> {
  List<Map<String, dynamic>> _compras = [];
  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _monedas = [];
  List<Map<String, dynamic>> _todasLasMonedas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final service = context.read<OperacionesService>();
      final resultado = await Future.wait<List<Map<String, dynamic>>>([
        service.listarCompras(),
        service.listarProveedores(),
        service.listarProductos(),
        service.listarMonedas(incluirInactivas: true),
      ]);
      if (!mounted) return;
      setState(() {
        _compras = resultado[0];
        _proveedores = resultado[1]
            .where((fila) => fila['activo'] == true)
            .toList();
        _productos = resultado[2]
            .where((fila) => fila['activo'] == true)
            .toList();
        _monedas = resultado[3]
            .where((fila) => fila['activa'] == true)
            .toList();
        _todasLasMonedas = resultado[3];
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _registrar() async {
    // El dialogo guarda por su cuenta: si el backend rechaza la compra, el
    // formulario sigue abierto con lo escrito en vez de perderse.
    final service = context.read<OperacionesService>();
    final creada = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompraDialog(
        proveedores: _proveedores,
        productos: _productos,
        monedas: _monedas,
        enviar: service.crearCompra,
      ),
    );
    if (creada == null || !mounted) return;
    _mensaje(
      context,
      'Compra #${creada['id']} registrada por '
      '${creada['moneda_codigo']} ${_numero(creada['total_moneda'])} '
      '(Bs ${_numero(creada['total_bob'])}).',
    );
    await _cargar();
  }

  Future<void> _administrarMonedas() async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _MonedasDialog(monedas: _todasLasMonedas),
    );
    if (cambio == true && mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _EncabezadoSeccion(
            titulo: 'Compras e ingresos de mercadería',
            descripcion:
                'Registra factura, descuentos y envío. El costo y el stock se actualizan al guardar.',
            accion: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BotonSeguro(
                  variante: VarianteBoton.outlined,
                  onPressed: _administrarMonedas,
                  icon: const Icon(Icons.currency_exchange),
                  child: const Text('Monedas'),
                ),
                BotonSeguro(
                  onPressed:
                      _proveedores.isEmpty ||
                          _productos.isEmpty ||
                          _monedas.isEmpty
                      ? null
                      : _registrar,
                  icon: const Icon(Icons.add_shopping_cart),
                  child: const Text('Registrar compra'),
                ),
              ],
            ),
          ),
          if (_proveedores.isEmpty && !_cargando)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Primero registra un proveedor en Administración → Proveedores.',
              ),
            ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else if (_compras.isEmpty)
            const SectionCard(child: Text('Aún no se han registrado compras.'))
          else
            ..._compras.map(
              (compra) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      'Compra #${compra['id']} · ${compra['estado']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${compra['numero_factura'] ?? 'Sin factura'} · '
                      '${compra['moneda_codigo']} ${_numero(compra['total_moneda'])} '
                      '(Bs ${_numero(compra['total_bob'])})',
                    ),
                    children: [
                      for (final detalle
                          in (compra['detalles'] as List<dynamic>? ?? []))
                        ListTile(
                          dense: true,
                          title: Text('Producto #${detalle['producto_id']}'),
                          subtitle: Text(
                            '${detalle['cantidad']} unidades · '
                            'costo unitario final Bs ${_numero(detalle['costo_unitario_final_bob'])}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompraDialog extends StatefulWidget {
  final List<Map<String, dynamic>> proveedores;
  final List<Map<String, dynamic>> productos;
  final List<Map<String, dynamic>> monedas;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) enviar;

  const _CompraDialog({
    required this.proveedores,
    required this.productos,
    required this.monedas,
    required this.enviar,
  });

  @override
  State<_CompraDialog> createState() => _CompraDialogState();
}

class _CompraDialogState extends State<_CompraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _factura = TextEditingController();
  final _descuento = TextEditingController(text: '0');
  final _porcentajeEnvio = TextEditingController(text: '0');
  final _tcExt = TextEditingController(text: '1');
  final _tcBob = TextEditingController(text: '6.96');
  final List<_DetalleCompraEditor> _detalles = [];
  int? _proveedorId;
  String _moneda = 'BOB';
  bool _guardando = false;
  // Los errores de producto (vacio o repetido) solo se pintan despues del
  // primer intento de guardar, para no recibir al usuario con la fila en rojo.
  bool _validar = false;
  String? _error;

  late final Map<int, String> _nombres = {
    for (final p in widget.productos) p['id'] as int: p['nombre'] as String,
  };

  @override
  void initState() {
    super.initState();
    _proveedorId = widget.proveedores.firstOrNull?['id'] as int?;
    _moneda =
        widget.monedas
            .where((moneda) => moneda['codigo'] == 'BOB')
            .map((moneda) => moneda['codigo'] as String)
            .firstOrNull ??
        widget.monedas.firstOrNull?['codigo'] as String? ??
        'BOB';
    _detalles.add(_nuevaFila());
  }

  @override
  void dispose() {
    _factura.dispose();
    _descuento.dispose();
    _porcentajeEnvio.dispose();
    _tcExt.dispose();
    _tcBob.dispose();
    for (final detalle in _detalles) {
      detalle.dispose();
    }
    super.dispose();
  }

  _DetalleCompraEditor _nuevaFila() {
    late final _DetalleCompraEditor fila;
    fila = _DetalleCompraEditor(
      alCambiar: () {
        // Si el texto del buscador ya no es el del producto elegido, la fila
        // queda sin producto: evita guardar uno distinto al que se ve.
        final id = fila.productoId;
        if (id != null && fila.buscador.text != _nombres[id]) {
          fila.productoId = null;
        }
        if (mounted) setState(() {});
      },
    );
    return fila;
  }

  void _agregarFila() {
    final fila = _nuevaFila();
    setState(() => _detalles.add(fila));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fila.focoProducto.requestFocus();
    });
  }

  void _quitarFila(_DetalleCompraEditor fila) {
    setState(() => _detalles.remove(fila));
    fila.dispose();
  }

  String? _errorProducto(_DetalleCompraEditor fila) {
    if (fila.productoId == null) return 'Elige un producto';
    final repetido =
        _detalles.where((f) => f.productoId == fila.productoId).length > 1;
    return repetido ? 'Producto repetido' : null;
  }

  double get _subtotal =>
      _detalles.fold(0, (suma, fila) => suma + fila.subtotal);

  int get _unidades => _detalles.fold(0, (suma, fila) => suma + fila.unidades);

  Map<String, dynamic> _payload() => {
    'proveedor_id': _proveedorId,
    'moneda_codigo': _moneda,
    'tipo_cambio_ext': _moneda == 'BOB'
        ? _tcBob.text.trim()
        : _tcExt.text.trim(),
    'tipo_cambio_bob': _tcBob.text.trim(),
    'numero_factura': _factura.text.trim().isEmpty
        ? null
        : _factura.text.trim(),
    'descuento_moneda': _descuento.text.trim(),
    'porcentaje_manipulacion_envio': _porcentajeEnvio.text.trim(),
    'detalles': _detalles
        .map(
          (fila) => {
            'producto_id': fila.productoId,
            'cantidad': int.parse(fila.cantidad.text),
            'costo_unitario_moneda': fila.costo.text.trim(),
            if (fila.descripcion.text.trim().isNotEmpty)
              'descripcion_factura': fila.descripcion.text.trim(),
          },
        )
        .toList(),
  };

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _validar = true;
      _error = null;
    });
    final formularioOk = _formKey.currentState!.validate();
    final productosOk = _detalles.every((f) => _errorProducto(f) == null);
    if (!formularioOk || !productosOk || _proveedorId == null) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }
    if (_moneda == 'USD' && (double.tryParse(_tcExt.text) ?? 0) != 1) {
      setState(
        () => _error = 'Para USD, el tipo de cambio externo debe ser 1.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final creada = await widget.enviar(_payload());
      if (!mounted) return;
      // _guardando queda en true a proposito: el dialogo ya se cierra y un
      // segundo Enter no debe volver a enviar la misma compra.
      Navigator.of(context).pop(creada);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = _detalleError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantallaCompleta = MediaQuery.sizeOf(context).width < 600;
    final contenido = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: pantallaCompleta ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(),
          const Divider(),
          Flexible(
            fit: pantallaCompleta ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tituloSeccion('Factura'),
                  _datosFactura(),
                  const SizedBox(height: 16),
                  _tituloSeccion('Productos'),
                  _tablaProductos(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _guardando ? null : _agregarFila,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar producto'),
                    ),
                  ),
                  Text(
                    'El costo final por unidad se convierte a BOB y actualiza '
                    'el costo promedio del inventario.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _pie(pantallaCompleta),
        ],
      ),
    );

    return PopScope(
      canPop: !_guardando,
      child: pantallaCompleta
          ? Dialog.fullscreen(child: SafeArea(child: contenido))
          : Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: contenido,
              ),
            ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Registrar compra',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: _guardando ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.textoSecundario,
      ),
    ),
  );

  /// Grilla de 2 columnas en el telefono y 3 en pantallas anchas.
  Widget _datosFactura() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 640 ? 3 : 2;
        const espacio = 8.0;
        final celda =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        Widget ocupa(int span, Widget hijo) =>
            SizedBox(width: celda * span + espacio * (span - 1), child: hijo);
        final decimal = const TextInputType.numberWithOptions(decimal: true);
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            ocupa(
              2,
              DropdownButtonFormField<int>(
                initialValue: _proveedorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Proveedor'),
                items: widget.proveedores
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          item['nombre'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'Elige un proveedor' : null,
                onChanged: (value) => setState(() => _proveedorId = value),
              ),
            ),
            ocupa(
              1,
              TextFormField(
                controller: _factura,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'N° factura',
                  hintText: 'Opcional',
                  counterText: '',
                ),
              ),
            ),
            ocupa(
              1,
              DropdownButtonFormField<String>(
                initialValue: _moneda,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Moneda'),
                items: widget.monedas
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['codigo'] as String,
                        child: Text(
                          '${item['codigo']} · ${item['nombre']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _moneda = value;
                    if (value == 'USD') _tcExt.text = '1';
                    if (value == 'BOB') _tcExt.text = _tcBob.text;
                  });
                },
              ),
            ),
            if (_moneda != 'BOB')
              ocupa(
                1,
                TextFormField(
                  controller: _tcExt,
                  keyboardType: decimal,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _moneda == 'USD'
                        ? 'T/C externo'
                        : '$_moneda por USD',
                    errorMaxLines: 2,
                  ),
                  validator: _positivo,
                ),
              ),
            ocupa(
              1,
              TextFormField(
                controller: _tcBob,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Bs por USD',
                  errorMaxLines: 2,
                ),
                validator: _positivo,
              ),
            ),
            ocupa(
              1,
              TextFormField(
                controller: _descuento,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Descuento ($_moneda)',
                  errorMaxLines: 2,
                ),
                validator: _noNegativo,
              ),
            ),
            ocupa(
              1,
              TextFormField(
                controller: _porcentajeEnvio,
                keyboardType: decimal,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Envío (%)',
                  errorMaxLines: 2,
                ),
                validator: (value) {
                  final n = double.tryParse(value ?? '');
                  return n == null || n < 0 || n > 100 ? 'De 0 a 100' : null;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tabla editable: una linea por producto en pantallas anchas y dos lineas
  /// (producto arriba; cantidad, costo y subtotal abajo) en el telefono.
  Widget _tablaProductos() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancha = constraints.maxWidth >= 560;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: context.paleta.borde),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (ancha) _encabezadoTabla(),
              for (var i = 0; i < _detalles.length; i++) ...[
                if (i > 0 || ancha) const Divider(height: 1),
                ancha ? _filaAncha(i) : _filaAngosta(i),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _encabezadoTabla() {
    final estilo = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: context.textoSecundario,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: estilo)),
          Expanded(child: Text('Producto', style: estilo)),
          const SizedBox(width: 8),
          SizedBox(width: 76, child: Text('Cant.', style: estilo)),
          const SizedBox(width: 8),
          SizedBox(width: 104, child: Text('Costo u.', style: estilo)),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text('Subtotal', style: estilo, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _filaAncha(int indice) {
    final fila = _detalles[indice];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('${indice + 1}'),
                ),
              ),
              Expanded(child: _selectorProducto(fila, conEtiqueta: false)),
              const SizedBox(width: 8),
              SizedBox(width: 76, child: _campoCantidad(fila, false)),
              const SizedBox(width: 8),
              SizedBox(width: 104, child: _campoCosto(fila, false)),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _textoSubtotal(fila),
                ),
              ),
              _accionesFila(fila),
            ],
          ),
          if (fila.conDescripcion) ...[
            const SizedBox(height: 6),
            _campoDescripcion(fila),
          ],
        ],
      ),
    );
  }

  Widget _filaAngosta(int indice) {
    final fila = _detalles[indice];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _selectorProducto(
                  fila,
                  conEtiqueta: true,
                  indice: indice,
                ),
              ),
              _accionesFila(fila),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _campoCantidad(fila, true)),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _campoCosto(fila, true)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _textoSubtotal(fila),
                  ),
                ),
              ],
            ),
          ),
          if (fila.conDescripcion) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _campoDescripcion(fila),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectorProducto(
    _DetalleCompraEditor fila, {
    required bool conEtiqueta,
    int indice = 0,
  }) {
    return DropdownMenu<int>(
      controller: fila.buscador,
      focusNode: fila.focoProducto,
      initialSelection: fila.productoId,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 280,
      label: conEtiqueta ? Text('Producto ${indice + 1}') : null,
      hintText: 'Buscar producto',
      errorText: _validar && !_guardando ? _errorProducto(fila) : null,
      inputDecorationTheme: Theme.of(context).inputDecorationTheme,
      enabled: !_guardando,
      dropdownMenuEntries: [
        for (final entrada in _nombres.entries)
          DropdownMenuEntry<int>(value: entrada.key, label: entrada.value),
      ],
      onSelected: (id) {
        setState(() => fila.productoId = id);
        if (id != null) fila.focoCantidad.requestFocus();
      },
    );
  }

  Widget _campoCantidad(_DetalleCompraEditor fila, bool conEtiqueta) {
    return TextFormField(
      controller: fila.cantidad,
      focusNode: fila.focoCantidad,
      enabled: !_guardando,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.end,
      decoration: InputDecoration(
        labelText: conEtiqueta ? 'Cant.' : null,
        errorMaxLines: 2,
      ),
      validator: (value) =>
          (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Mín. 1' : null,
    );
  }

  Widget _campoCosto(_DetalleCompraEditor fila, bool conEtiqueta) {
    return TextFormField(
      controller: fila.costo,
      enabled: !_guardando,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.end,
      decoration: InputDecoration(
        labelText: conEtiqueta ? 'Costo u. ($_moneda)' : null,
        errorMaxLines: 2,
      ),
      validator: (value) =>
          (double.tryParse(value ?? '') ?? -1) < 0 ? 'Costo ≥ 0' : null,
      onFieldSubmitted: (_) {
        if (fila == _detalles.last) _agregarFila();
      },
    );
  }

  Widget _textoSubtotal(_DetalleCompraEditor fila) => Text(
    _numero(fila.subtotal),
    textAlign: TextAlign.end,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontWeight: FontWeight.w700),
  );

  Widget _campoDescripcion(_DetalleCompraEditor fila) => TextFormField(
    controller: fila.descripcion,
    enabled: !_guardando,
    maxLength: 250,
    decoration: const InputDecoration(
      labelText: 'Descripción en la factura',
      counterText: '',
    ),
  );

  Widget _accionesFila(_DetalleCompraEditor fila) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: fila.conDescripcion
              ? 'Ocultar descripción'
              : 'Agregar descripción de factura',
          visualDensity: VisualDensity.compact,
          onPressed: _guardando
              ? null
              : () =>
                    setState(() => fila.conDescripcion = !fila.conDescripcion),
          icon: Icon(
            fila.conDescripcion ? Icons.notes : Icons.note_add_outlined,
            size: 20,
          ),
        ),
        IconButton(
          tooltip: 'Quitar producto',
          visualDensity: VisualDensity.compact,
          onPressed: _detalles.length == 1 || _guardando
              ? null
              : () => _quitarFila(fila),
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      ],
    );
  }

  Widget _pie(bool pantallaCompleta) {
    final resumen = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_detalles.length} producto(s) · $_unidades unidad(es)',
          style: TextStyle(fontSize: 12, color: context.textoSecundario),
        ),
        Text(
          'Subtotal $_moneda ${_numero(_subtotal)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
    final cancelar = OutlinedButton(
      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    );
    final registrar = BotonSeguro(
      onPressed: _guardando ? null : _guardar,
      icon: const Icon(Icons.check),
      child: const Text('Registrar'),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.paleta.borde)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: context.paleta.negativo),
              ),
            ),
          if (pantallaCompleta) ...[
            resumen,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: cancelar),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: registrar),
              ],
            ),
          ] else
            Row(
              children: [
                Expanded(child: resumen),
                cancelar,
                const SizedBox(width: 8),
                registrar,
              ],
            ),
        ],
      ),
    );
  }
}

class _DetalleCompraEditor {
  _DetalleCompraEditor({required VoidCallback alCambiar}) {
    buscador.addListener(alCambiar);
    cantidad.addListener(alCambiar);
    costo.addListener(alCambiar);
  }

  int? productoId;
  bool conDescripcion = false;
  final buscador = TextEditingController();
  final cantidad = TextEditingController(text: '1');
  final costo = TextEditingController();
  final descripcion = TextEditingController();
  final focoProducto = FocusNode();
  final focoCantidad = FocusNode();

  int get unidades => int.tryParse(cantidad.text) ?? 0;

  double get subtotal =>
      unidades * (double.tryParse(costo.text.replaceAll(',', '.')) ?? 0);

  void dispose() {
    buscador.dispose();
    cantidad.dispose();
    costo.dispose();
    descripcion.dispose();
    focoProducto.dispose();
    focoCantidad.dispose();
  }
}

class _MonedasDialog extends StatefulWidget {
  final List<Map<String, dynamic>> monedas;

  const _MonedasDialog({required this.monedas});

  @override
  State<_MonedasDialog> createState() => _MonedasDialogState();
}

class _MonedasDialogState extends State<_MonedasDialog> {
  late List<Map<String, dynamic>> _monedas;
  bool _cambio = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _monedas = widget.monedas.map(Map<String, dynamic>.from).toList();
  }

  Future<void> _crear() async {
    final datos = await showDialog<_MonedaFormulario>(
      context: context,
      builder: (_) => const _MonedaDialog(),
    );
    if (datos == null || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final creada = await context.read<OperacionesService>().crearMoneda(
        codigo: datos.codigo,
        nombre: datos.nombre,
        simbolo: datos.simbolo,
        pais: datos.pais,
        decimales: datos.decimales,
      );
      if (!mounted) return;
      setState(() {
        _monedas.add(creada);
        _monedas.sort(
          (a, b) => (a['codigo'] as String).compareTo(b['codigo'] as String),
        );
        _cambio = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _detalleError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarEstado(Map<String, dynamic> moneda) async {
    final codigo = moneda['codigo'] as String;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizada = await context
          .read<OperacionesService>()
          .actualizarEstadoMoneda(codigo, moneda['activa'] != true);
      if (!mounted) return;
      setState(() {
        final indice = _monedas.indexWhere((fila) => fila['codigo'] == codigo);
        if (indice >= 0) _monedas[indice] = actualizada;
        _cambio = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _detalleError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monedas aceptadas'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.paleta.negativo),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final moneda in _monedas)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${moneda['codigo']} · ${moneda['nombre']}'),
                      subtitle: Text(
                        '${moneda['simbolo'] ?? 'Sin símbolo'} · '
                        '${moneda['decimales']} decimales · '
                        '${moneda['activa'] == true ? 'Activa' : 'Inactiva'}',
                      ),
                      trailing: Switch(
                        value: moneda['activa'] == true,
                        onChanged:
                            _guardando ||
                                moneda['codigo'] == 'BOB' ||
                                moneda['codigo'] == 'USD'
                            ? null
                            : (_) => _cambiarEstado(moneda),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        BotonSeguro(
          variante: VarianteBoton.text,
          onPressed: _guardando ? null : _crear,
          icon: const Icon(Icons.add),
          child: const Text('Agregar moneda'),
        ),
        BotonSeguro(
          onPressed: _guardando ? null : () => Navigator.pop(context, _cambio),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

class _MonedaFormulario {
  final String codigo;
  final String nombre;
  final String? simbolo;
  final String? pais;
  final int decimales;

  const _MonedaFormulario({
    required this.codigo,
    required this.nombre,
    required this.simbolo,
    required this.pais,
    required this.decimales,
  });
}

class _MonedaDialog extends StatefulWidget {
  const _MonedaDialog();

  @override
  State<_MonedaDialog> createState() => _MonedaDialogState();
}

class _MonedaDialogState extends State<_MonedaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _simbolo = TextEditingController();
  final _pais = TextEditingController();
  int _decimales = 2;

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _simbolo.dispose();
    _pais.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar moneda'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codigo,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: const InputDecoration(
                  labelText: 'Código ISO (3 letras)',
                ),
                validator: (value) =>
                    RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Usa exactamente 3 letras',
              ),
              TextFormField(
                controller: _nombre,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el nombre'
                    : null,
              ),
              TextFormField(
                controller: _simbolo,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Símbolo (opcional)',
                ),
              ),
              TextFormField(
                controller: _pais,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'País (opcional)'),
              ),
              DropdownButtonFormField<int>(
                initialValue: _decimales,
                decoration: const InputDecoration(
                  labelText: 'Decimales de la moneda',
                ),
                items: [
                  for (var i = 0; i <= 4; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _decimales = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _MonedaFormulario(
                codigo: _codigo.text.trim().toUpperCase(),
                nombre: _nombre.text.trim(),
                simbolo: _simbolo.text.trim().isEmpty
                    ? null
                    : _simbolo.text.trim(),
                pais: _pais.text.trim().isEmpty ? null : _pais.text.trim(),
                decimales: _decimales,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SueldosTab extends StatefulWidget {
  const _SueldosTab({super.key});

  @override
  State<_SueldosTab> createState() => _SueldosTabState();
}

class _SueldosTabState extends State<_SueldosTab> {
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _liquidaciones = [];
  List<Map<String, dynamic>> _asistencias = [];
  bool _cargando = true;
  bool _accionando = false;
  String? _error;

  bool get _esAdmin => context.read<AuthProvider>().isAdmin;

  @override
  void initState() {
    super.initState();
    if (_esAdmin) _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final service = context.read<OperacionesService>();
      final resultado = await Future.wait([
        service.listarUsuarios(),
        service.listarLiquidaciones(),
        service.listarAsistencias(),
      ]);
      if (!mounted) return;
      setState(() {
        _usuarios = resultado[0]
            .where(
              (usuario) =>
                  usuario['activo'] == true &&
                  (usuario['rol_nombre'] as String? ?? '').toLowerCase() ==
                      'vendedor',
            )
            .toList();
        _liquidaciones = resultado[1];
        _asistencias = resultado[2];
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _marcar(bool entrada) async {
    final esAdmin = _esAdmin;
    setState(() => _accionando = true);
    try {
      final respuesta = entrada
          ? await context.read<OperacionesService>().marcarEntrada()
          : await context.read<OperacionesService>().marcarSalida();
      if (!mounted) return;
      _mensaje(
        context,
        entrada
            ? 'Entrada registrada para ${respuesta['fecha']} a las ${respuesta['hora_entrada']}.'
            : 'Salida registrada para ${respuesta['fecha']} a las ${respuesta['hora_salida']}.',
      );
      if (esAdmin) await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    } finally {
      if (mounted) setState(() => _accionando = false);
    }
  }

  Future<void> _confirmar(Map<String, dynamic> asistencia) async {
    try {
      await context.read<OperacionesService>().confirmarAsistencia(
        asistencia['id'] as int,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _liquidar() async {
    if (_usuarios.isEmpty) {
      _mensaje(context, 'No hay vendedores activos para liquidar.');
      return;
    }
    final datos = await showDialog<_LiquidacionFormulario>(
      context: context,
      builder: (_) => _LiquidacionDialog(usuarios: _usuarios),
    );
    if (datos == null || !mounted) return;
    try {
      final creada = await context.read<OperacionesService>().crearLiquidacion(
        usuarioId: datos.usuarioId,
        fechaInicio: datos.fechaInicio,
        fechaFin: datos.fechaFin,
      );
      if (!mounted) return;
      _mensaje(
        context,
        'Liquidación #${creada['id']} calculada: '
        'Bs ${_numero(creada['total_pagado'])}.',
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _configurarTarifas(Map<String, dynamic> usuario) async {
    final tarifas = await showDialog<_TarifasVendedor>(
      context: context,
      builder: (_) => _TarifasVendedorDialog(usuario: usuario),
    );
    if (tarifas == null || !mounted) return;
    try {
      await context.read<OperacionesService>().actualizarTarifasVendedor(
        usuarioId: usuario['id'] as int,
        pagoPorHora: tarifas.pagoPorHora,
        porcentajeComision: tarifas.porcentajeComision,
      );
      if (!mounted) return;
      _mensaje(context, 'Tarifas de ${usuario['nombre']} actualizadas.');
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _pagar(Map<String, dynamic> liquidacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Confirmar pago de sueldo'),
        content: Text(
          'Marcar liquidación #${liquidacion['id']} como pagada por '
          'Bs ${_numero(liquidacion['total_pagado'])}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          BotonSeguro(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Marcar pagada'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await context.read<OperacionesService>().pagarLiquidacion(
        liquidacion['id'] as int,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_esAdmin) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _EncabezadoSimple(
            titulo: 'Control de jornada',
            descripcion:
                'Registra tu asistencia al iniciar y terminar tu jornada.',
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Las horas se registran con la fecha y hora local de Bolivia.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BotonSeguro(
                      onPressed: _accionando ? null : () => _marcar(true),
                      icon: const Icon(Icons.login),
                      child: const Text('Marcar entrada'),
                    ),
                    BotonSeguro(
                      variante: VarianteBoton.outlined,
                      onPressed: _accionando ? null : () => _marcar(false),
                      icon: const Icon(Icons.logout),
                      child: const Text('Marcar salida'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _EncabezadoSeccion(
            titulo: 'Sueldos y asistencia',
            descripcion:
                'Revisa y confirma jornadas antes de calcular una liquidación.',
            accion: BotonSeguro(
              onPressed: _liquidar,
              icon: const Icon(Icons.calculate_outlined),
              child: const Text('Calcular liquidación'),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else ...[
            Text(
              'Tarifas de vendedores',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_usuarios.isEmpty)
              const SectionCard(child: Text('No hay vendedores activos.'))
            else
              ..._usuarios.map((usuario) {
                final pagoPorHora = usuario['pago_por_hora'];
                final porcentajeComision = usuario['porcentaje_comision'];
                final configurado =
                    pagoPorHora != null && porcentajeComision != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                usuario['nombre'] as String? ?? 'Vendedor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                configurado
                                    ? 'Bs ${_numero(pagoPorHora)}/hora · '
                                          '${_numero(porcentajeComision)}% de comisión'
                                    : 'Tarifas sin configurar',
                              ),
                            ],
                          ),
                        ),
                        BotonIconoSeguro(
                          tooltip: 'Configurar tarifas',
                          onPressed: () => _configurarTarifas(usuario),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'La comisión se calcula sobre las ventas completadas del período. '
                'Las nuevas tarifas se aplican a liquidaciones futuras.',
              ),
            ),
            Text(
              'Asistencias por revisar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_asistencias.isEmpty)
              const SectionCard(child: Text('No hay asistencias registradas.'))
            else
              ..._asistencias.map((asistencia) {
                final confirmada =
                    asistencia['confirmado_por_usuario_id'] != null;
                final salida = asistencia['hora_salida'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    child: Row(
                      children: [
                        Icon(
                          confirmada
                              ? Icons.check_circle_outline
                              : Icons.pending_outlined,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_nombreUsuario(asistencia['usuario_id'])} · ${asistencia['fecha']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${asistencia['hora_entrada']}'
                                '${salida == null ? ' · Jornada abierta' : ' a $salida'}',
                              ),
                              Text(
                                confirmada
                                    ? 'Confirmada'
                                    : 'Pendiente de confirmar',
                              ),
                            ],
                          ),
                        ),
                        if (!confirmada && salida != null)
                          BotonIconoSeguro(
                            tooltip: 'Confirmar asistencia',
                            onPressed: () => _confirmar(asistencia),
                            icon: const Icon(Icons.check),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 18),
            Text(
              'Liquidaciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_liquidaciones.isEmpty)
              const SectionCard(child: Text('Aún no hay liquidaciones.'))
            else
              ..._liquidaciones.map(
                (liquidacion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_nombreUsuario(liquidacion['usuario_id'])} · ${liquidacion['fecha_inicio']} a ${liquidacion['fecha_fin']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Horas Bs ${_numero(liquidacion['total_pago_horas'])} · '
                                'comisión Bs ${_numero(liquidacion['total_comision'])} · '
                                'bonos Bs ${_numero(liquidacion['total_bonos'])}',
                              ),
                              Text(
                                'Total a pagar: Bs ${_numero(liquidacion['total_pagado'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                liquidacion['estado'] == 'pagado'
                                    ? 'PAGADO${liquidacion['fecha_pago'] == null ? '' : ' · ${_formatearFecha(liquidacion['fecha_pago'])}'}'
                                    : 'PENDIENTE DE PAGO',
                                style: TextStyle(
                                  color: liquidacion['estado'] == 'pagado'
                                      ? context.paleta.positivo
                                      : context.paleta.aviso,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (liquidacion['estado'] == 'pendiente')
                          BotonIconoSeguro(
                            tooltip: 'Marcar como pagada',
                            onPressed: () => _pagar(liquidacion),
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _nombreUsuario(dynamic id) {
    return _usuarios
            .where((usuario) => usuario['id'] == id)
            .map((usuario) => usuario['nombre'] as String? ?? '')
            .firstOrNull ??
        'Vendedor #$id';
  }

  String _formatearFecha(dynamic valor) {
    final fecha = DateTime.tryParse('$valor');
    if (fecha == null) return '$valor';
    final local = fecha.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _TarifasVendedor {
  final String pagoPorHora;
  final String porcentajeComision;

  const _TarifasVendedor({
    required this.pagoPorHora,
    required this.porcentajeComision,
  });
}

class _TarifasVendedorDialog extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const _TarifasVendedorDialog({required this.usuario});

  @override
  State<_TarifasVendedorDialog> createState() => _TarifasVendedorDialogState();
}

class _TarifasVendedorDialogState extends State<_TarifasVendedorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pagoPorHoraController;
  late final TextEditingController _porcentajeComisionController;

  @override
  void initState() {
    super.initState();
    _pagoPorHoraController = TextEditingController(
      text: _valorInicial(widget.usuario['pago_por_hora']),
    );
    _porcentajeComisionController = TextEditingController(
      text: _valorInicial(widget.usuario['porcentaje_comision']),
    );
  }

  String _valorInicial(dynamic valor) {
    if (valor == null) return '';
    final numero = double.tryParse('$valor');
    return numero?.toStringAsFixed(2) ?? '';
  }

  @override
  void dispose() {
    _pagoPorHoraController.dispose();
    _porcentajeComisionController.dispose();
    super.dispose();
  }

  String? _validarNumero(String? valor, {required bool permitirCero}) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    final numero = double.tryParse(texto);
    if (numero == null || (permitirCero ? numero < 0 : numero <= 0)) {
      return permitirCero
          ? 'Ingresa un porcentaje entre 0 y 100'
          : 'Ingresa un pago por hora mayor que cero';
    }
    if (texto.contains('.') && texto.split('.').last.length > 2) {
      return 'Admite hasta 2 decimales';
    }
    if (permitirCero && numero > 100) {
      return 'Ingresa un porcentaje entre 0 y 100';
    }
    return null;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TarifasVendedor(
        pagoPorHora: _pagoPorHoraController.text.trim().replaceAll(',', '.'),
        porcentajeComision: _porcentajeComisionController.text
            .trim()
            .replaceAll(',', '.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tarifas de ${widget.usuario['nombre']}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _pagoPorHoraController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Pago por hora (Bs)',
                    errorMaxLines: 2,
                  ),
                  validator: (valor) =>
                      _validarNumero(valor, permitirCero: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _porcentajeComisionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Comisión por ventas (%)',
                    helperText:
                        'Se aplica sobre las ventas completadas del período.',
                    errorMaxLines: 2,
                  ),
                  validator: (valor) =>
                      _validarNumero(valor, permitirCero: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(onPressed: _guardar, child: const Text('Guardar tarifas')),
      ],
    );
  }
}

class _LiquidacionFormulario {
  final int usuarioId;
  final String fechaInicio;
  final String fechaFin;

  const _LiquidacionFormulario({
    required this.usuarioId,
    required this.fechaInicio,
    required this.fechaFin,
  });
}

class _LiquidacionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> usuarios;

  const _LiquidacionDialog({required this.usuarios});

  @override
  State<_LiquidacionDialog> createState() => _LiquidacionDialogState();
}

class _LiquidacionDialogState extends State<_LiquidacionDialog> {
  int? _usuarioId;
  late DateTime _inicio;
  late DateTime _fin;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _usuarioId = widget.usuarios.firstOrNull?['id'] as int?;
    _inicio = DateTime(ahora.year, ahora.month);
    _fin = ahora;
  }

  String _iso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha(bool inicio) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() {
        if (inicio) {
          _inicio = fecha;
        } else {
          _fin = fecha;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Calcular liquidación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _usuarioId,
            decoration: const InputDecoration(labelText: 'Vendedor'),
            items: widget.usuarios
                .map(
                  (usuario) => DropdownMenuItem(
                    value: usuario['id'] as int,
                    child: Text(usuario['nombre'] as String? ?? ''),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _usuarioId = value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Inicio del período'),
            subtitle: Text(_iso(_inicio)),
            trailing: IconButton(
              onPressed: () => _elegirFecha(true),
              icon: const Icon(Icons.calendar_month),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fin del período'),
            subtitle: Text(_iso(_fin)),
            trailing: IconButton(
              onPressed: () => _elegirFecha(false),
              icon: const Icon(Icons.calendar_month),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: _usuarioId == null || _fin.isBefore(_inicio)
              ? null
              : () => Navigator.pop(
                  context,
                  _LiquidacionFormulario(
                    usuarioId: _usuarioId!,
                    fechaInicio: _iso(_inicio),
                    fechaFin: _iso(_fin),
                  ),
                ),
          child: const Text('Calcular'),
        ),
      ],
    );
  }
}

String? _positivo(String? value) =>
    (double.tryParse(value ?? '') ?? 0) <= 0 ? 'Debe ser mayor a cero' : null;

String? _noNegativo(String? value) => (double.tryParse(value ?? '') ?? -1) < 0
    ? 'Ingresa un importe válido'
    : null;

class _BonosTab extends StatefulWidget {
  const _BonosTab({super.key});

  @override
  State<_BonosTab> createState() => _BonosTabState();
}

class _BonosTabState extends State<_BonosTab> {
  List<Map<String, dynamic>> _bonos = [];
  List<Map<String, dynamic>> _vendedores = [];
  List<Map<String, dynamic>> _liquidaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final service = context.read<OperacionesService>();
      final resultado = await Future.wait([
        service.listarBonos(),
        service.listarUsuarios(),
        service.listarLiquidaciones(),
      ]);
      if (!mounted) return;
      setState(() {
        _bonos = resultado[0];
        _vendedores = resultado[1]
            .where(
              (u) =>
                  u['activo'] == true &&
                  (u['rol_nombre'] as String? ?? '').toLowerCase() ==
                      'vendedor',
            )
            .toList();
        _liquidaciones = resultado[2];
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _crear() async {
    final bono = await showDialog<_BonoFormulario>(
      context: context,
      builder: (_) =>
          _BonoDialog(vendedores: _vendedores, liquidaciones: _liquidaciones),
    );
    if (bono == null || !mounted) return;
    try {
      await context.read<OperacionesService>().crearBono(
        usuarioId: bono.usuarioId,
        liquidacionId: bono.liquidacionId,
        tipo: bono.tipo,
        descripcion: bono.descripcion,
        monto: bono.monto,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _asignar(Map<String, dynamic> bono) async {
    final liquidaciones = _liquidaciones
        .where(
          (liquidacion) =>
              liquidacion['usuario_id'] == bono['usuario_id'] &&
              liquidacion['estado'] == 'pendiente' &&
              liquidacion['id'] != bono['liquidacion_sueldo_id'],
        )
        .toList();
    if (liquidaciones.isEmpty) {
      _mensaje(context, 'No hay liquidaciones pendientes para este vendedor.');
      return;
    }
    final id = await showDialog<int>(
      context: context,
      builder: (context) =>
          _ElegirLiquidacionDialog(liquidaciones: liquidaciones),
    );
    if (id == null || !mounted) return;
    try {
      await context.read<OperacionesService>().asignarBono(
        bono['id'] as int,
        id,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _EncabezadoSeccion(
            titulo: 'Bonos del personal',
            descripcion:
                'Registra incentivos y asígnalos a la liquidación que corresponda.',
            accion: BotonSeguro(
              onPressed: _vendedores.isEmpty || _cargando ? null : _crear,
              icon: const Icon(Icons.add),
              child: const Text('Registrar bono'),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else if (_bonos.isEmpty)
            const SectionCard(child: Text('Aún no se han registrado bonos.'))
          else
            ..._bonos.map(
              (bono) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_nombreBono(bono['tipo_bono'])} · Bs ${_numero(bono['monto'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_nombreVendedor(bono['usuario_id'])}'
                              '${bono['descripcion'] == null ? '' : ' · ${bono['descripcion']}'}',
                            ),
                            Text(
                              bono['liquidacion_sueldo_id'] == null
                                  ? 'Pendiente de liquidación'
                                  : 'Liquidación #${bono['liquidacion_sueldo_id']}',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (bono['liquidacion_sueldo_id'] == null)
                        BotonIconoSeguro(
                          tooltip: 'Asignar a liquidación',
                          onPressed: () => _asignar(bono),
                          icon: const Icon(Icons.link),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _nombreVendedor(dynamic id) {
    return _vendedores
            .where((vendedor) => vendedor['id'] == id)
            .map((vendedor) => vendedor['nombre'] as String? ?? '')
            .firstOrNull ??
        'Vendedor #$id';
  }
}

class _BonoFormulario {
  final int usuarioId;
  final int? liquidacionId;
  final String tipo;
  final String? descripcion;
  final double monto;

  const _BonoFormulario({
    required this.usuarioId,
    required this.liquidacionId,
    required this.tipo,
    required this.descripcion,
    required this.monto,
  });
}

class _BonoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vendedores;
  final List<Map<String, dynamic>> liquidaciones;

  const _BonoDialog({required this.vendedores, required this.liquidaciones});

  @override
  State<_BonoDialog> createState() => _BonoDialogState();
}

class _BonoDialogState extends State<_BonoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  int? _usuarioId;
  int? _liquidacionId;
  String _tipo = 'otro';

  @override
  void initState() {
    super.initState();
    _usuarioId = widget.vendedores.firstOrNull?['id'] as int?;
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar bono'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _usuarioId,
                decoration: const InputDecoration(labelText: 'Vendedor'),
                items: widget.vendedores
                    .map(
                      (u) => DropdownMenuItem(
                        value: u['id'] as int,
                        child: Text(u['nombre'] as String? ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _usuarioId = value;
                  _liquidacionId = null;
                }),
              ),
              DropdownButtonFormField<int?>(
                initialValue: _liquidacionId,
                decoration: const InputDecoration(
                  labelText: 'Liquidación pendiente (opcional)',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Dejar pendiente'),
                  ),
                  ...widget.liquidaciones
                      .where(
                        (liquidacion) =>
                            liquidacion['usuario_id'] == _usuarioId &&
                            liquidacion['estado'] == 'pendiente',
                      )
                      .map(
                        (liquidacion) => DropdownMenuItem<int?>(
                          value: liquidacion['id'] as int,
                          child: Text(
                            '#${liquidacion['id']} · ${liquidacion['fecha_inicio']} a ${liquidacion['fecha_fin']}',
                          ),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _liquidacionId = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de bono'),
                items: const [
                  DropdownMenuItem(
                    value: 'live',
                    child: Text('Por hacer lives'),
                  ),
                  DropdownMenuItem(value: 'almuerzo', child: Text('Almuerzo')),
                  DropdownMenuItem(value: 'navidad', child: Text('Navidad')),
                  DropdownMenuItem(value: 'otro', child: Text('Otro')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _tipo = value);
                },
              ),
              TextFormField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Monto (Bs)'),
                validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Monto inválido'
                    : null,
              ),
              TextFormField(
                controller: _descripcion,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (!_formKey.currentState!.validate() || _usuarioId == null) {
              return;
            }
            Navigator.pop(
              context,
              _BonoFormulario(
                usuarioId: _usuarioId!,
                liquidacionId: _liquidacionId,
                tipo: _tipo,
                descripcion: _descripcion.text,
                monto: double.parse(_monto.text),
              ),
            );
          },
          child: const Text('Guardar bono'),
        ),
      ],
    );
  }
}

class _ElegirLiquidacionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> liquidaciones;

  const _ElegirLiquidacionDialog({required this.liquidaciones});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Elige una liquidación pendiente'),
      children: [
        for (final liquidacion in liquidaciones)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, liquidacion['id'] as int),
            child: Text(
              '#${liquidacion['id']} · ${liquidacion['fecha_inicio']} a ${liquidacion['fecha_fin']} · Bs ${_numero(liquidacion['total_pagado'])}',
            ),
          ),
      ],
    );
  }
}

class _GastosTab extends StatefulWidget {
  const _GastosTab({super.key});

  @override
  State<_GastosTab> createState() => _GastosTabState();
}

class _GastosTabState extends State<_GastosTab> {
  List<Map<String, dynamic>> _gastos = [];
  List<Map<String, dynamic>> _monedas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        context.read<OperacionesService>().listarGastos(),
        context.read<OperacionesService>().listarMonedas(),
      ]);
      if (!mounted) return;
      setState(() {
        _gastos = resultados[0];
        _monedas = resultados[1].where((m) => m['activa'] == true).toList();
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _crear() async {
    final gasto = await showDialog<_GastoFormulario>(
      context: context,
      builder: (_) => _GastoDialog(monedas: _monedas),
    );
    if (gasto == null || !mounted) return;
    try {
      await context.read<OperacionesService>().crearGasto(
        categoria: gasto.categoria,
        concepto: gasto.concepto,
        monedaCodigo: gasto.moneda,
        monto: gasto.monto,
        tipoCambioExt: gasto.tipoCambioExt,
        tipoCambioBob: gasto.tipoCambioBob,
        numeroDocumento: gasto.numeroDocumento,
        periodoDesde: gasto.periodoDesde,
        periodoHasta: gasto.periodoHasta,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _pagar(Map<String, dynamic> gasto) async {
    final pago = await showDialog<_PagoFormulario>(
      context: context,
      builder: (_) => _PagoGastoDialog(gasto: gasto),
    );
    if (pago == null || !mounted) return;
    try {
      await context.read<OperacionesService>().pagarGasto(
        gastoId: gasto['id'] as int,
        monto: pago.monto,
        metodoPago: pago.metodo,
        referencia: pago.referencia,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  Future<void> _anular(Map<String, dynamic> gasto) async {
    final motivo = await _pedirMotivo(context, 'Anular gasto');
    if (motivo == null || !mounted) return;
    try {
      await context.read<OperacionesService>().anularGasto(
        gasto['id'] as int,
        motivo,
      );
      await _cargar();
    } catch (error) {
      if (mounted) _mensaje(context, _detalleError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _EncabezadoSeccion(
            titulo: 'Gastos del negocio',
            descripcion:
                'Servicios, alquiler, limpieza y otros. Los pagos parciales conservan su moneda.',
            accion: BotonSeguro(
              onPressed: _monedas.isEmpty ? null : _crear,
              icon: const Icon(Icons.add),
              child: const Text('Nuevo gasto'),
            ),
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else if (_gastos.isEmpty)
            const SectionCard(child: Text('Aún no se han registrado gastos.'))
          else
            ..._gastos.map(_tarjetaGasto),
        ],
      ),
    );
  }

  Widget _tarjetaGasto(Map<String, dynamic> gasto) {
    final pagos = (gasto['pagos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final estado = gasto['estado'] as String? ?? 'pendiente';
    final moneda = gasto['moneda_codigo'] as String? ?? 'BOB';
    final pagado = pagos.fold<double>(
      0,
      (total, pago) => total + _aNumero(pago['monto']),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gasto['concepto'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('${_categoria(gasto['categoria'])} · $estado'),
                    ],
                  ),
                ),
                Text(
                  '$moneda ${_numero(gasto['monto'])}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pagado: $moneda ${pagado.toStringAsFixed(2)} · '
              'Pendiente: Bs ${_numero(gasto['saldo_pendiente_bob'])}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            if (estado == 'pendiente') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  BotonSeguro(
                    variante: VarianteBoton.outlined,
                    onPressed: () => _pagar(gasto),
                    icon: const Icon(Icons.payments_outlined),
                    child: const Text('Registrar pago'),
                  ),
                  if (pagos.isEmpty)
                    BotonSeguro(
                      variante: VarianteBoton.text,
                      onPressed: () => _anular(gasto),
                      icon: const Icon(Icons.block_outlined),
                      child: const Text('Anular'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GastoFormulario {
  final String categoria;
  final String concepto;
  final String moneda;
  final double monto;
  final double tipoCambioExt;
  final double tipoCambioBob;
  final String? numeroDocumento;
  final String? periodoDesde;
  final String? periodoHasta;

  const _GastoFormulario({
    required this.categoria,
    required this.concepto,
    required this.moneda,
    required this.monto,
    required this.tipoCambioExt,
    required this.tipoCambioBob,
    required this.numeroDocumento,
    required this.periodoDesde,
    required this.periodoHasta,
  });
}

class _GastoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> monedas;

  const _GastoDialog({required this.monedas});

  @override
  State<_GastoDialog> createState() => _GastoDialogState();
}

class _GastoDialogState extends State<_GastoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  final _tipoCambioExt = TextEditingController(text: '1');
  final _tipoCambioBob = TextEditingController(text: '6.96');
  final _documento = TextEditingController();
  final _desde = TextEditingController();
  final _hasta = TextEditingController();
  String _categoria = 'servicio';
  String _moneda = 'BOB';

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    _tipoCambioExt.dispose();
    _tipoCambioBob.dispose();
    _documento.dispose();
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  int _decimales() {
    return widget.monedas
            .where((moneda) => moneda['codigo'] == _moneda)
            .map((moneda) => moneda['decimales'] as int? ?? 2)
            .firstOrNull ??
        2;
  }

  Future<void> _elegirFecha(TextEditingController controller) async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      controller.text =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final codigos = widget.monedas
        .map((moneda) => moneda['codigo'] as String)
        .toList();
    if (!codigos.contains(_moneda) && codigos.isNotEmpty) {
      _moneda = codigos.first;
    }
    return AlertDialog(
      title: const Text('Registrar gasto'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(
                      value: 'servicio',
                      child: Text('Servicio: agua, luz, internet'),
                    ),
                    DropdownMenuItem(
                      value: 'alquiler',
                      child: Text('Alquiler'),
                    ),
                    DropdownMenuItem(
                      value: 'insumo_limpieza',
                      child: Text('Insumos de limpieza'),
                    ),
                    DropdownMenuItem(
                      value: 'mantenimiento',
                      child: Text('Mantenimiento'),
                    ),
                    DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _categoria = value);
                  },
                ),
                TextFormField(
                  controller: _concepto,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Concepto'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el concepto'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _moneda,
                  decoration: const InputDecoration(labelText: 'Moneda'),
                  items: widget.monedas
                      .map(
                        (moneda) => DropdownMenuItem(
                          value: moneda['codigo'] as String,
                          child: Text(
                            '${moneda['codigo']} · ${moneda['nombre']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _moneda = value);
                    if (value == 'BOB') {
                      _tipoCambioExt.text = _tipoCambioBob.text;
                    } else if (value == 'USD') {
                      _tipoCambioExt.text = '1';
                    }
                  },
                ),
                TextFormField(
                  controller: _monto,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: 'Importe ($_moneda)'),
                  validator: (value) {
                    final monto = double.tryParse(value ?? '');
                    if (monto == null || monto <= 0) return 'Importe inválido';
                    final decimales =
                        value!.split('.').elementAtOrNull(1)?.length ?? 0;
                    return decimales > _decimales()
                        ? 'Esta moneda admite ${_decimales()} decimales'
                        : null;
                  },
                ),
                if (_moneda != 'BOB')
                  TextFormField(
                    controller: _tipoCambioExt,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _moneda == 'USD'
                          ? 'Tipo de cambio externo (USD = 1)'
                          : 'Unidades de $_moneda por USD',
                    ),
                    validator: (value) {
                      final tasa = double.tryParse(value ?? '');
                      if (tasa == null || tasa <= 0) return 'Tasa inválida';
                      if (_moneda == 'USD' && tasa != 1) {
                        return 'Para USD, esta tasa debe ser 1';
                      }
                      return null;
                    },
                  ),
                TextFormField(
                  controller: _tipoCambioBob,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _moneda == 'BOB'
                        ? 'Tipo de cambio BOB por USD'
                        : 'Bolivianos por dólar (tipo de cambio BOB/USD)',
                  ),
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? 'Ingresa un tipo de cambio válido'
                      : null,
                ),
                TextFormField(
                  controller: _documento,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'N.º de factura/recibo (opcional)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _desde,
                        readOnly: true,
                        onTap: () => _elegirFecha(_desde),
                        decoration: const InputDecoration(
                          labelText: 'Período desde',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _hasta,
                        readOnly: true,
                        onTap: () => _elegirFecha(_hasta),
                        decoration: const InputDecoration(
                          labelText: 'Período hasta',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_desde.text.isNotEmpty &&
                _hasta.text.isNotEmpty &&
                _hasta.text.compareTo(_desde.text) < 0) {
              _mensaje(
                context,
                'El fin del período no puede ser anterior al inicio.',
              );
              return;
            }
            final tcBob = double.parse(_tipoCambioBob.text);
            Navigator.pop(
              context,
              _GastoFormulario(
                categoria: _categoria,
                concepto: _concepto.text.trim(),
                moneda: _moneda,
                monto: double.parse(_monto.text),
                tipoCambioExt: _moneda == 'BOB'
                    ? tcBob
                    : double.parse(_tipoCambioExt.text),
                tipoCambioBob: tcBob,
                numeroDocumento: _documento.text,
                periodoDesde: _desde.text.isEmpty ? null : _desde.text,
                periodoHasta: _hasta.text.isEmpty ? null : _hasta.text,
              ),
            );
          },
          child: const Text('Guardar gasto'),
        ),
      ],
    );
  }
}

class _PagoFormulario {
  final double monto;
  final String metodo;
  final String? referencia;

  const _PagoFormulario(this.monto, this.metodo, this.referencia);
}

class _PagoGastoDialog extends StatefulWidget {
  final Map<String, dynamic> gasto;

  const _PagoGastoDialog({required this.gasto});

  @override
  State<_PagoGastoDialog> createState() => _PagoGastoDialogState();
}

class _PagoGastoDialogState extends State<_PagoGastoDialog> {
  final _monto = TextEditingController();
  final _referencia = TextEditingController();
  String _metodo = 'efectivo';

  @override
  void dispose() {
    _monto.dispose();
    _referencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gasto = widget.gasto;
    final pagos = (gasto['pagos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final restante = pagos.fold<double>(
      _aNumero(gasto['monto']),
      (saldo, pago) => saldo - _aNumero(pago['monto']),
    );
    final moneda = gasto['moneda_codigo'] as String? ?? 'BOB';
    return AlertDialog(
      scrollable: true,
      title: const Text('Registrar pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Saldo aproximado: $moneda ${restante.toStringAsFixed(2)}'),
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Importe a pagar ($moneda)'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _metodo,
            decoration: const InputDecoration(labelText: 'Método de pago'),
            items: const [
              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
              DropdownMenuItem(
                value: 'transferencia',
                child: Text('Transferencia'),
              ),
              DropdownMenuItem(value: 'qr', child: Text('QR')),
              DropdownMenuItem(value: 'otro', child: Text('Otro')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _metodo = value);
            },
          ),
          TextField(
            controller: _referencia,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Referencia (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            final monto = double.tryParse(_monto.text);
            if (monto == null || monto <= 0 || monto > restante) {
              _mensaje(
                context,
                'El pago debe ser mayor a cero y no superar el saldo.',
              );
              return;
            }
            Navigator.pop(
              context,
              _PagoFormulario(monto, _metodo, _referencia.text),
            );
          },
          child: const Text('Registrar pago'),
        ),
      ],
    );
  }
}

class _ReporteTab extends StatefulWidget {
  const _ReporteTab({super.key});

  @override
  State<_ReporteTab> createState() => _ReporteTabState();
}

class _ReporteTabState extends State<_ReporteTab> {
  late DateTime _inicio;
  late DateTime _fin;
  Map<String, dynamic>? _reporte;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _inicio = DateTime(ahora.year, ahora.month);
    _fin = ahora;
    _cargar();
  }

  String _iso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<void> _seleccionar(bool inicio) async {
    final fecha = inicio ? _inicio : _fin;
    final seleccion = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (seleccion == null) return;
    setState(() {
      if (inicio) {
        _inicio = seleccion;
      } else {
        _fin = seleccion;
      }
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final reporte = await context
          .read<OperacionesService>()
          .reporteFinanciero(fechaInicio: _iso(_inicio), fechaFin: _iso(_fin));
      if (!mounted) return;
      setState(() {
        _reporte = reporte;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _detalleError(error);
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Resumen del negocio',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Consulta ingresos y costos del período. Las utilidades son estimaciones contables.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _seleccionar(true),
                icon: const Icon(Icons.calendar_month),
                label: Text('Desde ${_iso(_inicio)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _seleccionar(false),
                icon: const Icon(Icons.event),
                label: Text('Hasta ${_iso(_fin)}'),
              ),
              FilledButton.icon(
                onPressed: _cargando || _fin.isBefore(_inicio) ? null : _cargar,
                icon: const Icon(Icons.query_stats),
                label: const Text('Calcular'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _ErrorPanel(mensaje: _error!, reintentar: _cargar)
          else if (_reporte != null)
            _tarjetasReporte(_reporte!),
        ],
      ),
    );
  }

  Widget _tarjetasReporte(Map<String, dynamic> r) {
    final completo = r['costo_historico_completo'] == true;
    final tarjetas = <Widget>[
      _ResultadoCard(
        titulo: 'Ventas netas',
        valor: _bs(r['ventas_netas_bob']),
        icono: Icons.point_of_sale,
      ),
      _ResultadoCard(
        titulo: 'Costo de productos vendidos',
        valor: completo ? _bs(r['costo_ventas_bob']) : 'No disponible',
        icono: Icons.inventory_2_outlined,
        detalle: completo
            ? null
            : '${r['detalles_sin_costo_historico']} líneas sin costo histórico.',
      ),
      _ResultadoCard(
        titulo: 'Ganancia bruta',
        valor: completo ? _bs(r['ganancia_bruta_bob']) : 'No disponible',
        icono: Icons.trending_up,
        destacado: true,
      ),
      _ResultadoCard(
        titulo: 'Gastos operativos',
        valor: _bs(r['gastos_operativos_bob']),
        icono: Icons.receipt_long_outlined,
      ),
      _ResultadoCard(
        titulo: 'Sueldos y bonos',
        valor: _bs(r['sueldos_y_bonos_bob']),
        icono: Icons.groups_outlined,
      ),
      _ResultadoCard(
        titulo: 'Utilidad operativa estimada',
        valor: _nullableBs(r['utilidad_operativa_bob']),
        icono: Icons.account_balance_outlined,
        destacado: true,
      ),
      _ResultadoCard(
        titulo: 'Utilidad neta estimada',
        valor: _nullableBs(r['utilidad_neta_estimada_bob']),
        icono: Icons.savings_outlined,
        destacado: true,
        detalle: 'Antes de impuestos y cargos no registrados.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final ancho = (constraints.maxWidth - (columnas - 1) * 10) / columnas;
        return Column(
          children: [
            Wrap(
              spacing: 10,
              children: [
                for (final tarjeta in tarjetas)
                  SizedBox(width: ancho, child: tarjeta),
              ],
            ),
            SectionCard(child: Text(r['nota'] as String? ?? '')),
          ],
        );
      },
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final bool destacado;
  final String? detalle;

  const _ResultadoCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    this.destacado = false,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          children: [
            Icon(icono, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo),
                  if (detalle != null)
                    Text(
                      detalle!,
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: destacado ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final Widget accion;

  const _EncabezadoSeccion({
    required this.titulo,
    required this.descripcion,
    required this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final encabezado = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(descripcion, style: TextStyle(color: Theme.of(context).hintColor)),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: encabezado),
                const SizedBox(width: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: accion,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [encabezado, const SizedBox(height: 10), accion],
            ),
    );
  }
}

class _EncabezadoSimple extends StatelessWidget {
  final String titulo;
  final String descripcion;

  const _EncabezadoSimple({required this.titulo, required this.descripcion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(descripcion, style: TextStyle(color: Theme.of(context).hintColor)),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String mensaje;
  final VoidCallback reintentar;

  const _ErrorPanel({required this.mensaje, required this.reintentar});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje),
          TextButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

Future<String?> _pedirMotivo(BuildContext context, String titulo) async {
  final controller = TextEditingController();
  final motivo = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(titulo),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 250,
        decoration: const InputDecoration(labelText: 'Motivo'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (controller.text.trim().length < 3) {
              _mensaje(context, 'Escribe un motivo de al menos 3 caracteres.');
              return;
            }
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return motivo;
}

void _mensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

String _detalleError(Object error) {
  if (error is ApiException) return error.detalle;
  final texto = error.toString();
  final marcador = 'Error HTTP ';
  if (texto.startsWith(marcador) && texto.contains(':')) {
    return texto.substring(texto.indexOf(':') + 2);
  }
  return texto;
}

double _aNumero(dynamic valor) =>
    valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0;

String _numero(dynamic valor) => _aNumero(valor).toStringAsFixed(2);

String _bs(dynamic valor) => 'Bs ${_numero(valor)}';

String _nullableBs(dynamic valor) =>
    valor == null ? 'No disponible' : _bs(valor);

String _nombreBono(dynamic tipo) => switch (tipo) {
  'live' => 'Bono por lives',
  'almuerzo' => 'Bono de almuerzo',
  'navidad' => 'Bono de Navidad',
  _ => 'Otro bono',
};

String _categoria(dynamic categoria) => switch (categoria) {
  'servicio' => 'Servicio',
  'alquiler' => 'Alquiler',
  'insumo_limpieza' => 'Insumos de limpieza',
  'mantenimiento' => 'Mantenimiento',
  _ => 'Otro',
};
