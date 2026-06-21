import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/blacklist');
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        setState(() {
          _entries = (decoded is List)
              ? decoded.cast<Map<String, dynamic>>()
              : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load blacklist (${resp.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showAddDialog() async {
    final clientIdCtrl = TextEditingController();
    final driverIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Blacklist Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driver ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (clientIdCtrl.text.isEmpty || driverIdCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Client ID and Driver ID are required'),
                  ),
                );
                return;
              }
              try {
                final apiClient = this.context.read<AuthBloc>().apiClient;
                await apiClient.post('/blacklist', {
                  'clientId': clientIdCtrl.text,
                  'driverId': driverIdCtrl.text,
                  if (reasonCtrl.text.isNotEmpty) 'reason': reasonCtrl.text,
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) _loadEntries();
  }

  Future<void> _removeEntry(String id) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Blacklist Entry'),
        content: const Text(
          'Are you sure you want to remove this blacklist entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/blacklist/$id');
      _loadEntries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
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
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _loadEntries,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No blacklist entries',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) =>
                        _buildEntryCard(_entries[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.dispatcherGradient),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.block, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Blacklist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _showAddDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadEntries,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final clientId = entry['clientId']?['value'] ?? entry['clientId'] ?? '';
    final driverId = entry['driverId']?['value'] ?? entry['driverId'] ?? '';
    final reason = entry['reason'] as String?;
    final createdAt = entry['createdAt'] as String? ?? '';
    final id = entry['id']?['value'] ?? entry['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withAlpha(20),
          child: const Icon(Icons.block, color: AppColors.error),
        ),
        title: Text(
          'Client: ${_shortId(clientId.toString())}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver: ${_shortId(driverId.toString())}',
              style: const TextStyle(fontSize: 12),
            ),
            if (reason != null && reason.isNotEmpty)
              Text(
                reason,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
          onPressed: () => _removeEntry(id.toString()),
        ),
      ),
    );
  }

  String _shortId(String id) {
    if (id.length > 8) return '${id.substring(0, 8)}...';
    return id;
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
