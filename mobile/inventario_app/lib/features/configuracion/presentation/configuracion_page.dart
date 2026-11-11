import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/sucursal.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/configuracion_service.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../../shared/widgets/section_card.dart';

const _tiposMovimiento = {
  'entrada': 'Entrada',
  'salida': 'Salida',
  'ajuste': 'Ajuste',
};

String _motivo(Object e) => e is ApiException ? e.detalle : '$e';

String? _nombreObligatorio(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'Escribe un nombre.' : null;

/// Configuración del sistema (solo administrador): sucursal predeterminada,
/// catálogo de sucursales y razones de los movimientos de inventario.
class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key, required this.alCambiarSucursales});

  /// Se llama al crear, editar o desactivar sucursales o razones, o al cambiar
  /// la predeterminada: el selector de la barra y el formulario de
  /// movimientos tienen que ver los datos nuevos.
  final Future<void> Function() alCambiarSucursales;

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  late final ConfiguracionService _servicio;
  List<Sucursal> _sucursales = const [];
  List<RazonMovimiento> _razones = const [];
  int? _predeterminadaId;
  int? _predeterminadaElegida;
  String _tipoRazon = 'entrada';
  bool _cargando = true;
  bool _guardandoPredeterminada = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _servicio = context.read<ConfiguracionService>();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        _servicio.fetchSucursales(incluirInactivas: true),
        _servicio.fetchSucursalPredeterminadaId(),
        _servicio.fetchRazones(incluirInactivas: true),
      ]);
      if (!mounted) return;
      setState(() {
        _sucursales = resultados[0] as List<Sucursal>;
        _predeterminadaId = resultados[1] as int;
        _predeterminadaElegida = _predeterminadaId;
        _razones = resultados[2] as List<RazonMovimiento>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la configuración: ${_motivo(e)}';
        _cargando = false;
      });
    }
  }

  /// Recarga la página y avisa al resto de la app.
  Future<void> _refrescar() async {
    await _cargar();
    await widget.alCambiarSucursales();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardarPredeterminada() async {
    final id = _predeterminadaElegida;
    if (id == null || id == _predeterminadaId || _guardandoPredeterminada) return;
    setState(() => _guardandoPredeterminada = true);
    try {
      await _servicio.definirSucursalPredeterminada(id);
      _avisar('Sucursal predeterminada actualizada.');
      await _refrescar();
    } catch (e) {
      _avisar('No se pudo guardar: ${_motivo(e)}');
    }
    if (mounted) setState(() => _guardandoPredeterminada = false);
  }

  Future<void> _editarSucursal([Sucursal? sucursal]) async {
    final datos = await showDialog<({String nombre, String direccion, String telefono})>(
      context: context,
      builder: (_) => _SucursalDialog(sucursal: sucursal),
    );
    if (datos == null) return;
    try {
      if (sucursal == null) {
        await _servicio.crearSucursal(
          nombre: datos.nombre,
          direccion: datos.direccion,
          telefono: datos.telefono,
        );
        _avisar('Sucursal "${datos.nombre}" registrada.');
      } else {
        await _servicio.actualizarSucursal(
          sucursal.id,
          nombre: datos.nombre,
          direccion: datos.direccion,
          telefono: datos.telefono,
        );
        _avisar('Sucursal actualizada.');
      }
      await _refrescar();
    } catch (e) {
      _avisar('No se pudo guardar la sucursal: ${_motivo(e)}');
    }
  }

  Future<void> _alternarSucursal(Sucursal sucursal) async {
    try {
      await _servicio.actualizarSucursal(sucursal.id, activo: !sucursal.activo);
      _avisar(sucursal.activo
          ? 'Sucursal "${sucursal.nombre}" desactivada.'
          : 'Sucursal "${sucursal.nombre}" activada.');
      await _refrescar();
    } catch (e) {
      _avisar(_motivo(e));
    }
  }

  Future<void> _editarRazon([RazonMovimiento? razon]) async {
    final datos = await showDialog<({String nombre, bool destino})>(
      context: context,
      builder: (_) => _RazonDialog(razon: razon, tipo: razon?.tipoMovimiento ?? _tipoRazon),
    );
    if (datos == null) return;
    try {
      if (razon == null) {
        await _servicio.crearRazon(
          nombre: datos.nombre,
          tipoMovimiento: _tipoRazon,
          requiereSucursalDestino: datos.destino,
        );
        _avisar('Razón "${datos.nombre}" registrada.');
      } else {
        await _servicio.actualizarRazon(
          razon.id,
          nombre: datos.nombre,
          requiereSucursalDestino: datos.destino,
        );
        _avisar('Razón actualizada.');
      }
      await _refrescar();
    } catch (e) {
      _avisar('No se pudo guardar la razón: ${_motivo(e)}');
    }
  }

  Future<void> _alternarRazon(RazonMovimiento razon) async {
    try {
      await _servicio.actualizarRazon(razon.id, activo: !razon.activo);
      await _refrescar();
    } catch (e) {
      _avisar(_motivo(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _sucursales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sucursales.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionCard(
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: context.paleta.stockBajo),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }

    final activas = _sucursales.where((s) => s.activo).toList();
    final razonesTipo =
        _razones.where((r) => r.tipoMovimiento == _tipoRazon).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _titulo(context, 'Sucursal predeterminada'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cada sesión arranca en esta sucursal y los vendedores operan '
                  'siempre en ella. El administrador puede cambiar de sucursal '
                  'desde la barra superior.',
                  style: TextStyle(color: context.textoSecundario),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(_predeterminadaId),
                  initialValue: activas.any((s) => s.id == _predeterminadaElegida)
                      ? _predeterminadaElegida
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sucursal predeterminada'),
                  items: [
                    for (final sucursal in activas)
                      DropdownMenuItem(value: sucursal.id, child: Text(sucursal.nombre)),
                  ],
                  onChanged: (id) => setState(() => _predeterminadaElegida = id),
                ),
                const SizedBox(height: 12),
                BotonSeguro(
                  onPressed: _predeterminadaElegida == _predeterminadaId ||
                          _guardandoPredeterminada
                      ? null
                      : _guardarPredeterminada,
                  child: Text(_guardandoPredeterminada ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _titulo(context, 'Sucursales')),
              BotonSeguro(
                onPressed: () => _editarSucursal(),
                icon: const Icon(Icons.add),
                child: const Text('Nueva sucursal'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final sucursal in _sucursales)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: sucursal.activo ? null : context.textoTerciario,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sucursal.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: sucursal.activo ? null : context.textoTerciario,
                            ),
                          ),
                          Text(
                            [
                              if (sucursal.id == _predeterminadaId) 'Predeterminada',
                              if (!sucursal.activo) 'Inactiva',
                              if ((sucursal.direccion ?? '').isNotEmpty) sucursal.direccion!,
                              if ((sucursal.telefono ?? '').isNotEmpty) sucursal.telefono!,
                            ].join(' · '),
                            style: TextStyle(color: context.textoSecundario, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar ${sucursal.nombre}',
                      onPressed: () => _editarSucursal(sucursal),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    // La predeterminada no se puede desactivar (primero hay
                    // que elegir otra; el backend también lo rechaza). Un
                    // interruptor bloqueado se leía como "apagado", así que
                    // en su lugar va una etiqueta explícita.
                    if (sucursal.id == _predeterminadaId)
                      Tooltip(
                        message: 'Para desactivarla, elige otra sucursal '
                            'predeterminada.',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: context.textoSecundario,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Siempre\nactiva',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Switch(
                        value: sucursal.activo,
                        onChanged: (_) => _alternarSucursal(sucursal),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _titulo(context, 'Razones de movimiento')),
              BotonSeguro(
                onPressed: () => _editarRazon(),
                icon: const Icon(Icons.add),
                child: const Text('Nueva razón'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Son obligatorias al registrar un movimiento manual. Ventas, compras, '
            'anulaciones, stock inicial y traspasos reciben su razón solos.',
            style: TextStyle(color: context.textoSecundario, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final tipo in _tiposMovimiento.entries)
                ButtonSegment(value: tipo.key, label: Text(tipo.value)),
            ],
            selected: {_tipoRazon},
            onSelectionChanged: (s) => setState(() => _tipoRazon = s.first),
          ),
          const SizedBox(height: 10),
          if (razonesTipo.isEmpty)
            const SectionCard(child: Text('No hay razones para este tipo.'))
          else
            for (final razon in razonesTipo)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              razon.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: razon.activo ? null : context.textoTerciario,
                              ),
                            ),
                            if (razon.requiereSucursalDestino || !razon.activo)
                              Text(
                                [
                                  if (razon.requiereSucursalDestino)
                                    'Envía a otra sucursal',
                                  if (!razon.activo) 'Inactiva',
                                ].join(' · '),
                                style: TextStyle(
                                  color: context.textoSecundario,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar ${razon.nombre}',
                        onPressed: () => _editarRazon(razon),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      Switch(
                        value: razon.activo,
                        onChanged: (_) => _alternarRazon(razon),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Botones a lo ancho dentro del contenido (ver AGENTS.md: los `actions` del
/// diálogo quedan diminutos en el teléfono).
Widget _botonesDialogo(BuildContext context, VoidCallback alGuardar) => Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
        child: const Text('Cancelar'),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: BotonSeguro(
        onPressed: alGuardar,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
        child: const Text('Guardar'),
      ),
    ),
  ],
);

class _SucursalDialog extends StatefulWidget {
  const _SucursalDialog({this.sucursal});

  final Sucursal? sucursal;

  @override
  State<_SucursalDialog> createState() => _SucursalDialogState();
}

class _SucursalDialogState extends State<_SucursalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.sucursal?.nombre ?? '');
  late final _direccion = TextEditingController(text: widget.sucursal?.direccion ?? '');
  late final _telefono = TextEditingController(text: widget.sucursal?.telefono ?? '');

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      nombre: _nombre.text.trim(),
      direccion: _direccion.text.trim(),
      telefono: _telefono.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.sucursal == null ? 'Nueva sucursal' : 'Editar sucursal'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          // Con autofocus el teclado resta alto: sin scroll, la franja de
          // desbordamiento aparece al abrir el diálogo en el teléfono.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Nombre', errorMaxLines: 2),
                  validator: _nombreObligatorio,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _direccion,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _telefono,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                  onFieldSubmitted: (_) => _guardar(),
                ),
                const SizedBox(height: 16),
                _botonesDialogo(context, _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RazonDialog extends StatefulWidget {
  const _RazonDialog({this.razon, required this.tipo});

  final RazonMovimiento? razon;
  final String tipo;

  @override
  State<_RazonDialog> createState() => _RazonDialogState();
}

class _RazonDialogState extends State<_RazonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.razon?.nombre ?? '');
  late bool _destino = widget.razon?.requiereSucursalDestino ?? false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((nombre: _nombre.text.trim(), destino: _destino));
  }

  @override
  Widget build(BuildContext context) {
    final tipo = _tiposMovimiento[widget.tipo] ?? widget.tipo;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.razon == null ? 'Nueva razón de $tipo' : 'Editar razón'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombre,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Nombre', errorMaxLines: 2),
                  validator: _nombreObligatorio,
                  onFieldSubmitted: (_) => _guardar(),
                ),
                Text(
                  'Tipo: $tipo. El tipo no se cambia después de crearla.',
                  style: TextStyle(color: context.textoSecundario, fontSize: 12),
                ),
                if (widget.tipo == 'salida')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _destino,
                    onChanged: (v) => setState(() => _destino = v),
                    title: const Text('Envía a otra sucursal'),
                    subtitle: const Text(
                      'Pide la sucursal destino y registra allí la entrada.',
                    ),
                  ),
                const SizedBox(height: 16),
                _botonesDialogo(context, _guardar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
