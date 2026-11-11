import '../../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/detection_record.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../productos/presentation/movimiento_dialog.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _busqueda = TextEditingController();

  // Filtros en memoria: el listado ya vive en memoria (se recarga al entrar),
  // asi que tipo/periodo/nombre se filtran aca sin ir al servidor por cada
  // tecla. Valores de _tipo y _periodo descritos abajo.
  String _tipo = 'todos';
  String _periodo = 'todo';

  // Los tres movimientos que existen en la BD. 'ajuste' fija el stock en una
  // cifra exacta admitiendo cantidad 0, por eso su icono/color son propios
  // y no se le pinta el icono de salida como hacia la version anterior.
  static const _tipos = ['todos', 'entrada', 'salida', 'ajuste'];
  static const _tiposEtiqueta = {
    'todos': 'Todos',
    'entrada': 'Entradas',
    'salida': 'Salidas',
    'ajuste': 'Ajustes',
  };

  static const _periodos = ['todo', 'hoy', 'semana', 'mes'];
  static const _periodosEtiqueta = {
    'todo': 'Todo',
    'hoy': 'Hoy',
    'semana': '7 dias',
    'mes': '30 dias',
  };

  bool _pasaTipo(String? tipo) => _tipo == 'todos' || (tipo ?? '') == _tipo;

  bool _pasaFecha(String? creadoEn) {
    if (_periodo == 'todo') return true;
    if (creadoEn == null) return false;
    final fecha = DateTime.parse(creadoEn).toLocal();
    final ahora = DateTime.now();
    final desde = _periodo == 'hoy'
        ? DateTime(ahora.year, ahora.month, ahora.day)
        : ahora.subtract(Duration(days: _periodo == 'semana' ? 7 : 30));
    // Con isBefore invertido se acepta tambien el instante desde (>=).
    return !fecha.isBefore(desde);
  }

  bool _pasaTexto(Movimiento m) {
    final consulta = _busqueda.text.trim().toLowerCase();
    if (consulta.isEmpty) return true;
    final nombre = (m.productoNombre ?? '#${m.productoId}').toLowerCase();
    return nombre.contains(consulta);
  }

  bool _pasaTodo(Movimiento m) =>
      _pasaTipo(m.tipo) && _pasaFecha(m.creadoEn) && _pasaTexto(m);

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventarioProvider>().cargarHistorial();
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final inventario = context.read<InventarioProvider>();
    final guardado = await mostrarMovimientoLote(context);
    if (guardado == true) {
      await inventario.cargarHistorial();
      await inventario.cargarInventario();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final historial = inventario.historial;
    final filtrados = historial.where(_pasaTodo).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: BotonSeguro(
            onPressed: _registrar,
            icon: const Icon(Icons.playlist_add),
            child: const Text('Nuevo movimiento'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busqueda,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar producto',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () => inventario.cargarHistorial(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final tipo in _tipos)
                    DropdownMenuItem(value: tipo, child: Text(_tiposEtiqueta[tipo]!)),
                ],
                onChanged: (tipo) {
                  if (tipo != null) setState(() => _tipo = tipo);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _periodo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Período'),
                items: [
                  for (final periodo in _periodos)
                    DropdownMenuItem(value: periodo, child: Text(_periodosEtiqueta[periodo]!)),
                ],
                onChanged: (periodo) {
                  if (periodo != null) setState(() => _periodo = periodo);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${filtrados.length} movimiento(s)', style: TextStyle(color: context.textoSecundario, fontSize: 12)),
        const SizedBox(height: 16),
        if (inventario.cargando && historial.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (historial.isEmpty)
          const SectionCard(child: Text('Aun no hay movimientos registrados.'))
        else if (filtrados.isEmpty)
          // Lista con datos pero ningun registro con ese filtro: hay que
          // decirlo, porque "lista vacia" parece error o pagina sin cargar.
          SectionCard(
            child: Text(
              'Ningun movimiento cumple el filtro. Prueba con otro tipo, '
              'otro periodo o menos texto.',
              style: TextStyle(color: context.textoSecundario),
            ),
          )
        else ...filtrados.map(
          (m) {
            final esEntrada = m.tipo == 'entrada';
            final esAjuste = m.tipo == 'ajuste';
            final tono = esAjuste
                ? context.paleta.aviso
                : esEntrada
                    ? context.paleta.positivo
                    : context.paleta.negativo;
            final icono = esAjuste
                ? Icons.tune
                : esEntrada
                    ? Icons.south_west
                    : Icons.north_east;
            final accion = esAjuste
                ? 'Ajuste · stock ${m.stockResultante}'
                : '${esEntrada ? 'Entrada' : 'Salida'} de ${m.cantidad} '
                    '· stock ${m.stockResultante}';
            final relacionada = m.sucursalRelacionadaNombre;
            final razon = [
              m.razonNombre ?? 'Sin razón',
              if (relacionada != null) '${esEntrada ? 'desde' : 'hacia'} $relacionada',
              if (m.origen == 'ia') 'IA',
            ].join(' · ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tono.withValues(alpha: 0.18),
                      ),
                      child: Icon(icono, size: 17, color: tono),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.productoNombre ?? 'Producto #${m.productoId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            razon,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (m.creadoEn != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM HH:mm')
                            .format(DateTime.parse(m.creadoEn!).toLocal()),
                        style: TextStyle(
                          color: context.textoTerciario,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
