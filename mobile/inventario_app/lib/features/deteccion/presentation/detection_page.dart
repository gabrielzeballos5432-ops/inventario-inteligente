import '../../../app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/detection_record.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/boton_seguro.dart';
import '../../../shared/widgets/section_card.dart';
import 'camara_en_vivo_page.dart';
import 'foto_con_recuadros.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  final _picker = ImagePicker();

  bool _capturando = false;
  bool _registrando = false;
  Uint8List? _imageBytes;

  /// Cantidad a registrar por producto, editable antes de confirmar. Arranca
  /// con lo que conto la IA; 0 quita el producto (deteccion equivocada).
  final Map<int, int> _cantidades = {};
  String? _errorRegistro;

  /// Resultado al que corresponden [_cantidades]: con uno nuevo se reinician
  /// a lo que conto la IA.
  ResultadoInferencia? _resultadoEditado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().consultarEstadoServidor();
    });
  }

  // Solo celular tiene camara; en laptop y web se selecciona un archivo.
  bool get _soportaCamara =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _captureAndDetect() async {
    setState(() {
      _capturando = true;
    });

    try {
      final foto = await _obtenerFoto();
      if (foto == null) {
        if (mounted) setState(() => _capturando = false);
        return;
      }
      final (bytes, nombre) = foto;
      setState(() => _imageBytes = bytes);

      if (!mounted) return;
      await context.read<InventarioProvider>().enviarImagen(bytes, nombre);

      if (!mounted) return;
      setState(() {
        _capturando = false;
        _errorRegistro = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturando = false;
      });
    }
  }

  /// En el celular abre la camara con recuadros en vivo; en web y escritorio,
  /// el selector de archivos. Null si el usuario cancela.
  Future<(Uint8List, String)?> _obtenerFoto() async {
    if (_soportaCamara) {
      final inventario = context.read<InventarioProvider>();
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => CamaraEnVivoPage(vistaPrevia: inventario.vistaPrevia),
        ),
      );
      return bytes == null ? null : (bytes, 'foto.jpg');
    }
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image == null) return null;
    return (await image.readAsBytes(), image.name);
  }

  int get _unidades => _cantidades.values.fold(0, (a, b) => a + b);

  Future<void> _registrar() async {
    if (_registrando || _unidades == 0) return;
    setState(() {
      _registrando = true;
      _errorRegistro = null;
    });
    // Se lee antes de confirmar: al terminar, la pantalla se limpia y el
    // total quedaba en 0 ("Entrada registrada: 0 unidad(es)").
    final unidades = _unidades;
    try {
      final lote = await context.read<InventarioProvider>().confirmarDeteccion([
        for (final e in _cantidades.entries)
          (productoId: e.key, cantidad: e.value),
      ]);
      if (!mounted) return;
      final reactivados = lote.reactivados.isEmpty
          ? ''
          : ' Se reactivo: ${lote.reactivados.join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entrada registrada: $unidades unidad(es) en '
            '${lote.guardados} producto(s).$reactivados',
          ),
        ),
      );
      setState(() {
        _registrando = false;
        _imageBytes = null;
        _cantidades.clear();
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _registrando = false;
          _errorRegistro = e.detalle;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _registrando = false;
          _errorRegistro =
              'No se pudo registrar. Revisa la conexión y el historial antes de reintentar.';
        });
      }
    }
  }

  void _descartar() {
    context.read<InventarioProvider>().descartarDeteccion();
    setState(() {
      _imageBytes = null;
      _cantidades.clear();
      _errorRegistro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final resultado = inventario.ultimaInferencia;
    if (!identical(resultado, _resultadoEditado)) {
      _resultadoEditado = resultado;
      _cantidades
        ..clear()
        ..addEntries(
          (resultado?.detecciones ?? const <Deteccion>[]).map(
            (d) => MapEntry(d.productoId, d.cantidad),
          ),
        );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // El titulo de la pestana ya lo muestra la AppBar.
        Text(
          _soportaCamara
              ? 'Toma una foto de los productos: la IA los cuenta y tu revisas '
                  'el resultado antes de registrar la entrada.'
              : 'Selecciona una imagen de los productos: la IA los cuenta y tu '
                  'revisas el resultado antes de registrar la entrada. La captura '
                  'con cámara esta disponible en la aplicacion movil.',
          style: TextStyle(color: context.textoSecundario),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _capturando ? null : _captureAndDetect,
                  icon: _capturando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_soportaCamara
                          ? Icons.camera_alt_outlined
                          : Icons.image_outlined),
                  label: Text(_capturando
                      ? 'Procesando...'
                      : (_soportaCamara
                          ? 'Tomar foto y detectar'
                          : 'Seleccionar imagen y detectar')),
                ),
              ),
            ],
          ),
        ),
        if (inventario.yoloDisponible == false) ...[
          SizedBox(height: 16),
          SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: context.paleta.aviso),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reconocimiento con IA pendiente',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'El servidor todavía no tiene el modelo entrenado '
                        '(best.pt). Mientras tanto puedes registrar entradas '
                        'y salidas a mano desde la pestaña Productos.',
                        style: TextStyle(
                            color: context.textoSecundario, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (inventario.yoloDisponible == true) ...[
          SizedBox(height: 16),
          SectionCard(
            child: Row(
              children: [
                Icon(Icons.check_circle, color: context.paleta.positivo, size: 20),
                const SizedBox(width: 8),
                // Expanded: sin el, el texto no se ajusta al ancho del
                // telefono y la fila se desbordaba (franja amarilla).
                const Expanded(
                  child: Text('Modelo de IA cargado. Detección activa.'),
                ),
              ],
            ),
          ),
        ],
        if (_imageBytes != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            // Foto completa con un recuadro por unidad contada: deja ver si
            // la IA conto dos veces lo mismo o se salto uno.
            child: FotoConRecuadros(
              bytes: _imageBytes!,
              detecciones: resultado?.detecciones ?? const [],
            ),
          ),
        ],
        if (inventario.errorDeteccion != null) ...[
          SizedBox(height: 16),
          SectionCard(
            child: Text(
              inventario.errorDeteccion!,
              style: TextStyle(color: context.paleta.stockBajo),
            ),
          ),
        ],
        if (resultado != null && resultado.detecciones.isEmpty) ...[
          SizedBox(height: 16),
          SectionCard(
            child: Text(
              'No se reconocieron productos en la imagen. '
              'Prueba con mejor iluminación y acercando más.',
              style: TextStyle(color: context.paleta.stockBajo),
            ),
          ),
        ],
        if (resultado != null && resultado.detecciones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Revisa antes de registrar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Corrige la cantidad si la IA conto mal. Deja en 0 lo que no '
            'corresponda. El stock no cambia hasta que confirmes.',
            style: TextStyle(color: context.textoSecundario),
          ),
          const SizedBox(height: 10),
          ...resultado.detecciones.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                child: Row(
                  children: [
                    // Mismo color que sus recuadros en la foto.
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: colorDeDeteccion(d.productoId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.productoNombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'La IA conto ${d.cantidad} · confianza '
                            '${(d.confianza * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: context.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar una unidad de ${d.productoNombre}',
                      onPressed: _registrando ||
                              (_cantidades[d.productoId] ?? 0) == 0
                          ? null
                          : () => setState(
                              () => _cantidades[d.productoId] =
                                  (_cantidades[d.productoId] ?? 0) - 1,
                            ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${_cantidades[d.productoId] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Agregar una unidad de ${d.productoNombre}',
                      onPressed: _registrando
                          ? null
                          : () => setState(
                              () => _cantidades[d.productoId] =
                                  (_cantidades[d.productoId] ?? 0) + 1,
                            ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errorRegistro != null) ...[
            Text(
              _errorRegistro!,
              style: TextStyle(color: context.paleta.negativo),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _registrando ? null : _descartar,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: BotonSeguro(
                  onPressed: _registrando || _unidades == 0 ? null : _registrar,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  child: Text(
                    _registrando
                        ? 'Registrando...'
                        : 'Registrar entrada ($_unidades)',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
