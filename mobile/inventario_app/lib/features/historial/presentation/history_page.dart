import '../../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/detection_record.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';

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
      context.read<InventarioProvider>().cargarHistorial();
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Widget _chip(String valor, Map<String, String> etiquetas, bool esPeriodo) {
    final seleccionado = esPeriodo ? _periodo == valor : _tipo == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(etiquetas[valor] ?? valor),
        selected: seleccionado,
        onSelected: (_) => setState(
          () => esPeriodo ? _periodo = valor : _tipo = valor,
        ),
        visualDensity: VisualDensity.compact,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final historial = inventario.historial;
    final filtrados = historial.where(_pasaTodo).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
        // Dos filas de chips de eleccion: la de arriba cambia el tipo, la de
        // abajo el periodo. En telefono ambos Wraps parten en dos lineas
        // cuando no caben los cuatro, sin scroll horizontal.
        Wrap(
          spacing: 0,
          runSpacing: 8,
          children: _tipos.map((t) => _chip(t, _tiposEtiqueta, false)).toList(),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 0,
          runSpacing: 8,
          children: _periodos
              .map((p) => _chip(p, _periodosEtiqueta, true))
              .toList(),
        ),
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
                    '· stock ${m.stockResultante}'
                    '${m.origen != null ? ' · ${m.origen}' : ''}';

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
