import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Mas ajustado en el telefono: cada dp lateral es ancho util de la tabla.
    final angosta = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(angosta ? 12 : 16),
        child: child,
      ),
    );
  }
}
