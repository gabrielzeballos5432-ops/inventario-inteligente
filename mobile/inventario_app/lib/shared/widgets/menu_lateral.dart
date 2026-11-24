import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/destino_app.dart';

/// Navegacion agrupada por tareas; desplegable en movil y fija en escritorio.
class MenuLateral extends StatelessWidget {
  final List<DestinoApp> elementos;
  final DestinoApp seleccion;
  final bool permanente;
  final String usuarioNombre;
  final String rol;
  final bool esNoche;

  final bool mostrarGestion;

  final ValueChanged<DestinoApp> alNavegar;
  final VoidCallback alAlternarTema;
  final VoidCallback alConfigurarServidor;
  final VoidCallback alCerrarSesion;

  const MenuLateral({
    super.key,
    required this.elementos,
    required this.seleccion,
    this.permanente = false,
    required this.usuarioNombre,
    required this.rol,
    required this.esNoche,
    required this.mostrarGestion,
    required this.alNavegar,
    required this.alAlternarTema,
    required this.alConfigurarServidor,
    required this.alCerrarSesion,
  });

  String get _inicial {
    final nombre = usuarioNombre.trim();
    return nombre.isEmpty ? 'Z' : nombre[0].toUpperCase();
  }

  Widget _tituloSeccion(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
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
    DestinoApp destino,
  ) {
    final enAqui = seleccion == destino;
    final tono = enAqui ? context.paleta.info : context.textoPrimario;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: Icon(destino.icono, color: tono),
          title: Text(
            destino.etiqueta(mostrarGestion),
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
            _cerrar(context);
            alNavegar(destino);
          },
        ),
      ),
    );
  }

  void _cerrar(BuildContext context) {
    if (!permanente) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: permanente ? 252 : null,
      shape: permanente ? const RoundedRectangleBorder() : null,
      backgroundColor: context.superficie,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Encabezado de marca: mismo degradado que el login y texto en
            // blanco porque va encima de morado fijo, El degradado no cambia
            // con el modo porque es el color de la marca.
            _Encabezado(inicial: _inicial, nombre: usuarioNombre, rol: rol),
            for (var i = 0; i < elementos.length; i++) ...[
              if (elementos[i].grupo.isNotEmpty &&
                  (i == 0 || elementos[i].grupo != elementos[i - 1].grupo))
                _tituloSeccion(context, elementos[i].grupo),
              _item(context, elementos[i]),
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
                  _cerrar(context);
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
                  'Cerrar sesión',
                  style: TextStyle(
                    color: context.paleta.negativo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  _cerrar(context);
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.morado, Color(0xFF3F2783)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Text(
              inicial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  rol,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
