import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/core/utils/validaciones.dart';

/// Las reglas de validacion son las que deciden que mensaje ve el usuario
/// cuando un campo no lo deja guardar. Se prueban aqui para que un cambio en
/// una expresion regular no rompa en silencio el alta de productos.
void main() {
  group('nombreSinNumeros', () {
    test('rechaza numeros en el nombre', () {
      expect(Validaciones.nombreSinNumeros('Uñas 2'),
          'El nombre no puede contener numeros');
      expect(Validaciones.nombreSinNumeros('123'),
          'El nombre no puede contener numeros');
    });

    test('exige un nombre', () {
      expect(Validaciones.nombreSinNumeros('  '), 'Escribe el nombre');
      expect(Validaciones.nombreSinNumeros(null), 'Escribe el nombre');
    });

    test('rechaza simbolos raros', () {
      expect(Validaciones.nombreSinNumeros('Tinte @'),
          "El nombre solo admite letras y espacios ( . , - & ' )");
    });

    test('acepta nombres reales con acentos y separadores', () {
      expect(Validaciones.nombreSinNumeros('Uñas'), isNull);
      expect(Validaciones.nombreSinNumeros("L'Oréal"), isNull);
      expect(Validaciones.nombreSinNumeros('Schwarzkopf'), isNull);
      expect(Validaciones.nombreSinNumeros('Cuidado personal'), isNull);
    });
  });

  group('nombreProducto', () {
    test('permite numeros comerciales pero exige letras', () {
      expect(Validaciones.nombreProducto('Shampoo 400 ml'), isNull);
      expect(Validaciones.nombreProducto('Tinte 7.1'), isNull);
    });

    test('rechaza un nombre solo numerico', () {
      expect(Validaciones.nombreProducto('123'),
          'El nombre debe incluir letras, no solo numeros');
    });

    test('exige un nombre', () {
      expect(Validaciones.nombreProducto(''),
          'Escribe el nombre del producto');
    });
  });

  group('precio', () {
    test('rechaza vacio, no numerico, negativo y cero', () {
      expect(Validaciones.precio('', etiqueta: 'precio de venta'),
          'Escribe el precio de venta');
      expect(Validaciones.precio('abc', etiqueta: 'precio de venta'),
          'Ingresa un numero valido (ej. 25.50)');
      expect(Validaciones.precio('-5', etiqueta: 'precio de compra'),
          'El precio de compra no puede ser negativo');
      expect(Validaciones.precio('0', etiqueta: 'precio de venta'),
          'El precio de venta debe ser mayor a 0');
    });

    test('acepta decimales con punto o coma', () {
      expect(Validaciones.precio('25.50', etiqueta: 'precio de venta'), isNull);
      expect(Validaciones.precio('25,50', etiqueta: 'precio de venta'), isNull);
    });
  });

  group('cantidad', () {
    test('entrada y salida exigen mayor a 0', () {
      expect(Validaciones.cantidad('0', tipo: 'entrada'),
          'La cantidad debe ser mayor a 0');
      expect(Validaciones.cantidad('0', tipo: 'salida'),
          'La cantidad debe ser mayor a 0');
    });

    test('el ajuste admite 0', () {
      expect(Validaciones.cantidad('0', tipo: 'ajuste'), isNull);
    });

    test('la salida no puede superar el stock', () {
      expect(
        Validaciones.cantidad('5', tipo: 'salida', stockDisponible: 3),
        'No hay stock suficiente: disponible 3',
      );
      expect(
        Validaciones.cantidad('3', tipo: 'salida', stockDisponible: 3),
        isNull,
      );
    });
  });

  group('telefono', () {
    test('es opcional', () {
      expect(Validaciones.telefono(''), isNull);
    });

    test('admite signos de telefono y rechaza letras', () {
      expect(Validaciones.telefono('+591 71234567'), isNull);
      expect(Validaciones.telefono('(4) 123-456'), isNull);
      expect(Validaciones.telefono('llamar'),
          'El telefono solo admite numeros y los signos + - ( )');
    });
  });

  group('correo', () {
    test('exige arroba y dominio', () {
      expect(Validaciones.correo('admin@zoom.com'), isNull);
      expect(Validaciones.correo('sin-arroba'),
          'Ingresa un correo valido (ej. nombre@correo.com)');
    });

    test('es opcional en proveedores', () {
      expect(Validaciones.correo('', obligatorio: false), isNull);
    });
  });
}
