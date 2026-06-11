import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/models/audit_entry.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditEntry> _entries = [];
  List<AuditEntry> _filteredEntries = [];
  bool _isLoading = true;
  String? _error;
  String _entityTypeFilter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAuditLog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditLog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/audit/recent?limit=50');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        _entries = jsonList.map((j) => AuditEntry.fromJson(j)).toList();
        _applyFilters();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _applyFilters() {
    var filtered = _entries.toList();

    if (_entityTypeFilter != 'All') {
      filtered = filtered.where((e) =>
        e.entityType.toLowerCase() == _entityTypeFilter.toLowerCase()
      ).toList();
    }

    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.entityId.toLowerCase().contains(search) ||
        e.action.toLowerCase().contains(search) ||
        e.actorId.toLowerCase().contains(search)
      ).toList();
    }

    _filteredEntries = filtered;
  }

  IconData _getActionIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create')) return Icons.add_circle;
    if (lower.contains('update') || lower.contains('edit')) return Icons.edit;
    if (lower.contains('delete') || lower.contains('remove')) return Icons.delete;
    if (lower.contains('assign')) return Icons.assignment;
    if (lower.contains('cancel')) return Icons.cancel;
    if (lower.contains('complete')) return Icons.check_circle;
    if (lower.contains('login') || lower.contains('auth')) return Icons.login;
    return Icons.info;
  }

  Color _getActionColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create')) return AppColors.success;
    if (lower.contains('delete') || lower.contains('cancel')) return AppColors.error;
    if (lower.contains('update') || lower.contains('edit')) return AppColors.info;
    if (lower.contains('assign')) return Theme.of(context).colorScheme.primary;
    if (lower.contains('complete')) return AppColors.success;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
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
                          ElevatedButton(onPressed: _loadAuditLog, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAuditLog,
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
            const Icon(Icons.history, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Audit Log',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadAuditLog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surfaceVariant,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by entity ID...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (_) {
                    setState(() => _applyFilters());
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _entityTypeFilter,
                underline: const SizedBox(),
                items: ['All', 'Ride', 'User', 'Driver']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _entityTypeFilter = v;
                      _applyFilters();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No audit entries found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        final color = _getActionColor(entry.action);

        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getActionIcon(entry.action), color: color, size: 18),
                  ),
                  if (index < _filteredEntries.length - 1)
                    Container(width: 2, height: 40, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.action,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.entityType} #${entry.entityId}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        'By: ${entry.actorId}',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      Text(
                        _formatTimestamp(entry.createdAt),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
