import 'package:flutter/material.dart';

/// Ancho minimo de todo dialogo (`dialogTheme.constraints`).
///
/// Sin el, `AlertDialog` se encoge al ancho de su contenido: en escritorio
/// los formularios quedaban en una columna de 280 px. En el telefono el
/// minimo se recorta solo al ancho disponible.
const double anchoMinimoDialogo = 440;

/// `builder` para `showDatePicker`: el selector de fecha tambien es un
/// `Dialog` y con [anchoMinimoDialogo] el calendario se estiraba. Le devuelve
/// el minimo por defecto de Flutter (280).
Widget selectorFechaSinAnchoMinimo(BuildContext context, Widget? child) {
  final tema = Theme.of(context);
  return Theme(
    data: tema.copyWith(
      dialogTheme: tema.dialogTheme.copyWith(
        constraints: const BoxConstraints(minWidth: 280),
      ),
    ),
    child: child!,
  );
}

/// Paleta de marca de la aplicacion: morado medio oscuro como color principal,
/// con negro al fondo, plomo en las superficies y blanco para el texto.
///
/// Son los colores de identidad y NO dependen del modo: se usan para el
/// color principal, la marca y los acentos. Para texto, superficies o estados
/// hay que usar [AppPaleta], que si cambia entre modo claro y modo noche.
///
/// Antes el tema era azul verdoso (teal). Se cambio para respetar la identidad
/// visual de Zoomventory y separar el producto de la paleta por defecto de
/// Material.
class AppColors {
  const AppColors._();

  /// Morado medio oscuro. Es el color de marca y la semilla del tema.
  static const morado = Color(0xFF5E35B1);

  /// Morado claro: bordes de foco, enfasis y elementos activos.
  static const moradoClaro = Color(0xFFB39DDB);

  /// Negro azulado, fondo general del modo noche.
  static const negro = Color(0xFF0A0A0F);

  /// Plomo oscuro, tarjetas y superficies del modo noche.
  static const plomo = Color(0xFF1C1C26);

  /// Plomo un poco mas claro, campos de formulario y chips del modo noche.
  static const plomoClaro = Color(0xFF2A2A38);

  /// Blanco puro, texto principal.
  static const blanco = Colors.white;

  /// Blanco al 70 %, texto secundario.
  static const blancoSuave = Color(0xB3FFFFFF);

  /// Blanco al 54 %, texto terciario.
  static const blancoTenue = Color(0x8AFFFFFF);
}

/// Paleta semantica que se adapta al modo claro y al modo noche.
///
/// Existe porque los colores de estado (stock bajo, error, correcto) no pueden
/// ser los mismos en los dos modos: el naranja de Material se lee bien sobre
/// negro, pero casi no se ve sobre blanco. Al meterlos en el tema, cada widget
/// pide `AppPaleta.of(context).stockBajo` y obtiene el tono con contraste
/// correcto en el modo activo, sin tener que comprobar el brightness a mano.
@immutable
class AppPaleta extends ThemeExtension<AppPaleta> {
  const AppPaleta({
    required this.fondo,
    required this.superficie,
    required this.superficieElevada,
    required this.textoPrimario,
    required this.textoSecundario,
    required this.textoTerciario,
    required this.borde,
    required this.stockBajo,
    required this.positivo,
    required this.negativo,
    required this.aviso,
    required this.info,
  });

  /// Fondo general de la pantalla.
  final Color fondo;

  /// Tarjetas, dialogos, hojas y menus.
  final Color superficie;

  /// Campos de formulario, chips y zonas hundidas.
  final Color superficieElevada;

  final Color textoPrimario;

  /// Descripciones y etiquetas secundarias.
  final Color textoSecundario;

  /// Marcas de agua y texto deshabilitado.
  final Color textoTerciario;

  final Color borde;

  /// Producto por debajo del minimo y avisos derotura de stock.
  final Color stockBajo;

  /// Entradas de stock, ingresos y confirmaciones.
  final Color positivo;

  /// Salidas de stock, errores y acciones destructivas.
  final Color negativo;

  final Color aviso;

  final Color info;

