import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/detection_record.dart';

/// Colores de los recuadros, uno por producto (segun su id, para que el mismo
/// producto tenga siempre el mismo color, salga solo o acompanado). Son literales a proposito, como el overlay del escaner de codigos:
/// van encima de la foto, no del fondo de la app, asi que tienen que verse
/// igual en modo claro y noche. Son tonos vivos que destacan sobre casi
/// cualquier foto; la etiqueta lleva texto negro encima.
const List<Color> coloresRecuadro = [
  Color(0xFFFFD600), // amarillo
  Color(0xFF00E5FF), // celeste
  Color(0xFFFF4081), // rosa
  Color(0xFF76FF03), // verde
];

Color colorDeDeteccion(int productoId) =>
    coloresRecuadro[productoId % coloresRecuadro.length];

/// Muestra la foto entera (sin recortar) con un recuadro por cada unidad que
/// conto la IA. La foto no se recorta porque las coordenadas son proporciones
/// de la imagen completa: con `BoxFit.cover` los recuadros quedaban corridos.
class FotoConRecuadros extends StatefulWidget {
  final Uint8List bytes;
  final List<Deteccion> detecciones;
  final double altoMaximo;

  const FotoConRecuadros({
    super.key,
    required this.bytes,
    this.detecciones = const [],
    this.altoMaximo = 420,
  });

  @override
  State<FotoConRecuadros> createState() => _FotoConRecuadrosState();
}

class _FotoConRecuadrosState extends State<FotoConRecuadros> {
  late MemoryImage _imagen;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) return;
      setState(() {
        _tamano = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    },
    onError: (_, _) {
      if (mounted) setState(() => _fallo = true);
    },
  );

  /// Tamano de la foto ya decodificada (Flutter aplica la orientacion EXIF,
  /// igual que el servidor con `exif_transpose`, asi que los recuadros
  /// calzan). Hasta conocerlo no se puede fijar la proporcion.
  Size? _tamano;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  @override
  void didUpdateWidget(FotoConRecuadros anterior) {
    super.didUpdateWidget(anterior);
    if (!identical(anterior.bytes, widget.bytes)) _resolver();
  }

  void _resolver() {
    _stream?.removeListener(_listener);
    _tamano = null;
    _fallo = false;
    _imagen = MemoryImage(widget.bytes);
    _stream = _imagen.resolve(ImageConfiguration.empty)..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamano = _tamano;
    if (tamano == null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: _fallo
              ? const Icon(Icons.broken_image_outlined, size: 48)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final unidades = widget.detecciones.fold<int>(
      0,
      (total, d) => total + d.cajas.length,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.altoMaximo),
      // heightFactor 1: el alto lo da la foto, no el maximo disponible.
      child: Center(
        heightFactor: 1,
        child: AspectRatio(
          aspectRatio: tamano.width / tamano.height,
          child: Semantics(
            label: 'Foto con $unidades recuadro(s) de detección',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: _imagen, fit: BoxFit.fill),
                  CustomPaint(
                    painter: PintorRecuadros(widget.detecciones),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja los recuadros y, arriba de cada uno, la confianza de esa unidad.
class PintorRecuadros extends CustomPainter {
  final List<Deteccion> detecciones;

  PintorRecuadros(this.detecciones);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < detecciones.length; i++) {
      final color = colorDeDeteccion(detecciones[i].productoId);
      final borde = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final caja in detecciones[i].cajas) {
        final rect = Rect.fromLTRB(
          caja.x1 * size.width,
          caja.y1 * size.height,
          caja.x2 * size.width,
          caja.y2 * size.height,
        );
        canvas.drawRect(rect, borde);
        _etiqueta(canvas, size, rect, color, caja.confianza);
      }
    }
  }

  void _etiqueta(Canvas canvas, Size size, Rect rect, Color color, double conf) {
    final texto = TextPainter(
      text: TextSpan(
        text: '${(conf * 100).round()}%',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const relleno = 4.0;
    final alto = texto.height + relleno;
    // Arriba del recuadro; si no cabe (recuadro pegado al borde), por dentro.
    final arriba = rect.top - alto >= 0 ? rect.top - alto : rect.top;
    final maxIzquierda = math.max(0.0, size.width - texto.width - 2 * relleno);
    final izquierda = rect.left.clamp(0.0, maxIzquierda);
    final fondo = Rect.fromLTWH(
      izquierda.toDouble(),
      arriba,
      texto.width + 2 * relleno,
      alto,
    );
    canvas.drawRect(fondo, Paint()..color = color);
    texto.paint(canvas, Offset(fondo.left + relleno, fondo.top + relleno / 2));
  }

  @override
  bool shouldRepaint(PintorRecuadros anterior) =>
      !identical(anterior.detecciones, detecciones);
}
