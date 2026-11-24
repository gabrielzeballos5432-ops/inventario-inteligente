import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/core/utils/validaciones.dart';

/// Las reglas de validacion son las que deciden que mensaje ve el usuario
/// cuando un campo no lo deja guardar. Se prueban aqui para que un cambio en
/// una expresion regular no rompa en silencio el alta de productos.
void main() {
  group('nombreSinNumeros', () {
    test('rechaza números en el nombre', () {
      expect(Validaciones.nombreSinNumeros('Uñas 2'),
          'El nombre no puede contener números');
      expect(Validaciones.nombreSinNumeros('123'),
          'El nombre no puede contener números');
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
    test('permite números comerciales pero exige letras', () {
      expect(Validaciones.nombreProducto('Shampoo 400 ml'), isNull);
      expect(Validaciones.nombreProducto('Tinte 7.1'), isNull);
    });

    test('rechaza un nombre solo numerico', () {
      expect(Validaciones.nombreProducto('123'),
          'El nombre debe incluir letras, no solo números');
    });

    test('exige un nombre', () {
      expect(Validaciones.nombreProducto(''),
          'Escribe el nombre del producto');
    });
  });

  group('precio', () {
    test('rechaza vacío, no numerico, negativo y cero', () {
      expect(Validaciones.precio('', etiqueta: 'precio de venta'),
          'Escribe el precio de venta');
      expect(Validaciones.precio('abc', etiqueta: 'precio de venta'),
          'Ingresa un número válido (ej. 25.50)');
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

    test('admite signos de teléfono y rechaza letras', () {
      expect(Validaciones.telefono('+591 71234567'), isNull);
      expect(Validaciones.telefono('(4) 123-456'), isNull);
      expect(Validaciones.telefono('llamar'),
          'El teléfono solo admite números y los signos + - ( )');
    });
  });

  group('correo', () {
    test('exige arroba y dominio', () {
      expect(Validaciones.correo('admin@zoom.com'), isNull);
      expect(Validaciones.correo('sin-arroba'),
          'Ingresa un correo válido (ej. nombre@correo.com)');
    });

    test('es opcional en proveedores', () {
      expect(Validaciones.correo('', obligatorio: false), isNull);
    });
  });

  group('cantidadInicial', () {
    test('es opcional: vacío cuenta como 0', () {
      expect(Validaciones.cantidadInicial(''), isNull);
      expect(Validaciones.cantidadInicial(null), isNull);
      expect(Validaciones.cantidadInicial('0'), isNull);
      expect(Validaciones.cantidadInicial('12'), isNull);
    });

    test('rechaza negativos, texto y valores fuera de rango', () {
      expect(Validaciones.cantidadInicial('-3'),
          'La cantidad inicial no puede ser negativa');
      expect(Validaciones.cantidadInicial('doce'),
          'La cantidad inicial debe ser un número entero');
      expect(Validaciones.cantidadInicial('2147483648'),
          'La cantidad inicial es demasiado grande');
    });
  });

  group('numeros', () {
    test('acepta coma decimal y rechaza NaN, Infinity y notacion cientifica', () {
      expect(Validaciones.leerNumero('12,50'), 12.5);
      expect(Validaciones.leerNumero(' 8 '), 8);
      expect(Validaciones.leerNumero('NaN'), isNull);
      expect(Validaciones.leerNumero('Infinity'), isNull);
      expect(Validaciones.leerNumero('1e5'), isNull);
      expect(Validaciones.aDecimal(' 12,5 '), '12.5');
    });

    test('monto: decimales, cero y tope de la columna', () {
      expect(Validaciones.monto('50,5'), isNull);
      expect(Validaciones.monto('NaN'), 'Ingresa un número válido (ej. 25.50)');
      expect(Validaciones.monto('0'), 'El monto debe ser mayor a 0');
      expect(Validaciones.monto('0', permitirCero: true), isNull);
      expect(Validaciones.monto('1.234'), 'Usa hasta 2 decimales');
      expect(Validaciones.monto('', obligatorio: false), isNull);
      expect(Validaciones.monto('99999999999'), startsWith('El monto es demasiado grande'));
    });

    test('precio respeta NUMERIC(10,2)', () {
      expect(Validaciones.precio('99999999.99', etiqueta: 'precio de venta'), isNull);
      expect(
        Validaciones.precio('100000000', etiqueta: 'precio de venta'),
        startsWith('El precio de venta es demasiado grande'),
      );
    });

    test('tipo de cambio admite 6 decimales y porcentaje va de 0 a 100', () {
      expect(Validaciones.tipoCambio('6,960000'), isNull);
      expect(Validaciones.tipoCambio('6.9600001'), 'Usa hasta 6 decimales');
      expect(Validaciones.porcentaje('100'), isNull);
      expect(Validaciones.porcentaje('100,01'), 'Ingresa un porcentaje entre 0 y 100');
      expect(Validaciones.porcentaje('', obligatorio: false), isNull);
    });

    test('entero: mínimo y tope de INTEGER', () {
      expect(Validaciones.entero('0'), 'La cantidad debe ser al menos 1');
      expect(Validaciones.entero('2147483648'), 'La cantidad es demasiado grande');
      expect(Validaciones.entero('3'), isNull);
    });
  });

  group('textos', () {
    test('motivo exige 3 caracteres sin contar espacios', () {
      expect(Validaciones.motivo('  ab  '), 'El motivo debe tener al menos 3 caracteres');
      expect(Validaciones.motivo('Error de cobro'), isNull);
    });

    test('contraseña: opcional al editar, pero si se escribe se válida', () {
      expect(Validaciones.contrasena('', obligatoria: false), isNull);
      expect(Validaciones.contrasena('abc', obligatoria: false),
          'La contraseña debe tener al menos 6 caracteres');
      expect(Validaciones.contrasena('      '),
          'La contraseña no puede ser solo espacios');
      expect(Validaciones.contrasena('Secreta1'), isNull);
    });

    test('url del servidor sin ruta ni espacios', () {
      expect(Validaciones.urlServidor('192.168.100.43:8000'), isNull);
      expect(Validaciones.urlServidor('http://192.168.100.43:8000/'), isNull);
      expect(Validaciones.urlServidor('http://192.168.100.43:8000/api'),
          contains('sin "/api" al final'));
      expect(Validaciones.urlServidor('192.168 .1.2'),
          'La dirección no puede tener espacios');
    });
  });
}
