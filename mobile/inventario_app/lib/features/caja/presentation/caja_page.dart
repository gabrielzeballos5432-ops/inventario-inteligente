import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/sucursal_controller.dart';
import '../../../core/services/operaciones_service.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';

class CajaPage extends StatefulWidget {
  final bool esAdmin;

  const CajaPage({super.key, required this.esAdmin});

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  Map<String, dynamic>? _sesion;
  List<Map<String, dynamic>> _sesiones = [];
  bool _cargando = true;
  bool _guardando = false;
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
      final sesion = await service.obtenerCajaActual();
      final List<Map<String, dynamic>> sesiones = widget.esAdmin
          ? await service.listarSesionesCaja()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _sesion = sesion;
        _sesiones = sesiones;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _mensajeError(error);
        _cargando = false;
      });
    }
  }

  Future<void> _abrir() async {
    final inicial = await _pedirMonto(
      titulo: 'Abrir caja',
      etiqueta: 'Efectivo inicial en caja (Bs)',
      permitirCero: true,
    );
    if (inicial == null || !mounted) return;
    await _ejecutar(() async {
      await context.read<OperacionesService>().abrirCaja(inicial.monto);
      await _cargar();
    });
  }

  Future<void> _cerrar() async {
    final cierre = await _pedirMonto(
      titulo: 'Cerrar caja',
      etiqueta: 'Efectivo contado (Bs)',
      permitirCero: true,
      pedirNota: true,
    );
    if (cierre == null || !mounted) return;
    await _ejecutar(() async {
      final resultado = await context.read<OperacionesService>().cerrarCaja(
        efectivoContado: cierre.monto,
        observacion: cierre.nota,
      );
      if (!mounted) return;
      final diferencia =
          double.tryParse('${resultado['monto_diferencia_cierre']}') ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Caja cerrada. Diferencia: Bs ${diferencia.toStringAsFixed(2)}',
          ),
        ),
      );
      await _cargar();
    });
  }

  Future<({double monto, String? nota})?> _pedirMonto({
    required String titulo,
    required String etiqueta,
    required bool permitirCero,
    bool pedirNota = false,
  }) {
    return showDialog<({double monto, String? nota})>(
      context: context,
      builder: (_) => _DialogoMonto(
        titulo: titulo,
        etiqueta: etiqueta,
        permitirCero: permitirCero,
        pedirNota: pedirNota,
      ),
    );
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (error) {
      if (mounted) setState(() => _error = _mensajeError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _mensajeError(Object error) {
    if (error is ApiException) return error.detalle;
    final texto = error.toString();
    return texto.startsWith('Error HTTP')
        ? texto.substring(texto.indexOf(':') + 2)
        : 'No se pudo completar la operación. $texto';
  }

  String _dinero(dynamic valor) =>
      'Bs ${(double.tryParse('$valor') ?? 0).toStringAsFixed(2)}';

  String _fecha(dynamic fecha) {
    final valor = DateTime.tryParse(fecha?.toString() ?? '');
    if (valor == null) return '—';
    return '${valor.day.toString().padLeft(2, '0')}/'
        '${valor.month.toString().padLeft(2, '0')}/${valor.year} '
        '${valor.hour.toString().padLeft(2, '0')}:'
        '${valor.minute.toString().padLeft(2, '0')}';
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
            'Caja del día',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Controla el efectivo antes de vender y concilia al terminar.',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_sesion == null)
            _CajaCerrada(onAbrir: _guardando ? null : _abrir)
          else
            _CajaAbierta(
              sesion: _sesion!,
              fecha: _fecha(_sesion!['fecha_apertura']),
              dinero: _dinero,
              onCerrar: _guardando ? null : _cerrar,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SectionCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!)),
                  TextButton(
                    onPressed: _cargar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ],
          if (widget.esAdmin) ...[
            const SizedBox(height: 24),
            Text(
              'Sesiones recientes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_sesiones.isEmpty)
              const SectionCard(child: Text('Aún no hay sesiones de caja.'))
            else
              ..._sesiones.map(
                (sesion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    child: Row(
                      children: [
                        Icon(
                          sesion['estado'] == 'abierta'
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sesión #${sesion['id']} · ${sesion['estado']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_fecha(sesion['fecha_apertura'])}'
                                '${sesion['fecha_cierre'] == null ? '' : ' · Cierre ${_fecha(sesion['fecha_cierre'])}'}',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _dinero(
                            sesion['monto_esperado_cierre'] ??
                                sesion['monto_inicial'],
                          ),
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
}

class _DialogoMonto extends StatefulWidget {
  const _DialogoMonto({
    required this.titulo,
    required this.etiqueta,
    required this.permitirCero,
    required this.pedirNota,
  });

  final String titulo;
  final String etiqueta;
  final bool permitirCero;
  final bool pedirNota;

  @override
  State<_DialogoMonto> createState() => _DialogoMontoState();
}

class _DialogoMontoState extends State<_DialogoMonto> {
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _monto,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: widget.etiqueta),
              validator: (texto) {
                final valor = double.tryParse(texto ?? '');
                if (valor == null ||
                    valor < 0 ||
                    (!widget.permitirCero && valor == 0)) {
                  return widget.permitirCero
                      ? 'Ingresa un monto válido'
                      : 'El monto debe ser mayor a cero';
                }
                if (!RegExp(
                  r'^\d{1,10}([.]\d{1,2})?$',
                ).hasMatch(texto!.trim())) {
                  return 'Usa hasta 2 decimales';
                }
                return null;
              },
            ),
            if (widget.pedirNota)
              TextFormField(
                controller: _nota,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Observación del cierre (opcional)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, (
                monto: double.parse(_monto.text.trim()),
                nota: widget.pedirNota ? _nota.text.trim() : null,
              ));
            }
          },
          child: Text(widget.titulo),
        ),
      ],
    );
  }
}

class _CajaCerrada extends StatelessWidget {
  final Future<void> Function()? onAbrir;

  const _CajaCerrada({required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 34),
          const SizedBox(height: 12),
          Text(
            'Tu caja está cerrada',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text('Abre la caja con el efectivo inicial para comenzar.'),
          const SizedBox(height: 14),
          BotonSeguro(
            onPressed: onAbrir,
            icon: const Icon(Icons.lock_open_outlined),
            child: const Text('Abrir caja'),
          ),
        ],
      ),
    );
  }
}

