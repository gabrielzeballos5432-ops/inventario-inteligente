import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/proveedor.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/validaciones.dart';

/// Gestion del catalogo de proveedores.
///
/// A diferencia de marcas, el proveedor tiene datos de contacto (persona,
/// telefono y correo). Todos son opcionales menos el nombre, y se envian como
/// null cuando quedan en blanco: el backend los normaliza a NULL y no a "".
class ProveedoresDialog extends StatefulWidget {
  const ProveedoresDialog();

  @override
  State<ProveedoresDialog> createState() => ProveedoresDialogState();
}

class ProveedoresDialogState extends State<ProveedoresDialog> {
  final _service = CatalogService(ApiClient());
  final _nombreController = TextEditingController();
  final _contactoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  late Future<List<Proveedor>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchProveedores();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _service.fetchProveedores());
  }

  void _limpiarCampos() {
    _nombreController.clear();
    _contactoController.clear();
    _telefonoController.clear();
    _emailController.clear();
  }

  static String _motivo(Object e) => e is ApiException ? e.detalle : '$e';

  Future<void> _crear() async {
    final error = Validaciones.nombreSinNumeros(_nombreController.text) ??
        Validaciones.telefono(_telefonoController.text) ??
        Validaciones.correo(_emailController.text, obligatorio: false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final nombre = _nombreController.text.trim();
    try {
      await _service.createProveedor(
        nombre: nombre,
        contacto: _contactoController.text,
        telefono: _telefonoController.text,
        email: _emailController.text,
      );
      _limpiarCampos();
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear: ${_motivo(e)}')),
      );
    }
  }

  Future<void> _editar(Proveedor p) async {
    final nombreC = TextEditingController(text: p.nombre);
    final contactoC = TextEditingController(text: p.contacto ?? '');
    final telefonoC = TextEditingController(text: p.telefono ?? '');
    final emailC = TextEditingController(text: p.email ?? '');

    final formKey = GlobalKey<FormState>();
    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar proveedor'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreC,
                  autofocus: true,
                  validator: Validaciones.nombreSinNumeros,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactoC,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? null
                      : Validaciones.nombreSinNumeros(v),
                  decoration: const InputDecoration(
                    labelText: 'Persona de contacto',
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoC,
                  keyboardType: TextInputType.phone,
                  validator: Validaciones.telefono,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailC,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      Validaciones.correo(v, obligatorio: false),
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    errorMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    // Se liberan en el siguiente frame: tras el pop queda un frame de
    // animacion de salida que referencia los controladores.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombreC.dispose();
      contactoC.dispose();
      telefonoC.dispose();
      emailC.dispose();
    });

    if (guardado != true) return;
    final nombre = nombreC.text.trim();
    if (nombre.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del proveedor es obligatorio')),
      );
      return;
    }
    try {
      await _service.actualizarProveedor(
        p.id,
        nombre: nombre,
        contacto: contactoC.text,
        telefono: telefonoC.text,
        email: emailC.text,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${_motivo(e)}')),
      );
    }
  }

  Future<void> _desactivar(Proveedor p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar proveedor'),
        content: Text(
          'El proveedor "${p.nombre}" dejara de aparecer al registrar o '
          'editar productos. Los productos que ya lo usan no se modifican.',
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
      await _service.desactivarProveedor(p.id);
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
      title: const Text('Gestionar proveedores'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del proveedor *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contactoController,
                    decoration:
                        const InputDecoration(labelText: 'Contacto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefono'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _crear,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Desactivar no borra el nombre: si vuelves a escribir el de un '
              'proveedor desactivado, este se reactiva.',
              style: TextStyle(color: context.textoTerciario, fontSize: 11),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Proveedor>>(
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
                          'No se pudieron cargar los proveedores.',
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
                final proveedores = snapshot.data ?? const <Proveedor>[];
                if (proveedores.isEmpty) {
                  return Text(
                    'No hay proveedores. El campo es opcional en el producto.',
                  );
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: proveedores
                        .map((p) => ListTile(
                              dense: true,
                              title: Text(p.nombre),
                              subtitle: p.lineaContacto.isEmpty
                                  ? null
                                  : Text(
                                      p.lineaContacto,
                                      style: TextStyle(
                                          color: context.textoTerciario, fontSize: 11),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar proveedor',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editar(p),
                                  ),
                                  IconButton(
                                    tooltip: 'Desactivar proveedor',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _desactivar(p),
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