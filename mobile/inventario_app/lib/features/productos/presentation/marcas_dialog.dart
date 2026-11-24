import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marca.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/mensaje_error.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/catalogo_view.dart';
import '../../../shared/widgets/section_card.dart';

/// Gestion del catalogo de marcas.
///
/// Mismo criterio que el dialogo de categorias: el borrado es logico y el
/// nombre sigue reservado, asi que escribir el nombre de una marca
/// desactivada la reactiva en lugar de crear otra.
class MarcasPage extends StatefulWidget {
  const MarcasPage({super.key, this.service});

  /// Inyectable para los tests; por defecto usa el cliente de la app.
  final CatalogService? service;

  @override
  State<MarcasPage> createState() => MarcasPageState();
}

class MarcasPageState extends State<MarcasPage> {
  late final CatalogService _service =
      widget.service ?? CatalogService(ApiClient());
  List<Marca>? _marcas;
  Object? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Consulta la lista sin vaciar la que ya se ve.
  ///
  /// Antes era `setState(() => _future = fetch())`: la flecha devuelve el
  /// Future y Flutter lanza "setState() callback argument returned a Future"
  /// en modo depuracion. Ese error caia en el catch de crear y la app
  /// mostraba "No se pudo crear la marca" aunque el API ya la habia guardado,
  /// y la lista no se refrescaba.
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final marcas = await _service.fetchMarcas();
      if (!mounted) return;
      setState(() {
        _marcas = marcas;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Pone la marca guardada en la lista al instante y luego confirma con el
  /// servidor, para que aparezca aunque la recarga tarde o falle.
  void _aplicar(Marca guardada) {
    final lista = [...?_marcas]..removeWhere((m) => m.id == guardada.id);
    lista
      ..add(guardada)
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    setState(() => _marcas = lista);
    _cargar();
  }

  Future<void> _formulario({Marca? actual}) async {
    final nombre = TextEditingController(text: actual?.nombre ?? '');
    final guardada = await mostrarFormularioCatalogo<Marca>(
      context: context,
      titulo: actual == null ? 'Registrar marca' : 'Renombrar marca',
      textoGuardar: actual == null ? 'Registrar' : 'Guardar',
      campos: (enviar) => [
        TextFormField(
          controller: nombre,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          validator: Validaciones.nombreSinNumeros,
          onFieldSubmitted: (_) => enviar(),
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            errorMaxLines: 2,
          ),
        ),
      ],
      guardar: () {
        final texto = nombre.text.trim();
        if (actual == null) return _service.createMarca(texto);
        if (texto == actual.nombre) return Future.value(actual);
        return _service.renombrarMarca(actual.id, texto);
      },
    );
    // Tras el pop queda un frame de animacion que aun usa el controlador.
    WidgetsBinding.instance.addPostFrameCallback((_) => nombre.dispose());
    if (guardada == null || !mounted) return;
    _aplicar(guardada);
    avisoCatalogo(
      context,
      actual == null
          ? 'Marca registrada: ${guardada.nombre}'
          : 'Marca actualizada: ${guardada.nombre}',
    );
  }

  Future<void> _desactivar(Marca m) async {
    final ok = await confirmarDesactivar(
      context,
      titulo: 'Desactivar marca',
      mensaje:
          'La marca "${m.nombre}" dejará de aparecer al registrar o editar '
          'productos. Los productos que ya la usan no se modifican.',
    );
    if (!ok || !mounted) return;
    try {
      await _service.desactivarMarca(m.id);
      if (!mounted) return;
      setState(() => _marcas = [...?_marcas]..removeWhere((x) => x.id == m.id));
      avisoCatalogo(context, 'Marca desactivada: ${m.nombre}');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      avisoCatalogo(context, 'No se pudo desactivar: ${mensajeDeError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogoView<Marca>(
      descripcion: 'Administra las marcas disponibles para clasificar productos.',
      items: _marcas,
      error: _error,
      cargando: _cargando,
      onRecargar: _cargar,
      onRegistrar: () => _formulario(),
      textoBusqueda: (m) => m.nombre,
      textoVacio: 'No hay marcas registradas.\nUsa "Registrar" para crear la primera.',
      etiquetaTotal: (n) => n == 1 ? '1 marca' : '$n marcas',
      icono: Icons.sell_outlined,
      notaPie:
          'Desactivar no borra el nombre: si vuelves a registrar una marca '
          'desactivada, se reactiva.',
      itemBuilder: (context, m) => SectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _formulario(actual: m),
          child: Row(
            children: [
              _Inicial(m.nombre),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  m.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _MenuAcciones(
                alEditar: () => _formulario(actual: m),
                alDesactivar: () => _desactivar(m),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circulo con la inicial del nombre, compartido por marcas y proveedores.
class _Inicial extends StatelessWidget {
  const _Inicial(this.nombre);
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final letra = nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: esquema.primaryContainer,
      foregroundColor: esquema.onPrimaryContainer,
      child: Text(letra, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MenuAcciones extends StatelessWidget {
  const _MenuAcciones({required this.alEditar, required this.alDesactivar});
  final VoidCallback alEditar;
  final VoidCallback alDesactivar;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      onSelected: (op) => op == 'editar' ? alEditar() : alDesactivar(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'editar',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'desactivar',
          child: ListTile(
            leading: Icon(Icons.block, color: context.paleta.negativo),
            title: const Text('Desactivar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
