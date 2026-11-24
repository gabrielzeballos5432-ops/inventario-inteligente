import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/core/utils/formato_numero.dart';

/// Simula escribir [texto] partiendo de [antes] y devuelve lo que queda.
String _escribir(List<TextInputFormatter> filtros, String antes, String texto) {
  var valor = TextEditingValue(text: antes);
  for (final f in filtros) {
    valor = f.formatEditUpdate(valor, TextEditingValue(text: texto));
  }
  return valor.text;
}

void main() {
  group('decimal', () {
    final dos = FormatoNumero.decimal();

    test('no deja escribir el signo menos', () {
      expect(_escribir(dos, '', '-'), '');
      expect(_escribir(dos, '5', '-5'), '5');
      expect(_escribir(dos, '5', '5-'), '5');
    });

    test('acepta punto o coma, uno solo', () {
      expect(_escribir(dos, '12', '12,5'), '12,5');
      expect(_escribir(dos, '12', '12.5'), '12.5');
      expect(_escribir(dos, '12.5', '12.5.'), '12.5');
    });

    test('no deja letras ni notacion cientifica', () {
      expect(_escribir(dos, '1', '1e'), '1');
      expect(_escribir(dos, '', 'a'), '');
    });

    test('limita los decimales mientras se escribe', () {
      expect(_escribir(dos, '1.25', '1.255'), '1.25');
      expect(_escribir(FormatoNumero.decimal(decimales: 6), '6.96', '6.960001'),
          '6.960001');
    });
  });

  test('monto se muestra con miles y coma decimal', () {
    expect(FormatoNumero.monto(18450), '18.450,00');
    expect(FormatoNumero.monto(1234567.891), '1.234.567,89');
    expect(FormatoNumero.monto(40), '40,00');
    expect(FormatoNumero.monto(0.005), '0,01');
    expect(FormatoNumero.monto(-1500.5), '-1.500,50');
    expect(FormatoNumero.monto(null), '0,00');
    expect(FormatoNumero.bs(999.999), 'Bs 1.000,00');
  });

  test('entero no deja negativos ni decimales', () {
    expect(_escribir(FormatoNumero.entero, '', '-3'), '3');
    expect(_escribir(FormatoNumero.entero, '3', '3.5'), '35');
  });
}
