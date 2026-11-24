import '../../../app/theme.dart';
import 'package:flutter/material.dart';

import '../../../core/models/proveedor.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/utils/mensaje_error.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/catalogo_view.dart';
import '../../../shared/widgets/section_card.dart';

/// Gestion del catalogo de proveedores.
///
/// A diferencia de marcas, el proveedor tiene datos de contacto (persona,
/// telefono y correo). Todos son opcionales menos el nombre, y se envian como
/// null cuando quedan en blanco: el backend los normaliza a NULL y no a "".
class ProveedoresPage extends StatefulWidget {
  const ProveedoresPage({super.key, this.service});

  /// Inyectable para los tests; por defecto usa el cliente de la app.
  final CatalogService? service;

  @override
  State<ProveedoresPage> createState() => ProveedoresPageState();
}

class ProveedoresPageState extends State<ProveedoresPage> {
  late final CatalogService _service =
      widget.service ?? CatalogService(ApiClient());
  List<Proveedor>? _proveedores;
  Object? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Consulta la lista sin vaciar la que ya se ve. Ver [MarcasPageState]: el
  /// `setState(() => _future = ...)` anterior hacia fallar el alta en
  /// depuracion despues de que el API ya habia guardado.
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final lista = await _service.fetchProveedores();
      if (!mounted) return;
      setState(() {
        _proveedores = lista;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicar(Proveedor guardado) {
    final lista = [...?_proveedores]..removeWhere((p) => p.id == guardado.id);
    lista
      ..add(guardado)
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    setState(() => _proveedores = lista);
    _cargar();
  }

  Future<void> _formulario({Proveedor? actual}) async {
    final nombre = TextEditingController(text: actual?.nombre ?? '');
    final contacto = TextEditingController(text: actual?.contacto ?? '');
    final telefono = TextEditingController(text: actual?.telefono ?? '');
    final email = TextEditingController(text: actual?.email ?? '');

    final guardado = await mostrarFormularioCatalogo<Proveedor>(
      context: context,
      titulo: actual == null ? 'Registrar proveedor' : 'Editar proveedor',
      textoGuardar: actual == null ? 'Registrar' : 'Guardar',
      campos: (enviar) => [
        TextFormField(
          controller: nombre,
          autofocus: true,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: Validaciones.nombreSinNumeros,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            prefixIcon: Icon(Icons.local_shipping_outlined),
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: contacto,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) => v == null || v.trim().isEmpty
              ? null
              : Validaciones.nombreSinNumeros(v),
          decoration: const InputDecoration(
            labelText: 'Persona de contacto',
            prefixIcon: Icon(Icons.person_outline),
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: telefono,
          maxLength: 20,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: Validaciones.telefono,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            prefixIcon: Icon(Icons.phone_outlined),
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: email,
          maxLength: 100,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => enviar(),
          validator: (v) => Validaciones.correo(v, obligatorio: false),
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.mail_outline),
            errorMaxLines: 2,
          ),
        ),
      ],
      guardar: () {
        final datos = (
          nombre: nombre.text.trim(),
          contacto: contacto.text,
          telefono: telefono.text,
          email: email.text,
        );
        if (actual == null) {
          return _service.createProveedor(
            nombre: datos.nombre,
            contacto: datos.contacto,
            telefono: datos.telefono,
            email: datos.email,
          );
        }
        return _service.actualizarProveedor(
          actual.id,
          nombre: datos.nombre,
          contacto: datos.contacto,
          telefono: datos.telefono,
          email: datos.email,
        );
      },
    );

    // Tras el pop queda un frame de animacion que aun usa los controladores.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombre.dispose();
      contacto.dispose();
      telefono.dispose();
      email.dispose();
    });
    if (guardado == null || !mounted) return;
    _aplicar(guardado);
    avisoCatalogo(
      context,
      actual == null
          ? 'Proveedor registrado: ${guardado.nombre}'
          : 'Proveedor actualizado: ${guardado.nombre}',
    );
  }

  Future<void> _desactivar(Proveedor p) async {
    final ok = await confirmarDesactivar(
      context,
      titulo: 'Desactivar proveedor',
      mensaje:
          'El proveedor "${p.nombre}" dejará de aparecer al registrar o '
          'editar productos. Los productos que ya lo usan no se modifican.',
    );
    if (!ok || !mounted) return;
    try {
      await _service.desactivarProveedor(p.id);
      if (!mounted) return;
      setState(
        () => _proveedores = [...?_proveedores]..removeWhere((x) => x.id == p.id),
      );
      avisoCatalogo(context, 'Proveedor desactivado: ${p.nombre}');
      _cargar();
    } catch (e) {
      if (!mounted) return;
      avisoCatalogo(context, 'No se pudo desactivar: ${mensajeDeError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogoView<Proveedor>(
      descripcion:
          'Administra los datos de contacto de los proveedores del salón.',
      items: _proveedores,
      error: _error,
      cargando: _cargando,
      onRecargar: _cargar,
      onRegistrar: () => _formulario(),
      textoBusqueda: (p) => '${p.nombre} ${p.lineaContacto}',
      textoVacio:
          'No hay proveedores registrados. El campo es opcional en productos.',
      etiquetaTotal: (n) => n == 1 ? '1 proveedor' : '$n proveedores',
      icono: Icons.local_shipping_outlined,
      notaPie:
          'Desactivar no borra el nombre: si vuelves a registrar un proveedor '
          'desactivado, se reactiva.',
      itemBuilder: (context, p) {
        final esquema = Theme.of(context).colorScheme;
        return SectionCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _formulario(actual: p),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: esquema.primaryContainer,
                  foregroundColor: esquema.onPrimaryContainer,
                  child: Text(
                    p.nombre.trim().isEmpty ? '?' : p.nombre.trim()[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.lineaContacto.isEmpty
                            ? 'Sin datos de contacto'
                            : p.lineaContacto,
                        style: TextStyle(
                          color: context.textoTerciario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  onSelected: (op) =>
                      op == 'editar' ? _formulario(actual: p) : _desactivar(p),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
