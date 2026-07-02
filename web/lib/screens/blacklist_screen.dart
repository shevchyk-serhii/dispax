import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/error_messages.dart';
import '../modules/core/json_parse.dart';
import '../modules/core/services/api_client.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  Object? _error;

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
          _error = ApiException(
            'Failed to load blacklist',
            statusCode: resp.statusCode,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final clientIdCtrl = TextEditingController();
    final driverIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addBlacklistEntryDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clientIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.clientIdLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.driverIdLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.reasonOptionalLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (clientIdCtrl.text.isEmpty || driverIdCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.clientDriverIdRequired)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        friendlyError(e, AppLocalizations.of(context)!),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.addButton),
          ),
        ],
      ),
    );

    if (result == true) _loadEntries();
  }

  Future<void> _removeEntry(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeBlacklistEntryDialogTitle),
        content: Text(l10n.removeBlacklistEntryContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.removeBlacklistEntryButton),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, AppLocalizations.of(context)!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildHeader(l10n),
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
                      ElevatedButton(
                        onPressed: _loadEntries,
                        child: Text(l10n.retry),
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
                        l10n.noBlacklistEntries,
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

  Widget _buildHeader(AppLocalizations l10n) {
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
              Expanded(
                child: Text(
                  l10n.blacklistTitle,
                  style: const TextStyle(
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
    final clientId = JsonParse.optionalId(entry, 'clientId') ?? '';
    final driverId = JsonParse.optionalId(entry, 'driverId') ?? '';
    final clientLabel =
        entry['clientName'] as String? ?? _shortId(clientId.toString());
    final driverLabel =
        entry['driverName'] as String? ?? _shortId(driverId.toString());
    final reason = entry['reason'] as String?;
    final createdAt = entry['createdAt'] as String? ?? '';
    final id = JsonParse.optionalId(entry, 'id') ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withAlpha(20),
          child: const Icon(Icons.block, color: AppColors.error),
        ),
        title: Text(
          'Client: $clientLabel',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver: $driverLabel', style: const TextStyle(fontSize: 12)),
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
