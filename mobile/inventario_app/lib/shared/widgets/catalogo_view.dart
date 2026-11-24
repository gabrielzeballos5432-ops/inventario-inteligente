import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/mensaje_error.dart';
import 'boton_seguro.dart';
import 'section_card.dart';

/// Lista de un catalogo simple (marcas, proveedores): cabecera con
/// "Registrar", buscador, estados de carga/error/vacio y la nota del pie.
///
/// La lista anterior se mantiene en pantalla mientras se recarga (con una
/// barra fina arriba) en vez de cambiarla por un spinner: tras registrar, el
/// elemento nuevo aparece sin que la pantalla parpadee.
class CatalogoView<T> extends StatefulWidget {
  const CatalogoView({
    super.key,
    required this.descripcion,
    required this.items,
    required this.error,
    required this.cargando,
    required this.onRecargar,
    required this.onRegistrar,
    required this.textoBusqueda,
    required this.itemBuilder,
    required this.textoVacio,
    required this.etiquetaTotal,
    required this.icono,
    this.notaPie,
  });

  final String descripcion;

  /// null mientras no hubo una carga correcta.
  final List<T>? items;
  final Object? error;
  final bool cargando;
  final Future<void> Function() onRecargar;
  /// No se espera: el boton solo abre el dialogo, y esperar al cierre lo
  /// dejaba girando todo el rato que el dialogo estaba abierto.
  final VoidCallback onRegistrar;
  final String Function(T) textoBusqueda;
  final Widget Function(BuildContext, T) itemBuilder;
  final String textoVacio;
  final String Function(int) etiquetaTotal;
  final IconData icono;
  final String? notaPie;

  @override
  State<CatalogoView<T>> createState() => _CatalogoViewState<T>();
}

class _CatalogoViewState<T> extends State<CatalogoView<T>> {
  final _busqueda = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final visibles = items == null
        ? const []
        : _filtro.isEmpty
        ? items
        : items
              .where((i) => widget.textoBusqueda(i).toLowerCase().contains(_filtro))
              .toList();

    return RefreshIndicator(
      onRefresh: widget.onRecargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  widget.descripcion,
                  style: TextStyle(color: context.textoSecundario),
                ),
              ),
              BotonSeguro(
                onPressed: widget.onRegistrar,
                icon: const Icon(Icons.add),
                child: const Text('Registrar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 4,
            child: widget.cargando && items != null
                ? const LinearProgressIndicator()
                : null,
          ),
          const SizedBox(height: 8),
          if (items == null && widget.error == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (items == null)
            _errorCarga(context, widget.error!)
          else ...[
            if (widget.error != null) ...[
              _errorCarga(context, widget.error!),
              const SizedBox(height: 12),
            ],
            if (items.isEmpty)
              _vacio(context)
            else ...[
              TextField(
                controller: _busqueda,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    setState(() => _filtro = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar',
                  suffixIcon: _filtro.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _busqueda.clear();
                            setState(() => _filtro = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _filtro.isEmpty
                    ? widget.etiquetaTotal(items.length)
                    : '${visibles.length} de ${items.length}',
                style: TextStyle(
                  color: context.textoSecundario,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (visibles.isEmpty)
                SectionCard(
                  child: Text(
                    'Nada coincide con "${_busqueda.text.trim()}".',
                    style: TextStyle(color: context.textoSecundario),
                  ),
                )
              else
                for (final item in visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: widget.itemBuilder(context, item as T),
                  ),
            ],
          ],
          if (widget.notaPie != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.notaPie!,
              style: TextStyle(color: context.textoTerciario, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vacio(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(widget.icono, size: 40, color: context.textoTerciario),
          const SizedBox(height: 10),
          Text(
            widget.textoVacio,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textoSecundario),
          ),
        ],
      ),
    ),
  );

  Widget _errorCarga(BuildContext context, Object error) => SectionCard(
    child: Row(
      children: [
        Icon(Icons.cloud_off, color: context.paleta.stockBajo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.items == null
                    ? 'No se pudo cargar la lista.'
                    : 'No se pudo actualizar la lista.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                mensajeDeError(error),
                style: TextStyle(color: context.textoSecundario, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BotonSeguro(
          variante: VarianteBoton.text,
          onPressed: widget.onRecargar,
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}

/// Formulario de alta/edicion de un catalogo en un dialogo que **guarda
/// dentro del dialogo**.
///
/// Antes el dialogo se cerraba al validar y la llamada al API iba despues: si
/// el backend rechazaba (nombre repetido, sin conexion) el usuario perdia lo
/// escrito y solo veia un SnackBar. Aqui el rechazo se muestra dentro del
/// dialogo, los datos siguen ahi y se puede corregir. Devuelve lo que
/// devuelva [guardar], o null si se cancela.
///
/// [campos] recibe `enviar` para que el ultimo campo pueda guardar con Enter.
Future<R?> mostrarFormularioCatalogo<R>({
  required BuildContext context,
  required String titulo,
  required String textoGuardar,
  required List<Widget> Function(VoidCallback enviar) campos,
  required Future<R> Function() guardar,
}) {
  final formKey = GlobalKey<FormState>();
  return showDialog<R>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      String? error;
      var guardando = false;
      return StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> enviar() async {
            if (guardando) return;
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialog(() {
              guardando = true;
              error = null;
            });
            try {
              final resultado = await guardar();
              if (ctx.mounted) Navigator.of(ctx).pop(resultado);
            } catch (e) {
              if (ctx.mounted) {
                setDialog(() {
                  guardando = false;
                  error = mensajeDeError(e);
                });
              }
            }
          }

          return AlertDialog(
            title: Text(titulo),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...campos(enviar),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(ctx).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                              ),
                              onPressed: guardando
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BotonSeguro(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                              ),
                              onPressed: enviar,
                              child: Text(textoGuardar),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Muestra un aviso breve reemplazando al anterior (no se apilan).
void avisoCatalogo(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Confirmacion de desactivar con botones a lo ancho.
Future<bool> confirmarDesactivar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(mensaje),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Desactivar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
