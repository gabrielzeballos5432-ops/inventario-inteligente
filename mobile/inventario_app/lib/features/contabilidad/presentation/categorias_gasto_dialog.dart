import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/categoria_gasto.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/operaciones_service.dart';
import '../../../shared/widgets/boton_seguro.dart';

String _detalle(Object error) => error is ApiException
    ? error.detalle
    : 'No se pudo completar la operación: $error';

class CategoriasGastoDialog extends StatefulWidget {
  const CategoriasGastoDialog({super.key});

  @override
  State<CategoriasGastoDialog> createState() => _CategoriasGastoDialogState();
}

class _CategoriasGastoDialogState extends State<CategoriasGastoDialog> {
  List<CategoriaGasto> _categorias = [];
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
      final categorias = await context
          .read<OperacionesService>()
          .listarCategoriasGasto();
      if (mounted) setState(() => _categorias = categorias);
    } catch (error) {
      if (mounted) setState(() => _error = _detalle(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([CategoriaGasto? categoria]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoriaGastoFormulario(categoria: categoria),
    );
    if (guardado == true && mounted) await _cargar();
  }

  Future<void> _eliminar(CategoriaGasto categoria) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Eliminar "${categoria.nombre}" de la lista? Los gastos anteriores '
          'se conservarán. Si vuelves a añadir el mismo nombre, se reactivará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await context.read<OperacionesService>().eliminarCategoriaGasto(
        categoria.id,
      );
      if (mounted) await _cargar();
    } catch (error) {
      if (mounted) setState(() => _error = _detalle(error));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Categorías de gasto'),
    scrollable: true,
    content: SizedBox(
      width: 850,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periodicidad e importe son independientes. El monto habitual es una sugerencia en Bs.',
          ),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
          if (_cargando)
            const LinearProgressIndicator()
          else if (_categorias.isEmpty)
            const Text('No hay categorías. Agrega la primera.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Categoría')),
                  DataColumn(label: Text('Periodicidad')),
                  DataColumn(label: Text('Importe')),
                  DataColumn(label: Text('Habitual (Bs)')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: [
                  for (final categoria in _categorias)
                    DataRow(
                      cells: [
                        DataCell(Text(categoria.nombre)),
                        DataCell(
                          Text(
                            CategoriaGasto.periodos[categoria.periodicidad]!,
                          ),
                        ),
                        DataCell(
                          Text(
                            categoria.tipoImporte == 'fijo'
                                ? 'Fijo'
                                : 'Variable',
                          ),
                        ),
                        DataCell(
                          Text(
                            categoria.montoHabitual?.toStringAsFixed(2) ?? '—',
                          ),
                        ),
                        DataCell(
                          Text(categoria.activo ? 'Activa' : 'Inactiva'),
                        ),
                        DataCell(
                          Row(
                            children: [
                              BotonIconoSeguro(
                                tooltip: 'Editar ${categoria.nombre}',
                                onPressed: () => _editar(categoria),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              if (categoria.activo)
                                BotonIconoSeguro(
                                  tooltip: 'Eliminar ${categoria.nombre}',
                                  onPressed: () => _eliminar(categoria),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
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
    actions: [
      BotonSeguro(
        onPressed: _cargando ? null : () => _editar(),
        child: const Text('Añadir categoría'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Listo'),
      ),
    ],
  );
}

class _CategoriaGastoFormulario extends StatefulWidget {
  const _CategoriaGastoFormulario({this.categoria});
  final CategoriaGasto? categoria;

  @override
  State<_CategoriaGastoFormulario> createState() =>
      _CategoriaGastoFormularioState();
}

class _CategoriaGastoFormularioState extends State<_CategoriaGastoFormulario> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _monto;
  late String _periodicidad;
  late String _tipo;
  late bool _activo;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final categoria = widget.categoria;
    _nombre = TextEditingController(text: categoria?.nombre);
    _monto = TextEditingController(
      text: categoria?.montoHabitual?.toStringAsFixed(2),
    );
    _periodicidad = categoria?.periodicidad ?? 'sin_periodicidad';
    _tipo = categoria?.tipoImporte ?? 'variable';
    _activo = categoria?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await context.read<OperacionesService>().guardarCategoriaGasto(
        id: widget.categoria?.id,
        nombre: _nombre.text,
        periodicidad: _periodicidad,
        tipoImporte: _tipo,
        montoHabitual: _tipo == 'fijo' && _monto.text.trim().isNotEmpty
            ? double.parse(_monto.text.trim().replaceAll(',', '.'))
            : null,
        activo: _activo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _detalle(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.categoria == null
          ? 'Añadir categoría de gasto'
          : 'Editar categoría de gasto',
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (valor) => valor == null || valor.trim().isEmpty
                  ? 'Escribe el nombre'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _periodicidad,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Periodicidad'),
              items: [
                for (final periodo in CategoriaGasto.periodos.entries)
                  DropdownMenuItem(
                    value: periodo.key,
                    child: Text(periodo.value),
                  ),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) => setState(() => _periodicidad = valor!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de importe'),
              items: const [
                DropdownMenuItem(value: 'fijo', child: Text('Fijo')),
                DropdownMenuItem(value: 'variable', child: Text('Variable')),
              ],
              onChanged: _guardando
                  ? null
                  : (valor) => setState(() => _tipo = valor!),
            ),
            if (_tipo == 'fijo')
              TextFormField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto habitual (Bs, opcional)',
                ),
                validator: (valor) {
                  final texto = (valor ?? '').trim().replaceAll(',', '.');
                  if (texto.isEmpty) return null;
                  return RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(texto) &&
                          (double.tryParse(texto) ?? 0) > 0
                      ? null
                      : 'Usa un monto mayor a 0 con hasta 2 decimales';
                },
              ),
            if (widget.categoria != null)
              SwitchListTile(
                title: const Text('Activa'),
                value: _activo,
                onChanged: _guardando
                    ? null
                    : (valor) => setState(() => _activo = valor),
              ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      BotonSeguro(
        onPressed: _guardando ? null : _guardar,
        child: Text(_guardando ? 'Guardando…' : 'Guardar categoría'),
      ),
    ],
  );
}
