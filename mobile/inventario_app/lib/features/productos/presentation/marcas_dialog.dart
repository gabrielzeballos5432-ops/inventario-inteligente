import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marca.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';

/// Gestion del catalogo de marcas.
///
/// Mismo criterio que el dialogo de categorias: el borrado es logico y el
/// nombre sigue reservado, asi que escribir el nombre de una marca
/// desactivada la reactiva en lugar de crear otra.
class MarcasPage extends StatefulWidget {
  const MarcasPage();

  @override
  State<MarcasPage> createState() => MarcasPageState();
}

class MarcasPageState extends State<MarcasPage> {
  final _service = CatalogService(ApiClient());
  final _nombreController = TextEditingController();
  late Future<List<Marca>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMarcas();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _service.fetchMarcas());
  }

  static String _motivo(Object e) => e is ApiException ? e.detalle : '$e';

  Future<void> _crear() async {
    final error = Validaciones.nombreSinNumeros(_nombreController.text);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final nombre = _nombreController.text.trim();
    try {
      await _service.createMarca(nombre);
      _nombreController.clear();
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la marca: ${_motivo(e)}')),
      );
    }
  }

  Future<void> _editar(Marca m) async {
    final controller = TextEditingController(text: m.nombre);
    final formKey = GlobalKey<FormState>();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Renombrar marca'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (nombre == null || nombre.isEmpty || nombre == m.nombre) return;
    try {
      await _service.renombrarMarca(m.id, nombre);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo renombrar: ${_motivo(e)}')),
      );
    }
  }

  Future<void> _desactivar(Marca m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Desactivar marca'),
        content: Text(
          'La marca "${m.nombre}" dejara de aparecer al registrar o editar '
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
      await _service.desactivarMarca(m.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo desactivar: ${_motivo(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Marca>>(
      future: _future,
      builder: (context, snapshot) {
        final marcas = snapshot.data ?? const <Marca>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Administra las marcas disponibles para clasificar productos.',
                    style: TextStyle(color: context.textoSecundario),
                  ),
                ),
                BotonSeguro(
                  onPressed: _abrirCrear,
                  icon: const Icon(Icons.add),
                  child: const Text('Registrar'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              SectionCard(
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: context.paleta.stockBajo),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('No se pudieron cargar las marcas.')),
                    TextButton(onPressed: _reload, child: const Text('Reintentar')),
                  ],
                ),
              )
            else if (marcas.isEmpty)
              const SectionCard(child: Text('No hay marcas registradas.'))
            else ...[
              SectionCard(
                child: Text('Total de marcas: ${marcas.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              ...marcas.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.sell_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(m.nombre)),
                        PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          onSelected: (opcion) {
                            if (opcion == 'editar') _editar(m);
                            if (opcion == 'desactivar') _desactivar(m);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'editar', child: Text('Editar')),
                            PopupMenuItem(value: 'desactivar', child: Text('Desactivar')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Desactivar no borra el nombre: si vuelves a registrar una marca desactivada, se reactiva.',
              style: TextStyle(color: context.textoTerciario, fontSize: 12),
            ),
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
        title: const Text('Registrar marca'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _nombreController,
            autofocus: true,
            validator: Validaciones.nombreSinNumeros,
            decoration: const InputDecoration(labelText: 'Nombre', errorMaxLines: 2),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          BotonSeguro(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (crear == true) await _crear();
  }
}
