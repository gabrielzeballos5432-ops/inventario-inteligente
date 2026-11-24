import 'package:flutter/services.dart';

/// Filtros de escritura para campos numericos.
///
/// Los validadores ya rechazan un negativo al guardar, pero el campo dejaba
/// escribir "-", letras o "1e5" y el error recien aparecia al tocar Guardar.
/// Con estos filtros el campo directamente no acepta el signo menos ni nada
/// que no sea un numero, y limita los decimales mientras se escribe.
class FormatoNumero {
  FormatoNumero._();

  /// Solo digitos: cantidades, stock y unidades. Nunca negativos.
  static final List<TextInputFormatter> entero = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// Monto para MOSTRAR, como se escribe en Bolivia: `18.450,00`.
  ///
  /// Antes cada pantalla armaba el suyo con `toStringAsFixed(2)`: salian
  /// `Bs 18450.00` en un lado y `Bs. 40.00` en otro, sin separador de miles.
  /// Solo para texto en pantalla: al API y a los campos editables se les sigue
  /// pasando `toStringAsFixed(2)`.
  static String monto(num? valor) {
    final v = (valor ?? 0).toDouble();
    final centavos = (v.abs() * 100).round();
    final entero = (centavos ~/ 100).toString();
    final miles = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) miles.write('.');
      miles.write(entero[i]);
    }
    final signo = v < 0 && centavos > 0 ? '-' : '';
    return '$signo$miles,${(centavos % 100).toString().padLeft(2, '0')}';
  }

  /// [monto] con el prefijo de bolivianos: `Bs 18.450,00`.
  static String bs(num? valor) => 'Bs ${monto(valor)}';

  /// Digitos con un solo separador (punto o coma) y hasta [decimales]
  /// decimales. Nunca negativos.
  static List<TextInputFormatter> decimal({int decimales = 2}) {
    final patron = RegExp('^\\d*([.,]\\d{0,$decimales})?\$');
    return [
      TextInputFormatter.withFunction(
        (anterior, nuevo) => patron.hasMatch(nuevo.text) ? nuevo : anterior,
      ),
    ];
  }
}
