import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/branch_option.dart';
import '../../../core/models/role_option.dart';
import '../../../core/models/user_account.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/user_service.dart';
import '../../../core/session/session_controller.dart';
import '../../../shared/widgets/section_card.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _service = UserService(ApiClient());
  int _reloadTick = 0;

  Future<_UsersData> _loadData() async {
    final users = await _service.fetchUsers();
    final roles = await _service.fetchRoles();
    final branches = await _service.fetchBranches();
    return _UsersData(users: users, roles: roles, branches: branches);
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() => _reloadTick++);
  }

  Future<void> _openUserDialog({
    UserAccount? user,
    required List<RoleOption> roles,
    required List<BranchOption> branches,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _UserFormDialog(
        user: user,
        roles: roles,
        branches: branches,
        service: _service,
      ),
    );

    if (saved == true) {
      _refresh();
    }
  }

  Future<void> _deactivateUser(UserAccount user) async {
    final sessionUserId = SessionController.instance.user?.id;
    if (sessionUserId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No es posible desactivar tu propia cuenta desde esta sesion.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('Se desactivara la cuenta de ${user.nombreCompleto}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
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
        SnackBar(content: Text('Usuario ${user.username} desactivado.')),
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
        SnackBar(content: Text('Usuario ${user.username} reactivado.')),
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
          Text('Usuarios', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          SectionCard(
            child: Text('Solo un administrador puede ver y gestionar el panel de usuarios.'),
          ),
        ],
      );
    }

    return FutureBuilder<_UsersData>(
      key: ValueKey(_reloadTick),
      future: _loadData(),
      builder: (context, snapshot) {
        final users = snapshot.data?.users ?? const <UserAccount>[];
        final activeUsers = users.where((item) => item.activo).length;
        final inactiveUsers = users.length - activeUsers;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usuarios', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        'Gestion centralizada de acceso, roles y estado de las cuentas del sistema.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: snapshot.hasData
                      ? () => _openUserDialog(
                            roles: snapshot.data!.roles,
                            branches: snapshot.data!.branches,
                          )
                      : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Registrar'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (snapshot.hasData)
              Row(
                children: [
                  Expanded(
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('${users.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Activos', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('$activeUsers', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inactivos', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('$inactiveUsers', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              SectionCard(child: Text('No se pudo cargar el panel de usuarios: ${snapshot.error}'))
            else if (!snapshot.hasData || users.isEmpty)
              const SectionCard(child: Text('No hay usuarios registrados.'))
            else
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UserCard(
                    user: user,
                    isCurrentUser: user.id == session.user?.id,
                    onEdit: () => _openUserDialog(
                      user: user,
                      roles: snapshot.data!.roles,
                      branches: snapshot.data!.branches,
                    ),
                    onToggleStatus: user.activo ? () => _deactivateUser(user) : () => _activateUser(user),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UsersData {
  final List<UserAccount> users;
  final List<RoleOption> roles;
  final List<BranchOption> branches;

  const _UsersData({
    required this.users,
    required this.roles,
    required this.branches,
  });
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nombreCompleto,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('@${user.username}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              if (isCurrentUser)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Tu sesion', style: TextStyle(fontSize: 12)),
                ),
              Chip(
                label: Text(user.activo ? 'Activo' : 'Inactivo'),
                backgroundColor: user.activo ? Colors.teal.withOpacity(0.20) : Colors.red.withOpacity(0.20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Rol: ${user.rolNombre}'),
          Text('Sucursal: ${user.sucursalNombre ?? 'Sin asignar'}'),
          Text('Email: ${user.email}'),
          if (user.telefono != null && user.telefono!.isNotEmpty) Text('Telefono: ${user.telefono}'),
          if (user.ultimoAcceso != null)
            Text(
              'Ultimo acceso: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(user.ultimoAcceso!).toLocal())}',
              style: const TextStyle(color: Colors.white70),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              if (user.activo)
                OutlinedButton.icon(
                  onPressed: onToggleStatus,
                  icon: const Icon(Icons.person_off_outlined),
                  label: Text(isCurrentUser ? 'No disponible' : 'Desactivar'),
                )
              else
                ElevatedButton.icon(
                  onPressed: onToggleStatus,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Activar'),
                ),
            ],
          ),
          if (isCurrentUser) ...[
            const SizedBox(height: 10),
            const Text(
              'Por seguridad, no puedes desactivar tu propia cuenta desde esta sesion.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final UserAccount? user;
  final List<RoleOption> roles;
  final List<BranchOption> branches;
  final UserService service;

  const _UserFormDialog({
    this.user,
    required this.roles,
    required this.branches,
    required this.service,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _passwordController;

  int? _selectedRoleId;
  int? _selectedBranchId;
  bool _active = true;
  bool _saving = false;
  bool _showPassword = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _apellidoController = TextEditingController(text: user?.apellido ?? '');
    _telefonoController = TextEditingController(text: user?.telefono ?? '');
    _passwordController = TextEditingController();
    _selectedRoleId = user?.rolId ?? (widget.roles.isNotEmpty ? widget.roles.first.id : null);
    _selectedBranchId = user?.sucursalId ?? (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    _active = user?.activo ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
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
      'apellido': _apellidoController.text.trim().isEmpty ? null : _apellidoController.text.trim(),
      'telefono': _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
      'sucursal_id': _selectedBranchId,
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
        payload['username'] = _usernameController.text.trim();
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
                      : 'Crea una nueva cuenta y asignale su rol y sucursal de trabajo.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isEditing,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (!_isEditing && (value == null || value.trim().length < 3)) {
                      return 'Minimo 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty || !value.contains('@')) {
                      return 'Ingresa un email valido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apellidoController,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: _isEditing ? 'Nueva contrasena (opcional)' : 'Contrasena',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (value) {
                    if (!_isEditing && (value == null || value.length < 6)) {
                      return 'Minimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedRoleId,
                  items: widget.roles
                      .map((role) => DropdownMenuItem<int>(value: role.id, child: Text(role.nombre)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRoleId = value),
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedBranchId,
                  items: widget.branches
                      .map((branch) => DropdownMenuItem<int>(value: branch.id, child: Text(branch.nombre)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedBranchId = value),
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  subtitle: const Text('Puedes dejar la cuenta creada y activa desde el inicio.'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
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
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : (_isEditing ? 'Actualizar' : 'Registrar')),
        ),
      ],
    );
  }
}
