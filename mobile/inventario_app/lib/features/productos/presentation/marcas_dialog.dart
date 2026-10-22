import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marca.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/validaciones.dart';

/// Gestion del catalogo de marcas.
///
/// Mismo criterio que el dialogo de categorias: el borrado es logico y el
/// nombre sigue reservado, asi que escribir el nombre de una marca
/// desactivada la reactiva en lugar de crear otra.
class MarcasDialog extends StatefulWidget {
  const MarcasDialog();

  @override
  State<MarcasDialog> createState() => MarcasDialogState();
}

class MarcasDialogState extends State<MarcasDialog> {
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
          FilledButton(
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
          FilledButton(
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
    return AlertDialog(
      title: const Text('Gestionar marcas'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nombreController,
                    decoration:
                        const InputDecoration(labelText: 'Nueva marca'),
                  ),
                ),
                IconButton(onPressed: _crear, icon: const Icon(Icons.add)),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Desactivar no borra el nombre: si vuelves a escribir el de una '
              'marca desactivada, esta se reactiva.',
              style: TextStyle(color: context.textoTerciario, fontSize: 11),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Marca>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Icon(Icons.cloud_off,
                          size: 16, color: context.paleta.stockBajo),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se pudieron cargar las marcas.',
                          style:
                              TextStyle(color: context.paleta.stockBajo, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                final marcas = snapshot.data ?? const <Marca>[];
                if (marcas.isEmpty) {
                  return const Text('No hay marcas.');
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: marcas
                        .map((m) => ListTile(
                              dense: true,
                              title: Text(m.nombre),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Renombrar marca',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editar(m),
                                  ),
                                  IconButton(
                                    tooltip: 'Desactivar marca',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _desactivar(m),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}