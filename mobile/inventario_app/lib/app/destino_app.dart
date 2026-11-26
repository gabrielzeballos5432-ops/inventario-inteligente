import 'package:flutter/material.dart';

enum DestinoApp {
  panel('Inicio', Icons.dashboard_outlined, ''),
  ventas('Ventas', Icons.point_of_sale_outlined, 'Operación'),
  caja(
    'Caja',
    Icons.account_balance_wallet_outlined,
    'Operación',
    lectura: true,
  ),
  compras('Compras', Icons.shopping_bag_outlined, 'Operación', soloAdmin: true),
  productos('Productos', Icons.inventory_2_outlined, 'Inventario'),
  movimientos('Movimientos', Icons.swap_vert, 'Inventario'),
  deteccion(
    'Detección',
    Icons.image_search_outlined,
    'Inventario',
    lectura: true,
  ),
  gastos('Gastos', Icons.receipt_long_outlined, 'Finanzas', soloAdmin: true),
  resultados(
    'Resultados',
    Icons.query_stats_outlined,
    'Finanzas',
    soloAdmin: true,
  ),
  jornadas('Jornadas y sueldos', Icons.access_time, 'Equipo', lectura: true),
  bonos(
    'Bonos',
    Icons.card_giftcard_outlined,
    'Equipo',
    soloAdmin: true,
    lectura: true,
  ),
  clientes(
    'Clientes',
    Icons.people_outline,
    'Administración',
    soloAdmin: true,
    lectura: true,
  ),
  usuarios(
    'Usuarios',
    Icons.manage_accounts_outlined,
    'Administración',
    soloAdmin: true,
    lectura: true,
  ),
  categorias(
    'Categorías',
    Icons.category_outlined,
    'Administración',
    soloAdmin: true,
    lectura: true,
  ),
  marcas(
    'Marcas',
    Icons.label_outline,
    'Administración',
    soloAdmin: true,
    lectura: true,
  ),
  proveedores(
    'Proveedores',
    Icons.local_shipping_outlined,
    'Administración',
    soloAdmin: true,
    lectura: true,
  ),
  configuracion(
    'Configuración',
    Icons.settings_outlined,
    'Administración',
    soloAdmin: true,
    lectura: true,
  );

  const DestinoApp(
    this.titulo,
    this.icono,
    this.grupo, {
    this.soloAdmin = false,
    this.lectura = false,
  });

  final String titulo;
  final IconData icono;
  final String grupo;
  final bool soloAdmin;

  /// Seccion de lista o formulario: una fila con solo un nombre no necesita
  /// 1200 px. Ver [anchoMaximo].
  final bool lectura;

  /// Ancho maximo del contenido, centrado en pantallas anchas. Las listas y
  /// formularios se leen mejor angostos; tablas, tarjetas y la venta usan mas.
  double get anchoMaximo => lectura ? 960 : 1280;

  String etiqueta(bool esAdmin) =>
      this == jornadas && !esAdmin ? 'Mi jornada' : titulo;

  static List<DestinoApp> disponibles(bool esAdmin) =>
      values.where((destino) => esAdmin || !destino.soloAdmin).toList();
}
