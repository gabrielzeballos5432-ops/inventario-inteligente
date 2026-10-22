/// Reglas de validacion compartidas por los formularios.
///
/// Los mensajes se redactan en el tono del resto de la app (sin tildes) y
/// explican *que* no se admite y, cuando aplica, cual es el limite, para que
/// el usuario no tenga que adivinar por que no lo deja guardar.
///
/// Viven aqui, y no en cada formulario, para que la regla sea la misma en el
/// alta y en la edicion, y en la app y el backend (longitudes y signos).
class Validaciones {
  Validaciones._();

  /// Letras (con acentos), espacios y los separadores que si aparecen en
  /// nombres reales: punto, coma, guion, ampersand y apostrofo.
  static final RegExp _nombrePermitido =
      RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s'’.,&-]+$");
  static final RegExp _tieneNumero = RegExp(r'[0-9]');
  static final RegExp _tieneLetra = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
  static final RegExp _telefonoPermitido = RegExp(r'^[0-9+\-\s()]+$');
  static final RegExp _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Nombre de persona, categoria, marca o proveedor.
  ///
  /// No admite numeros: suelen ser un tecleo incompleto o un dato pegado por
  /// error, y ensucian los catalogos (por ejemplo "Uñas 2" o "123").
  static String? nombreSinNumeros(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe el nombre';
    if (_tieneNumero.hasMatch(texto)) {
      return 'El nombre no puede contener numeros';
    }
    if (!_nombrePermitido.hasMatch(texto)) {
      return "El nombre solo admite letras y espacios ( . , - & ' )";
    }
    return null;
  }

  /// Nombre de producto.
  ///
  /// Aqui si se permiten numeros porque forman parte del nombre comercial
  /// ("Shampoo 400 ml", "Tinte 7.1"), pero se exige al menos una letra para
  /// que "123" o "500" no pasen como nombre.
  static String? nombreProducto(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe el nombre del producto';
    if (!_tieneLetra.hasMatch(texto)) {
      return 'El nombre debe incluir letras, no solo numeros';
    }
    return null;
  }

  /// Precio de compra o de venta.
  ///
  /// No acepta negativos ni cero: un producto sin precio real falsea la
  /// valorizacion del inventario y el margen.
  static String? precio(String? valor, {required String etiqueta}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe el $etiqueta';
    final numero = double.tryParse(texto.replaceAll(',', '.'));
    if (numero == null) return 'Ingresa un numero valido (ej. 25.50)';
    if (numero < 0) return 'El $etiqueta no puede ser negativo';
    if (numero == 0) return 'El $etiqueta debe ser mayor a 0';
    return null;
  }

  /// Stock minimo. Admite 0 (deja el producto sin alerta de stock bajo),
  /// pero no negativos.
  static String? stockMinimo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final numero = int.tryParse(texto);
    if (numero == null) return 'El stock minimo debe ser un numero entero';
    if (numero < 0) return 'El stock minimo no puede ser negativo';
    return null;
  }

  /// Cantidad de un movimiento.
  ///
  /// Entrada y salida exigen mas de 0. El ajuste fija el stock exacto, asi
  /// que si admite 0. En una salida no se puede sacar mas de lo que hay.
  static String? cantidad(
    String? valor, {
    required String tipo,
    int? stockDisponible,
  }) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe la cantidad';
    final numero = int.tryParse(texto);
    if (numero == null) return 'La cantidad debe ser un numero entero';
    if (numero < 0) return 'La cantidad no puede ser negativa';
    if (tipo == 'ajuste') return null;
    if (numero == 0) return 'La cantidad debe ser mayor a 0';
    if (tipo == 'salida' &&
        stockDisponible != null &&
        numero > stockDisponible) {
      return 'No hay stock suficiente: disponible $stockDisponible';
    }
    return null;
  }

  /// Telefono: opcional, pero si se escribe solo admite digitos y los signos
  /// habituales de un numero telefonico.
  static String? telefono(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    if (!_telefonoPermitido.hasMatch(texto)) {
      return 'El telefono solo admite numeros y los signos + - ( )';
    }
    if (!_tieneNumero.hasMatch(texto)) return 'El telefono debe incluir numeros';
    return null;
  }

  /// Correo: opcional u obligatorio segun el formulario, pero si se escribe
  /// tiene que tener forma de correo.
  static String? correo(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Escribe el correo' : null;
    if (!_correo.hasMatch(texto)) {
      return 'Ingresa un correo valido (ej. nombre@correo.com)';
    }
    return null;
  }
}