  /// Paleta del modo noche: la que tenia la app antes de anadir el modo claro.
  static const oscuro = AppPaleta(
    fondo: AppColors.negro,
    superficie: AppColors.plomo,
    superficieElevada: AppColors.plomoClaro,
    textoPrimario: AppColors.blanco,
    textoSecundario: AppColors.blancoSuave,
    textoTerciario: AppColors.blancoTenue,
    borde: Color(0xFF34344A),
    stockBajo: Color(0xFFFF9800),
    positivo: Color(0xFF4CAF50),
    negativo: Color(0xFFFF5252),
    aviso: Color(0xFFFFC107),
    info: AppColors.moradoClaro,
  );

  /// Paleta del modo claro. Los tonos de estado se oscurecen para mantener el
  /// contraste sobre fondo casi blanco: el naranja de Material pasa de ~2.8:1
  /// a ~5.2:1, que es lo que pide WCAG para texto normal.
  static const claro = AppPaleta(
    fondo: Color(0xFFF6F4FA),
    superficie: Colors.white,
    superficieElevada: Color(0xFFEDEAF6),
    textoPrimario: Color(0xFF1B1B24),
    textoSecundario: Color(0xFF55555F),
    textoTerciario: Color(0xFF85858F),
    borde: Color(0xFFE0DCEB),
    stockBajo: Color(0xFFB24C00),
    positivo: Color(0xFF1B5E20),
    negativo: Color(0xFFB3261E),
    aviso: Color(0xFF8A5A00),
    info: Color(0xFF4527A0),
  );

  /// Acceso corto desde un `BuildContext`.
  static AppPaleta of(BuildContext context) =>
      Theme.of(context).extension<AppPaleta>() ?? oscuro;

  @override
  AppPaleta copyWith({
    Color? fondo,
    Color? superficie,
    Color? superficieElevada,
    Color? textoPrimario,
    Color? textoSecundario,
    Color? textoTerciario,
    Color? borde,
    Color? stockBajo,
    Color? positivo,
    Color? negativo,
    Color? aviso,
    Color? info,
  }) {
    return AppPaleta(
      fondo: fondo ?? this.fondo,
      superficie: superficie ?? this.superficie,
      superficieElevada: superficieElevada ?? this.superficieElevada,
      textoPrimario: textoPrimario ?? this.textoPrimario,
      textoSecundario: textoSecundario ?? this.textoSecundario,
      textoTerciario: textoTerciario ?? this.textoTerciario,
      borde: borde ?? this.borde,
      stockBajo: stockBajo ?? this.stockBajo,
      positivo: positivo ?? this.positivo,
      negativo: negativo ?? this.negativo,
      aviso: aviso ?? this.aviso,
      info: info ?? this.info,
    );
  }

