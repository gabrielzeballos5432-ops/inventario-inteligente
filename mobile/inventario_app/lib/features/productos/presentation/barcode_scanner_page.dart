import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerPage extends StatefulWidget {
  final void Function(String codigo) onDetectado;

  const BarcodeScannerPage({super.key, required this.onDetectado});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.itf,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
    ],
  );

  bool _procesando = false;

  bool get _soportaCamara =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_soportaCamara) {
      _solicitarPermiso();
    }
  }

  Future<void> _solicitarPermiso() async {
    // En pruebas y en plataformas sin implementacion del plugin, request()
    // lanza MissingPluginException. Sin capturar, esa excepcion sube como
    // Unhandled Exception y el usuario ve la pantalla en rojo.
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isDenied || status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado')),
        );
      }
    } catch (_) {
      // Sin permiso no hay escaneo; la propia pagina avisa en su cuerpo.
    }
  }

  /// Contrato de [BarcodeScannerPage.onDetectado]: es solo una notificacion.
  /// Esta pagina se cierra sola y devuelve el codigo como resultado de la
  /// ruta, asi que el callback no debe cerrar nada: un pop desde el contexto
  /// de quien llamo al push saca la ruta de mas y deja el Navigator bloqueado
  /// con _debugLocked en true.
  void _manejarCaptura(BarcodeCapture capture) {
    if (_procesando) return;
    final codigo = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (codigo == null) return;

    setState(() => _procesando = true);
    widget.onDetectado(codigo);

    // Red de seguridad: si el callback ya cerro la pagina, isCurrent es false
    // y el pop se omite en lugar de cerrar una ruta ajena.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop(codigo);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_soportaCamara) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear código')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'El escaneo de códigos de barras solo esta disponible en '
              'dispositivos moviles con cámara.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _manejarCaptura,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Apunta al código de barras o código QR del producto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
