import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/proveedor.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';

/// Gestion del catalogo de proveedores.
///
/// A diferencia de marcas, el proveedor tiene datos de contacto (persona,
/// telefono y correo). Todos son opcionales menos el nombre, y se envian como
/// null cuando quedan en blanco: el backend los normaliza a NULL y no a "".
class ProveedoresPage extends StatefulWidget {
  const ProveedoresPage();

  @override
  State<ProveedoresPage> createState() => ProveedoresPageState();
}

class ProveedoresPageState extends State<ProveedoresPage> {
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
          BotonSeguro(
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
        scrollable: true,
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
          BotonSeguro(
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
    return FutureBuilder<List<Proveedor>>(
      future: _future,
      builder: (context, snapshot) {
        final proveedores = snapshot.data ?? const <Proveedor>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(child: Text('Administra los datos de contacto de los proveedores del salon.', style: TextStyle(color: context.textoSecundario))),
              BotonSeguro(onPressed: _abrirCrear, icon: const Icon(Icons.add), child: const Text('Registrar')),
            ]),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              SectionCard(child: Row(children: [
                Icon(Icons.cloud_off, color: context.paleta.stockBajo),
                const SizedBox(width: 10),
                const Expanded(child: Text('No se pudieron cargar los proveedores.')),
                TextButton(onPressed: _reload, child: const Text('Reintentar')),
              ]))
            else if (proveedores.isEmpty)
              const SectionCard(child: Text('No hay proveedores registrados. El campo es opcional en productos.'))
            else ...[
              SectionCard(child: Text('Total de proveedores: ${proveedores.length}', style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 12),
              ...proveedores.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(child: Row(children: [
                  const Icon(Icons.local_shipping_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.lineaContacto.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(p.lineaContacto, style: TextStyle(color: context.textoTerciario, fontSize: 12)),
                    ],
                  ])),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (op) { if (op == 'editar') _editar(p); if (op == 'desactivar') _desactivar(p); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'desactivar', child: Text('Desactivar')),
                    ],
                  ),
                ])),
              )),
            ],
            const SizedBox(height: 8),
            Text('Desactivar no borra el nombre: si vuelves a registrar un proveedor desactivado, se reactiva.', style: TextStyle(color: context.textoTerciario, fontSize: 12)),
          ],
        );
      },
    );
  }

  Future<void> _abrirCrear() async {
    final formKey = GlobalKey<FormState>();
    _limpiarCampos();
    final crear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar proveedor'),
        content: SizedBox(width: 440, child: Form(
          key: formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _nombreController, autofocus: true, validator: Validaciones.nombreSinNumeros, decoration: const InputDecoration(labelText: 'Nombre *', errorMaxLines: 2)),
            const SizedBox(height: 12),
            TextFormField(controller: _contactoController, validator: (v) => v == null || v.trim().isEmpty ? null : Validaciones.nombreSinNumeros(v), decoration: const InputDecoration(labelText: 'Persona de contacto', errorMaxLines: 2)),
            const SizedBox(height: 12),
            TextFormField(controller: _telefonoController, keyboardType: TextInputType.phone, validator: Validaciones.telefono, decoration: const InputDecoration(labelText: 'Telefono', errorMaxLines: 2)),
            const SizedBox(height: 12),
            TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, validator: (v) => Validaciones.correo(v, obligatorio: false), decoration: const InputDecoration(labelText: 'Correo', errorMaxLines: 2)),
          ])),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          BotonSeguro(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Registrar')),
        ],
      ),
    );
    if (crear == true) await _crear();
  }
}
