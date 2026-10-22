import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Sidebar (menu lateral) global: concentra la identidad del usuario, la
/// navegacion y las opciones de cuenta que antes vivian desparramadas en el
/// menu de tres puntos de la app bar.
///
/// La separacion por secciones (Operacion, Cuenta) no es decorativa: en un
/// telefono de 6 pulgadas el drawer muestra solo la mitad de la lista, asi
/// que lo de uso diario va arriba y las acciones de cuenta, abajo.
class MenuLateral extends StatelessWidget {
  final List<NavigationDestination> elementos;
  final int seleccion;
  final String usuarioNombre;
  final String rol;
  final bool esNoche;

  /// Con admin aparecen los catalogos por su nombre (antes vivian escondidos
  /// en un menu de tres puntos de la pestaña Productos): cada fila abre el
  /// dialogo de gestion directo.
  final bool mostrarGestion;

  final ValueChanged<int> alNavegar;
  final VoidCallback alAlternarTema;
  final VoidCallback alConfigurarServidor;
  final VoidCallback alCerrarSesion;
  final ValueChanged<String> alAbrirCatalogo;

  const MenuLateral({
    super.key,
    required this.elementos,
    required this.seleccion,
    required this.usuarioNombre,
    required this.rol,
    required this.esNoche,
    required this.mostrarGestion,
    required this.alNavegar,
    required this.alAlternarTema,
    required this.alConfigurarServidor,
    required this.alCerrarSesion,
    required this.alAbrirCatalogo,
  });

  String get _inicial {
    final nombre = usuarioNombre.trim();
    return nombre.isEmpty ? 'Z' : nombre[0].toUpperCase();
  }

  Widget _tituloSeccion(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(
          texto.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: context.textoTerciario,
          ),
        ),
      );

  Widget _item(
    BuildContext context,
    NavigationDestination destino,
    int indice,
  ) {
    final enAqui = seleccion == indice;
    final tono = enAqui ? context.paleta.info : context.textoPrimario;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: Icon((destino.icon as Icon).icon, color: tono),
          title: Text(
            destino.label,
            style: TextStyle(
              fontWeight: enAqui ? FontWeight.w700 : FontWeight.w500,
              color: tono,
            ),
          ),
          // El color activo sale del esquema del tema (mismo tono que usa el
          // NavigationBar); el fondo es el mismo tono al 12% para marcar la
          // pestana sin inventar colores (el test de contraste sigue valiendo).
          tileColor: enAqui ? context.paleta.info.withValues(alpha: 0.12) : null,
          onTap: () {
            Navigator.of(context).pop(); // cierra el drawer
            alNavegar(indice);
          },
        ),
      ),
    );
  }

  /// Fila de gestion de catalogos: misma forma que _item pero con callback
  /// propio, porque abren un dialogo (que se muestra sobre el shell) en vez
  /// de cambiar de pestana.
  Widget _filaCatalogo(
    BuildContext context,
    IconData icono,
    String texto,
    String clave,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: Icon(icono, color: context.textoPrimario),
          title: Text(texto, style: TextStyle(color: context.textoPrimario)),
          onTap: () {
            // El dialogo se pide cuando el drawer ya se va, para que la
            // animacion del menu no pelee con la del dialogo: showdialog se
            // llama desde el contexto del shell, no del drawer.
            Navigator.of(context).pop();
            alAbrirCatalogo(clave);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.superficie,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Encabezado de marca: mismo degradado que el login y texto en
            // blanco porque va encima de morado fijo, El degradado no cambia
            // con el modo porque es el color de la marca.
            _Encabezado(inicial: _inicial, nombre: usuarioNombre, rol: rol),
            _tituloSeccion(context, 'Operacion'),
            for (var i = 0; i < elementos.length; i++)
              _item(context, elementos[i], i),
            if (mostrarGestion) ...[
              _tituloSeccion(context, 'Gestion'),
              _filaCatalogo(context, Icons.category_outlined, 'Categorias', 'categorias'),
              _filaCatalogo(context, Icons.label_outline, 'Marcas', 'marcas'),
              _filaCatalogo(context, Icons.local_shipping_outlined, 'Proveedores', 'proveedores'),
            ],
            _tituloSeccion(context, 'Cuenta'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(
                  esNoche ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: context.textoPrimario,
                ),
                title: Text('Modo noche', style: TextStyle(color: context.textoPrimario)),
                // Switch con estado visible: antes era una opcion que decia
                // "cambiar a modo claro/noche" sin mostrar en cual estabas.
                trailing: Switch(value: esNoche, onChanged: (_) => alAlternarTema()),
                onTap: alAlternarTema,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(Icons.dns_outlined, color: context.textoPrimario),
                title: Text('Configurar servidor',
                    style: TextStyle(color: context.textoPrimario)),
                onTap: () {
                  Navigator.of(context).pop();
                  alConfigurarServidor();
                },
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(Icons.logout, color: context.paleta.negativo),
                title: Text(
                  'Cerrar sesion',
                  style: TextStyle(
                    color: context.paleta.negativo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  alCerrarSesion();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                'Zoomventory 1.0',
                style: TextStyle(fontSize: 11, color: context.textoTerciario),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera del drawer con el degradado de marca de la app: la excepcion
/// documentada de texto blanco fijo (el fondo morado no cambia con el modo).
class _Encabezado extends StatelessWidget {
  final String inicial;
  final String nombre;
  final String rol;

  const _Encabezado({
    required this.inicial,
    required this.nombre,
    required this.rol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.morado, Color(0xFF3F2783)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Text(
              inicial,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rol,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
