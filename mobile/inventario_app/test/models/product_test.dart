import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/core/models/product.dart';

void main() {
  group('ProductoConStock.fromJson', () {
    test('parsea precios Decimal serializados como string', () {
      final json = {
        'id': 2,
        'sku': null,
        'codigo_barras': null,
        'nombre': 'Peroxido 20v',
        'descripcion': null,
        'categoria_id': 1,
        'categoria': {'id': 1, 'nombre': 'General', 'padre_id': null},
        'marca_id': null,
        'proveedor_id': null,
        'precio_compra': '8.00',
        'precio_venta': '18.00',
        'stock_minimo': 5,
        'activo': true,
        'stock_actual': 1,
        'stock_bajo': true,
      };

      final producto = ProductoConStock.fromJson(json);

      expect(producto.precioCompra, 8.0);
      expect(producto.precioVenta, 18.0);
      expect(producto.stockActual, 1);
      expect(producto.stockBajo, isTrue);
      expect(producto.categoria?.nombre, 'General');
    });

    test('parsea precios cuando llegan como número', () {
      final producto = ProductoConStock.fromJson({
        'id': 1,
        'nombre': 'Shampoo',
        'precio_compra': 10,
        'precio_venta': 25.5,
        'stock_minimo': 3,
        'activo': true,
        'stock_actual': 7,
        'stock_bajo': false,
      });

      expect(producto.precioCompra, 10.0);
      expect(producto.precioVenta, 25.5);
    });

    test('usa valores por defecto si el precio es inválido', () {
      final producto = ProductoConStock.fromJson({
        'id': 1,
        'nombre': 'Condicionador',
        'precio_compra': 'no-numerico',
        'stock_minimo': 2,
        'activo': true,
        'stock_actual': 0,
        'stock_bajo': false,
      });

      expect(producto.precioCompra, 0.0);
    });
  });
}
