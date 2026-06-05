import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  String _roleFilter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/users');

      if (response.statusCode == 200) {
        _users = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users.toList();
    if (_roleFilter != 'All') {
      filtered = filtered.where((u) =>
        (u['role'] as String? ?? '').toLowerCase() == _roleFilter.toLowerCase()
      ).toList();
    }
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((u) =>
        (u['name'] as String? ?? '').toLowerCase().contains(search) ||
        (u['email'] as String? ?? '').toLowerCase().contains(search)
      ).toList();
    }
    return filtered;
  }

  Map<String, int> get _roleCounts {
    final counts = <String, int>{'driver': 0, 'client': 0, 'secretary': 0, 'dispatcher': 0};
    for (final u in _users) {
      final role = (u['role'] as String? ?? '').toLowerCase();
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'driver': return AppColors.driverColor;
      case 'client': return AppColors.clientColor;
      case 'secretary': return AppColors.secretaryColor;
      case 'dispatcher': return AppColors.dispatcherColor;
      default: return AppColors.textSecondary;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active': return AppColors.success;
      case 'suspended': return AppColors.warning;
      case 'inactive': return AppColors.textSecondary;
      default: return AppColors.success;
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/users/${user['id']}', {'role': newRole});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to $newRole'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> user, String newStatus) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.patch('/users/${user['id']}/status', {'status': newStatus});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCreateUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'client';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: ['driver', 'client', 'secretary', 'dispatcher']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'client'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final apiClient = context.read<AuthBloc>().apiClient;
                  await apiClient.post('/users', {
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passwordCtrl.text,
                    'role': selectedRole,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadUsers();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (!_isLoading && _error == null) _buildStatsBar(),
        _buildSearchAndFilter(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: _buildContent(),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'User Management',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white, size: 22),
              onPressed: _showCreateUserDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadUsers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final counts = _roleCounts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Total', _users.length.toString(), AppColors.primary),
          _buildStatChip('Drivers', (counts['driver'] ?? 0).toString(), AppColors.driverColor),
          _buildStatChip('Clients', (counts['client'] ?? 0).toString(), AppColors.clientColor),
          _buildStatChip('Staff', ((counts['secretary'] ?? 0) + (counts['dispatcher'] ?? 0)).toString(), AppColors.secretaryColor),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _roleFilter,
            underline: const SizedBox(),
            items: ['All', 'Driver', 'Client', 'Secretary', 'Dispatcher']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _roleFilter = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No users found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final role = (user['role'] as String? ?? 'client');
        final status = user['status'] as String? ?? 'Active';
        final name = user['name'] as String? ?? 'Unknown';
        final email = user['email'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _roleColor(role).withAlpha(30),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(email, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _roleColor(role))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value.startsWith('role:')) {
                    _changeRole(user, value.substring(5));
                  } else if (value.startsWith('status:')) {
                    _changeStatus(user, value.substring(7));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(enabled: false, child: Text('Change Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...['driver', 'client', 'secretary', 'dispatcher']
                      .where((r) => r != role.toLowerCase())
                      .map((r) => PopupMenuItem(value: 'role:$r', child: Text(r))),
                  const PopupMenuDivider(),
                  const PopupMenuItem(enabled: false, child: Text('Change Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (status.toLowerCase() != 'active')
                    const PopupMenuItem(value: 'status:Active', child: Text('Activate')),
                  if (status.toLowerCase() != 'suspended')
                    const PopupMenuItem(value: 'status:Suspended', child: Text('Suspend')),
                  if (status.toLowerCase() != 'inactive')
                    const PopupMenuItem(value: 'status:Inactive', child: Text('Deactivate')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
