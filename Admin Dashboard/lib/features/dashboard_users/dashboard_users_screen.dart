import 'package:flutter/material.dart';
import '../../core/available_permissions.dart';
import '../../core/session_store.dart';
import 'dashboard_users_api.dart';

class DashboardUsersScreen extends StatefulWidget {
  const DashboardUsersScreen({super.key});

  @override
  State<DashboardUsersScreen> createState() => _DashboardUsersScreenState();
}

class _DashboardUsersScreenState extends State<DashboardUsersScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];

  bool get _allowed {
    final session = SessionStore.current;
    final role = (session?.role ?? '').trim().toUpperCase();
    return role == 'SUPER_ADMIN';
  }

  @override
  void initState() {
    super.initState();

    // ✅ role-based access (same logic as sidebar)
    if (!_allowed) {
      _loading = false;
      _error = 'Access denied';
      return;
    }

    _load();
  }

  Future<void> _load() async {
    if (!_allowed) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await DashboardUsersApi.list();

      // helpful debug for API shape
      debugPrint('DashboardUsersApi.list() => ${list.runtimeType} $list');

      setState(() => _users = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    if (!_allowed) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateUserDialog(),
    );

    if (created == true) await _load();
  }

  Future<void> _openEditDialog(Map<String, dynamic> user) async {
    if (!_allowed) return;

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(user: user),
    );

    if (updated == true) await _load();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (!_allowed) return;

    final id = (user['id'] as num).toInt();
    final email = user['email']?.toString() ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('This will disable Firebase account and remove DB user:\n$email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DashboardUsersApi.delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Deleted')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ If not allowed, show clear message (no pop / no blank)
    if (!_allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard Users')),
        body: const Center(child: Text('Access denied')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Users'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _openCreateDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _users.isEmpty
          ? const Center(child: Text('No users'))
          : ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final u = Map<String, dynamic>.from(_users[i]);

          final isActive = (u['isActive'] as bool?) ?? true;
          final role = u['role']?.toString() ?? '';
          final email = u['email']?.toString() ?? '';
          final name = u['name']?.toString();

          final perms = (u['permissions'] as List? ?? [])
              .map((e) => e.toString())
              .toList();

          return ListTile(
            title: Text(
              name?.isNotEmpty == true ? '$name ($email)' : email,
            ),
            subtitle: Text(
              'Role: $role • Active: $isActive • Perms: ${perms.length}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _openEditDialog(u),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () => _deleteUser(u),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  String _role = 'DASHBOARD_USER';
  bool _saving = false;
  final Set<String> _selectedPerms = {'ADMIN_USERS_MANAGE'};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await DashboardUsersApi.create(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        role: _role,
        permissions: _selectedPerms.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create dashboard user'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter valid email' : null,
                ),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 chars' : null,
                ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(
                        value: 'DASHBOARD_USER', child: Text('Dashboard User')),
                    DropdownMenuItem(
                        value: 'SUPER_ADMIN', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'DASHBOARD_USER'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Permissions',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                ...availablePermissions.entries.map((e) {
                  final key = e.key;
                  final label = e.value;
                  final checked = _selectedPerms.contains(key);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    title: Text(label),
                    subtitle: Text(key),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedPerms.add(key);
                        } else {
                          _selectedPerms.remove(key);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Create'),
        ),
      ],
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;

  late String _role;
  late bool _isActive;
  late final Set<String> _selectedPerms;

  bool _saving = false;

  int get _id => (widget.user['id'] as num).toInt();

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.user['name']?.toString() ?? '');
    _role = widget.user['role']?.toString() ?? 'DASHBOARD_USER';
    _isActive = (widget.user['isActive'] as bool?) ?? true;

    final perms =
    (widget.user['permissions'] as List? ?? []).map((e) => e.toString()).toSet();
    _selectedPerms = perms;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await DashboardUsersApi.update(
        id: _id,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        role: _role,
        isActive: _isActive,
        permissions: _selectedPerms.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user['email']?.toString() ?? '';

    return AlertDialog(
      title: Text('Edit user ($email)'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(
                        value: 'DASHBOARD_USER', child: Text('Dashboard User')),
                    DropdownMenuItem(
                        value: 'SUPER_ADMIN', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'DASHBOARD_USER'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Permissions',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                ...availablePermissions.entries.map((e) {
                  final key = e.key;
                  final label = e.value;
                  final checked = _selectedPerms.contains(key);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    title: Text(label),
                    subtitle: Text(key),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedPerms.add(key);
                        } else {
                          _selectedPerms.remove(key);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}