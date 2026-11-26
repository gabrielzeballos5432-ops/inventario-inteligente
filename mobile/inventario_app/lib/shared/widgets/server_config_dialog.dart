import '../../app/theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/utils/validaciones.dart';
import 'botones_dialogo.dart';

/// Abre el dialogo para ver o cambiar la URL del backend sin recompilar.
/// Devuelve true si el usuario guardo un nuevo servidor.
Future<bool?> mostrarDialogoServidor(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const ServerConfigDialog(),
  );
}

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _controller;
  String? _mensaje;
  bool _esError = false;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    final error = Validaciones.urlServidor(_controller.text);
    if (error != null) {
      setState(() {
        _mensaje = error;
        _esError = true;
      });
      return;
    }
    final url = ApiConfig.normalizar(_controller.text);
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final respuesta =
          await http.get(Uri.parse('$url/')).timeout(const Duration(seconds: 8));
      setState(() {
        _esError = respuesta.statusCode != 200;
        _mensaje = respuesta.statusCode == 200
            ? 'Conexión exitosa con el backend'
            : 'El servidor respondio con error HTTP ${respuesta.statusCode}';
      });
    } catch (_) {
      setState(() {
        _esError = true;
        _mensaje =
            'No se pudo conectar. Revisa la IP, que el backend este corriendo y que el celular este en la misma red.';
      });
    } finally {
      setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    final error = Validaciones.urlServidor(_controller.text);
    if (error != null) {
      setState(() {
        _esError = true;
        _mensaje = error;
      });
      return;
    }
    final url = ApiConfig.normalizar(_controller.text);
    await ApiConfig.setBaseUrl(url);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar servidor'),
      // Con scroll: el campo tiene autofocus, asi que el teclado sube solo, y
      // si ademas aparece el mensaje de error de tres lineas el contenido no
      // cabe y Flutter pinta la franja amarilla de "overflowed". Con el
      // SingleChildScrollView el dialogo se desplaza en vez de desbordar.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dirección del backend (PC) que usa la app. Se guarda en el '
              'dispositivo y no requiere reinstalar.',
              style: TextStyle(fontSize: 13, color: context.textoSecundario),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'URL del backend',
                hintText: 'http://192.168.100.43:8000',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            if (_mensaje != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_ocupado)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _mensaje!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _esError
                            ? context.paleta.negativo
                            : context.paleta.positivo,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Row + Expanded, igual que BotonesDialogo: a lo ancho sin pedir
            // un ancho infinito dentro del IntrinsicWidth del AlertDialog.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : _probar,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Probar conexión'),
                  ),
                ),
              ],
            ),
            BotonesDialogo(
              textoConfirmar: 'Guardar',
              onCancelar: () => Navigator.of(context).pop(false),
              onConfirmar: _guardar,
            ),
          ],
        ),
      ),
    );
  }
}