  @override
  AppPaleta lerp(AppPaleta? other, double t) {
    if (other == null) {
      return this;
    }
    return AppPaleta(
      fondo: Color.lerp(fondo, other.fondo, t)!,
      superficie: Color.lerp(superficie, other.superficie, t)!,
      superficieElevada: Color.lerp(superficieElevada, other.superficieElevada, t)!,
      textoPrimario: Color.lerp(textoPrimario, other.textoPrimario, t)!,
      textoSecundario: Color.lerp(textoSecundario, other.textoSecundario, t)!,
      textoTerciario: Color.lerp(textoTerciario, other.textoTerciario, t)!,
      borde: Color.lerp(borde, other.borde, t)!,
      stockBajo: Color.lerp(stockBajo, other.stockBajo, t)!,
      positivo: Color.lerp(positivo, other.positivo, t)!,
      negativo: Color.lerp(negativo, other.negativo, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Atajos para no repetir `AppPaleta.of(context)` en cada widget.
extension AppPaletaContext on BuildContext {
  AppPaleta get paleta => AppPaleta.of(this);
  Color get textoPrimario => paleta.textoPrimario;
  Color get textoSecundario => paleta.textoSecundario;
  Color get textoTerciario => paleta.textoTerciario;
  Color get superficie => paleta.superficie;
  Color get superficieElevada => paleta.superficieElevada;
  Color get colorBorde => paleta.borde;
}

/// Tema del modo noche. Conserva exactamente el aspecto que tenia la app antes
/// de anadir el modo claro.
ThemeData buildTemaNoche() => _buildTema(
      Brightness.dark,
      ColorScheme.fromSeed(
        seedColor: AppColors.morado,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.morado,
        secondary: AppColors.moradoClaro,
      ),
      AppPaleta.oscuro,
    );

/// Tema del modo claro.
ThemeData buildTemaClaro() => _buildTema(
      Brightness.light,
      ColorScheme.fromSeed(
        seedColor: AppColors.morado,
        brightness: Brightness.light,
      ).copyWith(
        // Forzado como en noche: fromSeed lo bajaba a un morado grisaceo
        // (#65558F) y en claro la app perdia el color de marca. Con texto
        // blanco encima da ~8:1 de contraste.
        primary: AppColors.morado,
        secondary: const Color(0xFF7E57C2),
      ),
      AppPaleta.claro,
    );

/// Tema segun el modo pedido. Se conserva por si algun widget lo pide.
ThemeData buildAppTheme(Brightness brightness) =>
    brightness == Brightness.dark ? buildTemaNoche() : buildTemaClaro();

ThemeData _buildTema(Brightness brightness, ColorScheme scheme, AppPaleta p) {
  // El morado de marca necesita texto blanco encima en los dos modos.
  final esquema = scheme.copyWith(onPrimary: Colors.white);

  final radioBorde = BorderRadius.circular(12);
  final radioTarjeta = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    // Interfaz compacta: la app se usa sobre todo en el telefono y con el
    // teclado abierto queda media pantalla. Los toques siguen >= 40-44 dp.
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    brightness: brightness,
    colorScheme: esquema,
    extensions: <ThemeExtension<dynamic>>[p],
    scaffoldBackgroundColor: p.fondo,
    dividerTheme: DividerThemeData(color: p.borde, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.textoPrimario,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.superficie,
      indicatorColor: AppColors.morado.withValues(alpha: 0.28),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: p.textoSecundario),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.superficie,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      // Borde sutil: sin el, en modo claro las tarjetas blancas se funden con
      // el fondo casi blanco y en noche el plomo se pierde contra el negro.
      shape: RoundedRectangleBorder(
        borderRadius: radioTarjeta,
        side: BorderSide(color: p.borde, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // El inset por defecto (40 dp) deja el formulario en una columna
      // angosta en el telefono; con 12 dp aprovecha casi todo el ancho.
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      // Sin minimo, AlertDialog se encoge a su contenido y en escritorio los
      // formularios quedaban en 280 px. En el telefono se recorta solo al
      // ancho disponible. Los selectores de fecha restauran el ancho propio
      // con `selectorFechaSinAnchoMinimo` (se estiraban).
      constraints: const BoxConstraints(minWidth: anchoMinimoDialogo),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.textoPrimario,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.superficie,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radioTarjeta),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: p.superficie),
    listTileTheme: ListTileThemeData(
      iconColor: p.textoSecundario,
      textColor: p.textoPrimario,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.superficieElevada,
      side: BorderSide(color: p.borde),
      labelStyle: TextStyle(color: p.textoPrimario),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.superficieElevada,
      contentTextStyle: TextStyle(color: p.textoPrimario),
      actionTextColor: AppColors.moradoClaro,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radioBorde),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.superficieElevada,
      // Campos densos (~48 dp): con el teclado abierto caben mas filas sin
      // desplazarse y la etiqueta flotante sigue legible.
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(color: p.textoTerciario),
      labelStyle: TextStyle(color: p.textoSecundario),
      prefixIconColor: p.textoSecundario,
      border: OutlineInputBorder(
        borderRadius: radioBorde,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radioBorde,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radioBorde,
        borderSide: BorderSide(
          // En claro el morado claro casi no se distingue del fondo.
          color: brightness == Brightness.dark
              ? AppColors.moradoClaro
              : AppColors.morado,
          width: 1.5,
        ),
      ),
    ),
    // Botones compactos y consistentes en toda la app: 44 dp de alto (minimo
    // comodo para el pulgar segun WCAG 2.5.8) y letra 15, para que formularios
    // y tablas quepan en el telefono sin desbordarse. Los colores no se tocan
    // aqui porque los botones heredan el esquema y theme_test.dart lo valida.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: p.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: p.textoPrimario),
      bodySmall: TextStyle(color: p.textoSecundario),
      titleLarge: TextStyle(color: p.textoPrimario),
      titleMedium: TextStyle(color: p.textoPrimario),
      titleSmall: TextStyle(color: p.textoPrimario),
      labelLarge: TextStyle(color: p.textoPrimario),
      labelMedium: TextStyle(color: p.textoSecundario),
      labelSmall: TextStyle(color: p.textoTerciario),
    ),
  );
}