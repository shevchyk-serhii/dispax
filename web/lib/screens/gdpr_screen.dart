import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';

class GdprScreen extends StatefulWidget {
  const GdprScreen({super.key});

  @override
  State<GdprScreen> createState() => _GdprScreenState();
}

class _GdprScreenState extends State<GdprScreen> {
  List<Map<String, dynamic>> _consents = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authBloc = context.read<AuthBloc>();
      final apiClient = authBloc.apiClient;
      final user = authBloc.state.user;
      // The deletion-requests list is an admin/dispatcher-only view (the backend
      // returns 403 otherwise). Regular users only manage their own consents, so
      // we skip that call for them instead of treating its 403 as an error.
      final canViewRequests =
          user?.isAdmin == true || user?.isDispatcher == true;

      final consentsResp = await apiClient.get('/gdpr/consents');
      final requestsResp = canViewRequests
          ? await apiClient.get('/gdpr/requests')
          : null;
      if (!mounted) return;

      final requestsOk = requestsResp == null || requestsResp.statusCode == 200;
      if (consentsResp.statusCode == 200 && requestsOk) {
        setState(() {
          _consents = (jsonDecode(consentsResp.body) as List)
              .cast<Map<String, dynamic>>();
          _requests = requestsResp == null
              ? []
              : (jsonDecode(requestsResp.body) as List)
                    .cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        final requestsStatus = requestsResp?.statusCode ?? '-';
        setState(() {
          _isLoading = false;
          _error =
              'Failed to load GDPR data (${consentsResp.statusCode}/$requestsStatus)';
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

  bool _isConsentGranted(String consentType) {
    return _consents.any(
      (c) => c['consentType'] == consentType && c['revokedAt'] == null,
    );
  }

  Future<void> _toggleConsent(String consentType, bool granted) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.put('/gdpr/consents', {
        'consentType': consentType,
        'granted': granted,
      });
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _exportData() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/gdpr/export');

      if (resp.statusCode == 200) {
        await Clipboard.setData(ClipboardData(text: resp.body));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data export copied to clipboard')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Data Deletion'),
        content: const Text(
          'This will submit a request to delete all your personal data. '
          'This action cannot be undone. Your account will be deactivated '
          'once the request is processed.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.post('/gdpr/deletion-request', {});
      if (!mounted) return;

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deletion request submitted')),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data (GDPR)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(_error!),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                _buildConsentSection(),
                _buildDataExportSection(),
                _buildDeletionSection(),
                if (_requests.isNotEmpty) _buildRequestsSection(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildConsentSection() {
    final consentTypes = [
      (
        'DataProcessing',
        'Data Processing',
        'Allow processing of ride and account data',
        Icons.storage,
      ),
      (
        'Marketing',
        'Marketing',
        'Receive promotional emails and offers',
        Icons.mail_outline,
      ),
      (
        'Analytics',
        'Analytics',
        'Help improve the app with usage analytics',
        Icons.analytics,
      ),
      (
        'ThirdPartySharing',
        'Third-Party Sharing',
        'Share data with partner services',
        Icons.share,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Consent Management'),
        ...consentTypes.map((ct) {
          final granted = _isConsentGranted(ct.$1);
          return SwitchListTile(
            secondary: Icon(
              ct.$4,
              color: granted
                  ? AppColors.success
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(ct.$2),
            subtitle: Text(ct.$3, style: const TextStyle(fontSize: 12)),
            value: granted,
            onChanged: (v) => _toggleConsent(ct.$1, v),
          );
        }),
      ],
    );
  }

  Widget _buildDataExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Your Data'),
        ListTile(
          leading: const Icon(Icons.download, color: AppColors.info),
          title: const Text('Export My Data'),
          subtitle: const Text(
            'Download all personal data we have stored about you',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportData,
        ),
      ],
    );
  }

  Widget _buildDeletionSection() {
    final hasPendingDeletion = _requests.any(
      (r) => r['requestType'] == 'DELETION' && r['status'] == 'PENDING',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Data Deletion'),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: hasPendingDeletion
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : AppColors.error,
          ),
          title: const Text('Request Data Deletion'),
          subtitle: Text(
            hasPendingDeletion
                ? 'A deletion request is already pending'
                : 'Permanently delete all your data and account',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: hasPendingDeletion
              ? Chip(
                  label: const Text('Pending', style: TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.warning.withAlpha(30),
                )
              : const Icon(Icons.chevron_right),
          onTap: hasPendingDeletion ? null : _requestDeletion,
        ),
      ],
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Request History'),
        ..._requests.map((r) {
          final type = r['requestType'] as String;
          final status = r['status'] as String;
          final date = r['requestedAt'] as String;

          return ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: _statusColor(status).withAlpha(30),
              child: Icon(
                type == 'DELETION' ? Icons.delete : Icons.download,
                size: 18,
                color: _statusColor(status),
              ),
            ),
            title: Text(type == 'DELETION' ? 'Data Deletion' : 'Data Export'),
            subtitle: Text(
              '${_formatDate(date)} \u2022 $status',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(status),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'PROCESSING':
        return AppColors.info;
      case 'COMPLETED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
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
