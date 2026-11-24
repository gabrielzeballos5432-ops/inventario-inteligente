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
      return 'El nombre no puede contener números';
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
      return 'El nombre debe incluir letras, no solo números';
    }
    return null;
  }

  // ------------------------------------------------------------- numeros

  /// Numero decimal escrito por el usuario: digitos con punto o coma.
  ///
  /// El teclado numerico del celular en castellano pone coma, y antes la
  /// mitad de los formularios la rechazaba con "Monto invalido". Tampoco se
  /// usa double.tryParse a secas porque acepta "NaN", "Infinity" y "1e5", y
  /// NaN pasaba los controles `<= 0`.
  static final RegExp _decimal = RegExp(r'^-?\d+([.,]\d+)?$');

  /// Valor numerico, o null si el texto no es un numero simple.
  static double? leerNumero(String? valor) {
    final texto = valor?.trim() ?? '';
    if (!_decimal.hasMatch(texto)) return null;
    return double.tryParse(texto.replaceAll(',', '.'));
  }

  /// Texto listo para mandar al API como Decimal ("12,50" -> "12.50").
  static String aDecimal(String valor) => valor.trim().replaceAll(',', '.');

  static int _cantidadDecimales(String texto) {
    final partes = texto.trim().split(RegExp('[.,]'));
    return partes.length < 2 ? 0 : partes.last.length;
  }

  /// Tope de las columnas NUMERIC(12,2) (totales, montos de caja y pagos).
  /// Por encima la base responde con un error y no con un rechazo legible.
  static const double montoMaximo = 9999999999.99;

  /// Tope de NUMERIC(10,2), la precision de los precios del producto.
  static const double precioMaximo = 99999999.99;

  /// Monto de dinero.
  ///
  /// [etiqueta] va en minusculas ("monto", "importe") y [articulo] concuerda
  /// con ella ("El monto", "La cantidad").
  static String? monto(
    String? valor, {
    String etiqueta = 'monto',
    String articulo = 'El',
    bool obligatorio = true,
    bool permitirCero = false,
    int decimales = 2,
    double maximo = montoMaximo,
  }) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Escribe el $etiqueta' : null;
    final numero = leerNumero(texto);
    if (numero == null) return 'Ingresa un número válido (ej. 25.50)';
    if (numero < 0) return '$articulo $etiqueta no puede ser negativo';
    if (numero == 0 && !permitirCero) {
      return '$articulo $etiqueta debe ser mayor a 0';
    }
    if (_cantidadDecimales(texto) > decimales) {
      return decimales == 0
          ? 'Usa un número sin decimales'
          : 'Usa hasta $decimales decimales';
    }
    if (numero > maximo) {
      return '$articulo $etiqueta es demasiado grande '
          '(máximo ${maximo.toStringAsFixed(decimales)})';
    }
    return null;
  }

  /// Precio de compra o de venta.
  ///
  /// No acepta negativos ni cero: un producto sin precio real falsea la
  /// valorizacion del inventario y el margen.
  static String? precio(String? valor, {required String etiqueta}) =>
      monto(valor, etiqueta: etiqueta, maximo: precioMaximo);

  /// Tipo de cambio: mayor a 0 y hasta 6 decimales, como el backend.
  static String? tipoCambio(String? valor) => monto(
    valor,
    etiqueta: 'tipo de cambio',
    decimales: 6,
    maximo: 999999999999,
  );

  /// Porcentaje de 0 a 100 con hasta 2 decimales.
  static String? porcentaje(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Escribe el porcentaje' : null;
    final numero = leerNumero(texto);
    if (numero == null || numero < 0 || numero > 100) {
      return 'Ingresa un porcentaje entre 0 y 100';
    }
    if (_cantidadDecimales(texto) > 2) return 'Usa hasta 2 decimales';
    return null;
  }

  /// Numero entero entre [minimo] y [maximo] (por defecto el tope de INTEGER).
  static String? entero(
    String? valor, {
    String etiqueta = 'cantidad',
    String articulo = 'La',
    bool obligatorio = true,
    int minimo = 1,
    int maximo = stockMaximo,
  }) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Escribe la $etiqueta' : null;
    final numero = int.tryParse(texto);
    if (numero == null) return '$articulo $etiqueta debe ser un número entero';
    if (numero < minimo) {
      return minimo == 0
          ? '$articulo $etiqueta no puede ser negativa'
          : '$articulo $etiqueta debe ser al menos $minimo';
    }
    if (numero > maximo) return '$articulo $etiqueta es demasiado grande';
    return null;
  }

  /// Stock minimo. Admite 0 (deja el producto sin alerta de stock bajo),
  /// pero no negativos.
  static String? stockMinimo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final numero = int.tryParse(texto);
    if (numero == null) return 'El stock mínimo debe ser un número entero';
    if (numero < 0) return 'El stock mínimo no puede ser negativo';
    if (numero > stockMaximo) return 'El stock mínimo es demasiado grande';
    return null;
  }

  // -------------------------------------------------------------- textos

  /// Campo de texto obligatorio sin otra regla (concepto, nombre de cliente).
  static String? obligatorio(String? valor, {String mensaje = 'Completa este campo'}) =>
      (valor?.trim() ?? '').isEmpty ? mensaje : null;

  /// Motivo de una anulacion: el backend exige al menos 3 caracteres.
  static String? motivo(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe el motivo';
    if (texto.length < 3) return 'El motivo debe tener al menos 3 caracteres';
    return null;
  }

  /// Contrasena de un usuario: de 6 a 128 caracteres, como el backend. Al
  /// editar puede quedar vacia (no se cambia), pero si se escribe se valida:
  /// antes "abc" pasaba en la app y el backend lo rechazaba con un 422.
  static String? contrasena(String? valor, {bool obligatoria = true}) {
    final texto = valor ?? '';
    if (texto.isEmpty) return obligatoria ? 'Escribe la contraseña' : null;
    if (texto.trim().isEmpty) return 'La contraseña no puede ser solo espacios';
    if (texto.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    if (texto.length > 128) return 'La contraseña admite hasta 128 caracteres';
    return null;
  }

  /// Direccion del backend: host valido, sin espacios y sin ruta.
  ///
  /// Una ruta como "http://ip:8000/api" hacia que todas las llamadas fueran a
  /// "/api/api/..." y la app quedaba "sin conexion" sin explicar por que.
  static String? urlServidor(String? valor) {
    var texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Escribe la dirección del servidor';
    if (texto.contains(' ')) return 'La dirección no puede tener espacios';
    if (!texto.startsWith('http://') && !texto.startsWith('https://')) {
      texto = 'http://$texto';
    }
    final uri = Uri.tryParse(texto);
    if (uri == null || uri.host.isEmpty) {
      return 'Dirección no válida (ej. http://192.168.100.43:8000)';
    }
    final ruta = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (ruta.isNotEmpty) {
      return 'Escribe solo la IP y el puerto, sin "$ruta" al final';
    }
    return null;
  }

  /// Mayor entero que guarda la columna de stock (INTEGER de PostgreSQL).
  static const int stockMaximo = 2147483647;

  /// Cantidad inicial al crear un producto.
  ///
  /// Opcional: vacio cuenta como 0 (el producto nace sin stock). No admite
  /// negativos; si es mayor a 0 se registra una entrada automatica.
  static String? cantidadInicial(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final numero = int.tryParse(texto);
    if (numero == null) return 'La cantidad inicial debe ser un número entero';
    if (numero < 0) return 'La cantidad inicial no puede ser negativa';
    if (numero > stockMaximo) return 'La cantidad inicial es demasiado grande';
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
    if (numero == null) return 'La cantidad debe ser un número entero';
    if (numero < 0) return 'La cantidad no puede ser negativa';
    if (numero > stockMaximo) return 'La cantidad es demasiado grande';
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
      return 'El teléfono solo admite números y los signos + - ( )';
    }
    if (!_tieneNumero.hasMatch(texto)) return 'El teléfono debe incluir números';
    return null;
  }

  /// Correo: opcional u obligatorio segun el formulario, pero si se escribe
  /// tiene que tener forma de correo.
  static String? correo(String? valor, {bool obligatorio = true}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return obligatorio ? 'Escribe el correo' : null;
    if (!_correo.hasMatch(texto)) {
      return 'Ingresa un correo válido (ej. nombre@correo.com)';
    }
    return null;
  }
}
