import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/inventario_provider.dart';
import '../../../shared/widgets/section_card.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  final _picker = ImagePicker();

  bool _capturando = false;
  Uint8List? _imageBytes;

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
      final image = await _picker.pickImage(
        source: _soportaCamara ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null) {
        setState(() => _capturando = false);
        return;
      }

      final bytes = await image.readAsBytes();
      setState(() => _imageBytes = bytes);

      await context.read<InventarioProvider>().enviarImagen(bytes, image.name);

      if (!mounted) return;
      setState(() => _capturando = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final resultado = inventario.ultimaInferencia;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Deteccion',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _soportaCamara
              ? 'Toma una foto para detectar productos y registrar entrada de inventario.'
              : 'Selecciona una imagen de los productos para detectarlos y registrar la entrada de inventario. La captura con camara esta disponible en la aplicacion movil.',
          style: const TextStyle(color: Colors.white70),
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
                      ? const SizedBox(
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
          const SizedBox(height: 16),
          SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Reconocimiento con IA pendiente',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'El servidor todavia no tiene el modelo entrenado '
                        '(best.pt). Mientras tanto puedes registrar entradas '
                        'y salidas a mano desde la pestaña Productos.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (inventario.yoloDisponible == true) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text('Modelo de IA cargado. Deteccion activa.'),
              ],
            ),
          ),
        ],
        if (_imageBytes != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                _imageBytes!,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
        if (inventario.error != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: Text(
              inventario.error!,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
        if (resultado != null && resultado.detecciones.isEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            child: Text(
              'No se reconocieron productos en la imagen. '
              'Prueba con mejor iluminacion y acercando mas.',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
        if (resultado != null && resultado.detecciones.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Resultado',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...resultado.detecciones.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
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
                    const SizedBox(height: 6),
                    Text('Cantidad detectada: ${d.cantidad}'),
                    Text(
                      'Confianza: ${(d.confianza * 100).toStringAsFixed(1)}%',
                    ),
                    if (d.confianza >= 0.5)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('Deteccion confiable'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (resultado.movimientosCreados > 0)
            SectionCard(
              child: Text(
                '${resultado.movimientosCreados} movimiento(s) de entrada registrado(s) automaticamente.',
                style: const TextStyle(color: Colors.green),
              ),
            ),
        ],
      ],
    );
  }
}
