import '../../../app/theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/models/role_option.dart';
import '../../../core/models/user_account.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/user_service.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/validaciones.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/boton_seguro.dart';

/// Estado del listado de roles dentro del panel de usuarios. Distingue
/// cargando, fallo y listo para no habilitar el alta de usuarios con una
/// lista de roles vacia, que es como se degradaba el formulario.
class RolesEstado {
  const RolesEstado({required this.puedeEditar, this.mensaje});

  final bool puedeEditar;
  final String? mensaje;
}

RolesEstado _estadoDe(AsyncSnapshot<List<RoleOption>> snapshot) {
  if (snapshot.connectionState == ConnectionState.waiting) {
    return const RolesEstado(puedeEditar: false);
  }
  if (snapshot.hasError) {
    return const RolesEstado(
      puedeEditar: false,
      mensaje:
          'No se pudieron cargar los roles. El alta y la edicion de '
          'usuarios quedan deshabilitadas hasta recuperar la lista.',
    );
  }
  final roles = snapshot.data ?? const <RoleOption>[];
  if (roles.isEmpty) {
    return const RolesEstado(
      puedeEditar: false,
      mensaje:
          'El servidor no devolvio ningun rol, asi que no se puede '
          'asignar uno a un usuario.',
    );
  }
  return const RolesEstado(puedeEditar: true);
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with WidgetsBindingObserver {
  final _service = UserService(ApiClient());
  int _reloadTick = 0;

  // Los futuros viven en el estado, no en el build. Antes se creaban dentro
  // de build, lo que hacia una peticion en cada reconstruccion y dejaba la
  // lista desactualizada: un usuario recien creado no aparecia hasta
  // reiniciar sesion.
  late Future<List<RoleOption>> _futureRoles;
  late Future<List<UserAccount>> _futureUsuarios;

  // Cada cuanto se pregunta al servidor por cambios que otros usuarios
  // hayan hecho. Con esto la lista se actualiza sola sin salir/entrar.
  static const _intervaloActualizacion = Duration(seconds: 30);

  Timer? _relojActualizacion;

  @override
  void initState() {
    super.initState();
    _futureRoles = _service.fetchRoles();
    _futureUsuarios = _service.fetchUsers();
    WidgetsBinding.instance.addObserver(this);
    _relojActualizacion = Timer.periodic(_intervaloActualizacion, (_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _relojActualizacion?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Al volver a abrir la app (desde background) se pide la lista fresca.
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _reloadTick++;
      _futureRoles = _service.fetchRoles();
      _futureUsuarios = _service.fetchUsers();
    });
  }

  Future<void> _openUserDialog({
    UserAccount? user,
    required List<RoleOption> roles,
  }) async {
    // Nadie edita su propia cuenta desde la lista: cambiar el propio rol o
    // correo por la via de administracion deja la sesion con datos que ya no
    // corresponden al token que se esta usando.
    final sessionUserId = SessionController.instance.user?.id;
    if (user != null && user.id == sessionUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes editar tu propia cuenta desde aqui.'),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _UserFormDialog(user: user, roles: roles, service: _service),
    );

    if (saved == true) {
      _refresh();
    }
  }

  Future<void> _deactivateUser(UserAccount user) async {
    final sessionUserId = SessionController.instance.user?.id;
    if (sessionUserId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No es posible desactivar tu propia cuenta desde esta sesion.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Desactivar usuario'),
        content: Text('Se desactivara la cuenta de ${user.nombreCompleto}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          BotonSeguro(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deactivateUser(user.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${user.nombre} desactivado.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo desactivar el usuario: $error')),
      );
    }
  }

  Future<void> _activateUser(UserAccount user) async {
    try {
      await _service.activateUser(user.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario ${user.nombre} reactivado.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo activar el usuario: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionController.instance;
    if (!session.isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          // El titulo de la pestana ya lo muestra la AppBar.
          SectionCard(
            child: Text(
              'Solo un administrador puede ver y gestionar el panel de usuarios.',
            ),
          ),
        ],
      );
    }

    return FutureBuilder<List<RoleOption>>(
      key: ValueKey(_reloadTick),
      future: _futureRoles,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? const <RoleOption>[];

        // El boton Registrar se habilita solo con los dos listados en mano:
        // con los usuarios cargados pero los roles todavia en vuelo se abria
        // el formulario sin combo de rol y el alta fallaba en el backend.
        final RolesEstado estadoRoles = _estadoDe(snapshot);

        return FutureBuilder<List<UserAccount>>(
          key: ValueKey('users_$_reloadTick'),
          future: _futureUsuarios,
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? const <UserAccount>[];
            final activeUsers = users.where((item) => item.activo).length;
            final inactiveUsers = users.length - activeUsers;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // El titulo de la pestana ya lo muestra la AppBar.
                          Text(
                            'Gestion centralizada de acceso, roles y estado de las cuentas del sistema.',
                            style: TextStyle(color: context.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          usersSnapshot.hasData && estadoRoles.puedeEditar
                          ? () => _openUserDialog(roles: roles)
                          : null,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Registrar'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (usersSnapshot.hasData)
                  Row(
                    children: [
                      Expanded(
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: context.textoSecundario,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${users.length}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activos',
                                style: TextStyle(
                                  color: context.textoSecundario,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$activeUsers',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inactivos',
                                style: TextStyle(
                                  color: context.textoSecundario,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$inactiveUsers',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (estadoRoles.mensaje != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 18,
                            color: context.paleta.stockBajo,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              estadoRoles.mensaje!,
                              style: TextStyle(
                                color: context.paleta.stockBajo,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (usersSnapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (usersSnapshot.hasError)
                  SectionCard(
                    child: Text(
                      'No se pudo cargar el panel de usuarios: ${usersSnapshot.error}',
                    ),
                  )
                else if (!usersSnapshot.hasData || users.isEmpty)
                  const SectionCard(child: Text('No hay usuarios registrados.'))
                else
                  ...users.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UserCard(
                        user: user,
                        isCurrentUser: user.id == session.user?.id,
                        onEdit: () => _openUserDialog(user: user, roles: roles),
                        onToggleStatus: user.activo
                            ? () => _deactivateUser(user)
                            : () => _activateUser(user),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserAccount user;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      // Antes la tarjeta ocupaba cuatro bloques: identificacion, rol, dos
      // botones y un aviso. Ahora es una fila y las acciones van en un menu.
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor:
                (user.activo
                        ? context.paleta.info
                        : context.paleta.textoTerciario)
                    .withValues(alpha: 0.22),
            child: Text(
              _iniciales(user.nombreCompleto),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: user.activo
                    ? context.paleta.info
                    : context.textoTerciario,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 6),
                      Text(
                        '(tu sesion)',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textoTerciario,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.rolNombre} · ${user.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: user.activo
                        ? context.textoSecundario
                        : context.paleta.textoTerciario,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  (user.activo
                          ? context.paleta.info
                          : context.paleta.textoTerciario)
                      .withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.activo ? 'Activo' : 'Inactivo',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          if (!isCurrentUser)
            PopupMenuButton<String>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (o) {
                if (o == 'editar') {
                  onEdit();
                } else {
                  onToggleStatus();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'editar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'estado',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      user.activo
                          ? Icons.person_off_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(user.activo ? 'Desactivar' : 'Activar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Iniciales para el avatar: "Gabriel Zeballos" -> "GZ".
  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }
}

class _UserFormDialog extends StatefulWidget {
  final UserAccount? user;
  final List<RoleOption> roles;
  final UserService service;

  const _UserFormDialog({
    this.user,
    required this.roles,
    required this.service,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _nombreController;
  late final TextEditingController _passwordController;

  int? _selectedRoleId;
  bool _active = true;
  bool _saving = false;
  bool _showPassword = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _emailController = TextEditingController(text: user?.email ?? '');
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _passwordController = TextEditingController();
    _selectedRoleId =
        user?.rolId ?? (widget.roles.isNotEmpty ? widget.roles.first.id : null);
    _active = user?.activo ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nombreController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'email': _emailController.text.trim(),
      'nombre': _nombreController.text.trim(),
      'rol_id': _selectedRoleId,
      'activo': _active,
    };

    try {
      if (_isEditing) {
        if (_passwordController.text.isNotEmpty) {
          payload['password'] = _passwordController.text;
        }
        await widget.service.updateUser(widget.user!.id, payload);
      } else {
        payload['password'] = _passwordController.text;
        await widget.service.createUser(payload);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el usuario: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar usuario' : 'Registrar usuario'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? 'Actualiza los datos del usuario y, si hace falta, renueva su contrasena.'
                      : 'Crea una nueva cuenta y asignale su rol.',
                  style: TextStyle(color: context.textoSecundario),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    errorMaxLines: 2,
                  ),
                  validator: Validaciones.nombreSinNumeros,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    errorMaxLines: 2,
                  ),
                  validator: Validaciones.correo,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _isEditing
                        ? 'Nueva contrasena (opcional)'
                        : 'Contrasena',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (!_isEditing && (value == null || value.length < 6)) {
                      return 'La contrasena debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedRoleId,
                  items: widget.roles
                      .map(
                        (role) => DropdownMenuItem<int>(
                          value: role.id,
                          child: Text(role.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRoleId = value),
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  subtitle: Text(
                    'Puedes dejar la cuenta creada y activa desde el inicio.',
                  ),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: context.paleta.negativo),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        BotonSeguro(
          onPressed: _saving ? null : _save,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined),
          child: Text(
            _saving
                ? 'Guardando...'
                : (_isEditing ? 'Actualizar' : 'Registrar'),
          ),
        ),
      ],
    );
  }
}
