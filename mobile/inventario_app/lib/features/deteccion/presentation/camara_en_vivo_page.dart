import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/detection_record.dart';
import 'foto_con_recuadros.dart';

/// Camara con los recuadros de la IA en vivo, mientras se apunta.
///
/// Cada ~medio segundo toma un cuadro y lo manda a la vista previa del
/// servidor (que no guarda nada); los recuadros se dibujan encima de la
/// imagen. Al tocar "Detectar" devuelve la foto final, que la pantalla de
/// Deteccion procesa como siempre: revisar, corregir y registrar.
///
/// Los recuadros llegan con ~0,5-1 s de retraso (ida y vuelta al servidor):
/// con el celular quieto calzan; si se mueve rapido, quedan atras.
class CamaraEnVivoPage extends StatefulWidget {
  final Future<ResultadoInferencia> Function(Uint8List bytes) vistaPrevia;

  const CamaraEnVivoPage({super.key, required this.vistaPrevia});

  @override
  State<CamaraEnVivoPage> createState() => _CamaraEnVivoPageState();
}

class _CamaraEnVivoPageState extends State<CamaraEnVivoPage>
    with WidgetsBindingObserver {
  CameraController? _camara;
  String? _error;
  List<Deteccion> _detecciones = const [];
  bool _sinServidor = false;

  /// Hasta la primera respuesta, un cuadro lento no es "servidor caido": el
  /// backend carga el modelo en la primera deteccion y tarda varios segundos.
  bool _huboRespuesta = false;

  /// El bucle de cuadros sigue mientras esto sea verdadero. Se apaga al
  /// tomar la foto final, al salir o al pasar la app a segundo plano.
  bool _enVivo = false;

  /// Cuadro en curso: la foto final espera a que termine, porque la camara
  /// no admite dos `takePicture` a la vez.
  Future<void>? _cuadroEnCurso;
  bool _tomandoFinal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enVivo = false;
    _camara?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Android libera la camara en segundo plano: se cierra y se vuelve a
    // abrir al regresar.
    if (estado == AppLifecycleState.inactive) {
      _enVivo = false;
      final camara = _camara;
      _camara = null;
      if (mounted) setState(() {});
      camara?.dispose();
    } else if (estado == AppLifecycleState.resumed && _camara == null) {
      _iniciar();
    }
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        setState(() => _error = 'Este dispositivo no tiene camara.');
        return;
      }
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final camara = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camara.initialize();
      // Foto siempre vertical, como la vista: si no, los recuadros (que
      // vienen en proporcion de la foto) no calzan sobre la imagen.
      await camara.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await camara.dispose();
        return;
      }
      setState(() {
        _camara = camara;
        _error = null;
      });
      _enVivo = true;
      unawaited(_bucle(camara));
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code.contains('AccessDenied')
            ? 'La app no tiene permiso para usar la camara. Activalo en los '
                'ajustes del telefono.'
            : 'No se pudo abrir la camara (${e.code}).';
      });
    }
  }

  Future<void> _bucle(CameraController camara) async {
    while (mounted && _enVivo && identical(camara, _camara)) {
      final cuadro = _procesarCuadro(camara);
      _cuadroEnCurso = cuadro;
      await cuadro;
      // Pausa corta: deja respirar al servidor y a la camara.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _procesarCuadro(CameraController camara) async {
    try {
      final foto = await camara.takePicture();
      final bytes = await foto.readAsBytes();
      _borrar(foto);
      if (!mounted || !_enVivo) return;
      final resultado = await widget.vistaPrevia(bytes);
      if (!mounted || !_enVivo) return;
      setState(() {
        _detecciones = resultado.detecciones;
        _sinServidor = false;
        _huboRespuesta = true;
      });
    } catch (_) {
      // Un cuadro perdido no es un error para el usuario: se avisa con una
      // linea y se reintenta; la foto final igual se puede tomar.
      if (!mounted || !_enVivo) return;
      setState(() {
        _detecciones = const [];
        _sinServidor = true;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Cada cuadro se guarda como archivo temporal; sin borrarlo, un minuto
  /// apuntando dejaba decenas de fotos en el cache del telefono.
  void _borrar(XFile foto) {
    if (kIsWeb) return;
    File(foto.path).delete().ignore();
  }

  Future<void> _tomarFinal() async {
    final camara = _camara;
    if (camara == null || _tomandoFinal) return;
    setState(() => _tomandoFinal = true);
    _enVivo = false;
    try {
      await _cuadroEnCurso;
      final foto = await camara.takePicture();
      final bytes = await foto.readAsBytes();
      _borrar(foto);
      if (mounted) Navigator.of(context).pop(bytes);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _tomandoFinal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo tomar la foto (${e.code}).')),
      );
      _enVivo = true;
      unawaited(_bucle(camara));
    }
  }

  String get _resumen {
    if (_sinServidor) {
      return _huboRespuesta
          ? 'Sin recuadros: el servidor no responde'
          : 'Preparando la IA...';
    }
    if (_detecciones.isEmpty) return 'Buscando productos...';
    return _detecciones.map((d) => '${d.productoNombre}: ${d.cantidad}').join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // La vista de camara es oscura en los dos modos (como el escaner de
    // codigos): el texto va en blanco fijo sobre negro.
    final camara = _camara;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Apunta a los productos'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    : camara == null || !camara.value.isInitialized
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            // La vista llega apaisada; en vertical se invierte.
                            aspectRatio: 1 / camara.value.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(camara),
                                CustomPaint(painter: PintorRecuadros(_detecciones)),
                              ],
                            ),
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final d in _detecciones)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: colorDeDeteccion(d.productoId),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _resumen,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          camara == null || _tomandoFinal ? null : _tomarFinal,
                      icon: _tomandoFinal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: const Text('Tomar foto y revisar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
