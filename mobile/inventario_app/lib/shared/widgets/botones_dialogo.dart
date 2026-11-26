import 'dart:async';

import 'package:flutter/material.dart';

import 'boton_seguro.dart';

/// Botones "Cancelar / Confirmar" de un formulario en dialogo.
///
/// Van **dentro del contenido**, a lo ancho y con 50 de alto: los `actions`
/// del `AlertDialog` quedan diminutos y fuera del alcance del pulgar en el
/// telefono (ver AGENTS.md). El de confirmar es un [BotonSeguro], asi que un
/// doble toque no guarda dos veces.
///
/// El boton de la izquierda tambien puede ser una accion propia en vez de
/// "Cancelar" ("Agregar moneda" en un dialogo de lista): con [iconoCancelar]
/// pasa a ser un [BotonSeguro] delineado, para que un doble toque no abra
/// dos formularios.
class BotonesDialogo extends StatelessWidget {
  const BotonesDialogo({
    super.key,
    required this.textoConfirmar,
    required this.onConfirmar,
    this.textoCancelar = 'Cancelar',
    this.onCancelar,
    this.ocupado = false,
    this.iconoConfirmar,
    this.iconoCancelar,
  });

  final String textoConfirmar;

  /// `null` deshabilita el boton de confirmar.
  final FutureOr<void> Function()? onConfirmar;
  final String textoCancelar;

  /// Por defecto cierra el dialogo sin devolver nada.
  final FutureOr<void> Function()? onCancelar;

  /// Deshabilita los dos botones mientras se guarda.
  final bool ocupado;
  final Widget? iconoConfirmar;
  final Widget? iconoCancelar;

  @override
  Widget build(BuildContext context) {
    final estiloSecundario = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final textoSecundario = Text(
      textoCancelar,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: iconoCancelar != null
                ? BotonSeguro(
                    variante: VarianteBoton.outlined,
                    onPressed: ocupado ? null : onCancelar,
                    icon: iconoCancelar,
                    style: estiloSecundario,
                    child: textoSecundario,
                  )
                : OutlinedButton(
                    onPressed: ocupado
                        ? null
                        : (onCancelar ?? () => Navigator.of(context).pop()),
                    style: estiloSecundario,
                    child: textoSecundario,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BotonSeguro(
              onPressed: ocupado ? null : onConfirmar,
              icon: iconoConfirmar,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                // Con el padding 24 del tema no cabe en la mitad del dialogo
                // y textos como "Guardar tarifas" se partian en dos.
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                textoConfirmar,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