class _CajaAbierta extends StatelessWidget {
  final Map<String, dynamic> sesion;
  final String fecha;
  final String Function(dynamic) dinero;
  final Future<void> Function()? onCerrar;

  const _CajaAbierta({
    required this.sesion,
    required this.fecha,
    required this.dinero,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_open, color: context.paleta.positivo),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Caja abierta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text('Sesión #${sesion['id']}')),
            ],
          ),
          Text('Abierta: $fecha'),
          ..._sucursalDeLaCaja(context, sesion),
          const SizedBox(height: 12),
          _DatoCaja(
            etiqueta: 'Efectivo inicial',
            valor: dinero(sesion['monto_inicial']),
          ),
          const SizedBox(height: 14),
          const Text(
            'Al cerrar, el sistema compara el efectivo contado con ventas en efectivo y pagos de gastos en efectivo.',
          ),
          const SizedBox(height: 14),
          BotonSeguro(
            variante: VarianteBoton.outlined,
            onPressed: onCerrar,
            icon: const Icon(Icons.lock_outline),
            child: const Text('Contar y cerrar caja'),
          ),
        ],
      ),
    );
  }
}

/// Sucursal de la caja abierta y, si no es la activa, un aviso: las ventas y
/// pagos en efectivo de esta sucursal no entran en una caja de otro local.
List<Widget> _sucursalDeLaCaja(
  BuildContext context,
  Map<String, dynamic> sesion,
) {
  final control = SucursalController.instance;
  final sucursalCaja = control.porId(sesion['sucursal_id'] as int?);
  if (sucursalCaja == null) return const [];
  final esOtra = control.activaId != null && sucursalCaja.id != control.activaId;
  return [
    const SizedBox(height: 4),
    Text('Sucursal: ${sucursalCaja.nombre}'),
    if (esOtra) ...[
      const SizedBox(height: 8),
      Text(
        'Esta caja es de ${sucursalCaja.nombre}. Las ventas en efectivo de '
        '${control.activa?.nombre ?? 'esta sucursal'} no se suman a ella: '
        'ciérrala y abre una aquí si vas a cobrar en este local.',
        style: TextStyle(color: context.paleta.stockBajo),
      ),
    ],
  ];
}

class _DatoCaja extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoCaja({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(etiqueta)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
