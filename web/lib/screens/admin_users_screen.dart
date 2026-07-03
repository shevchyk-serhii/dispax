import 'dart:convert';
import '../modules/core/services/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../utils/password_policy.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  Object? _error;
  // Internal filter key — compared with API role strings (lowercase)
  String _roleFilterKey = 'all';
  final _searchController = TextEditingController();

  // Map of internal filter key → display label (built with l10n)
  Map<String, String> _filterEntries(AppLocalizations l10n) => {
    'all': l10n.allLabel,
    'driver': l10n.roleDriver,
    'client': l10n.roleClient,
    'secretary': l10n.roleSecretary,
    'dispatcher': l10n.roleDispatcher,
  };

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
        _error = e;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users.toList();
    if (_roleFilterKey != 'all') {
      filtered = filtered
          .where(
            (u) => (u['role'] as String? ?? '').toLowerCase() == _roleFilterKey,
          )
          .toList();
    }
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered
          .where(
            (u) =>
                (u['name'] as String? ?? '').toLowerCase().contains(search) ||
                (u['email'] as String? ?? '').toLowerCase().contains(search),
          )
          .toList();
    }
    return filtered;
  }

  Map<String, int> get _roleCounts {
    final counts = <String, int>{
      'driver': 0,
      'client': 0,
      'secretary': 0,
      'dispatcher': 0,
    };
    for (final u in _users) {
      final role = (u['role'] as String? ?? '').toLowerCase();
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return AppColors.driverColor;
      case 'client':
        return AppColors.clientColor;
      case 'secretary':
        return AppColors.secretaryColor;
      case 'dispatcher':
        return AppColors.dispatcherColor;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'suspended':
        return AppColors.warning;
      case 'inactive':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return AppColors.success;
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/users/${user['id']}', {'role': newRole});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.roleChangedSuccess(newRole),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToChangeRole(
                friendlyError(e, AppLocalizations.of(context)!),
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> user,
    String newStatus,
  ) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.patch('/users/${user['id']}/status', {
        'status': newStatus,
      });
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.statusChangedSuccess(newStatus),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToChangeStatus(
                friendlyError(e, AppLocalizations.of(context)!),
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateUserDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'client';
    String? passwordError;

    showAdaptiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.createUserDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.temporaryPassword,
                    helperText: l10n.temporaryPasswordHint,
                    helperMaxLines: 2,
                    errorText: passwordError,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: l10n.roleLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: ['driver', 'client', 'secretary', 'dispatcher']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedRole = v ?? 'client'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                // Mirror the backend password policy so the admin gets a
                // field-level hint instead of a raw 400 from the server.
                if (!isPolicyCompliantPassword(passwordCtrl.text)) {
                  setDialogState(
                    () => passwordError = l10n.passwordPolicyRules,
                  );
                  return;
                }
                setDialogState(() => passwordError = null);
                try {
                  final apiClient = context.read<AuthBloc>().apiClient;
                  await apiClient.post('/users', {
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passwordCtrl.text,
                    'role': selectedRole,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.userCreatedSharePassword)),
                    );
                  }
                  _loadUsers();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.failedToCreateUser(
                            friendlyError(e, AppLocalizations.of(context)!),
                          ),
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.createButton),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildHeader(),
        if (!_isLoading && _error == null) _buildStatsBar(),
        _buildSearchAndFilter(),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(friendlyError(_error, l10n)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _loadUsers, child: _buildContent()),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.dispatcherGradient),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.userManagementTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _showCreateUserDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadUsers,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final l10n = AppLocalizations.of(context)!;
    final counts = _roleCounts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip(
            l10n.totalUsersLabel,
            _users.length.toString(),
            Theme.of(context).colorScheme.primary,
          ),
          _buildStatChip(
            l10n.driversStatLabel,
            (counts['driver'] ?? 0).toString(),
            AppColors.driverColor,
          ),
          _buildStatChip(
            l10n.clientsStatLabel,
            (counts['client'] ?? 0).toString(),
            AppColors.clientColor,
          ),
          _buildStatChip(
            l10n.staffStatLabel,
            ((counts['secretary'] ?? 0) + (counts['dispatcher'] ?? 0))
                .toString(),
            AppColors.secretaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    final l10n = AppLocalizations.of(context)!;
    final filterMap = _filterEntries(l10n);
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchUsersHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _roleFilterKey,
            underline: const SizedBox(),
            items: filterMap.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _roleFilterKey = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noUsersFound,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _roleColor(role).withAlpha(30),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _roleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _roleColor(role).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _roleColor(role),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(status),
                            ),
                          ),
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
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      l10n.changeRoleMenuHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...['driver', 'client', 'secretary', 'dispatcher']
                      .where((r) => r != role.toLowerCase())
                      .map(
                        (r) => PopupMenuItem(value: 'role:$r', child: Text(r)),
                      ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      l10n.changeStatusMenuHeader,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (status.toLowerCase() != 'active')
                    PopupMenuItem(
                      value: 'status:Active',
                      child: Text(l10n.activateUserAction),
                    ),
                  if (status.toLowerCase() != 'suspended')
                    PopupMenuItem(
                      value: 'status:Suspended',
                      child: Text(l10n.suspendUserAction),
                    ),
                  if (status.toLowerCase() != 'inactive')
                    PopupMenuItem(
                      value: 'status:Inactive',
                      child: Text(l10n.deactivateUserAction),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
