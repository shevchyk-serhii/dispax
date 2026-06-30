import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/error_messages.dart';

class GdprScreen extends StatefulWidget {
  const GdprScreen({super.key});

  @override
  State<GdprScreen> createState() => _GdprScreenState();
}

class _GdprScreenState extends State<GdprScreen> {
  List<Map<String, dynamic>> _consents = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Don't read AppLocalizations.of(context) here: this runs synchronously from
    // initState (before the first frame), where inherited widgets aren't bound
    // yet. Read it lazily in the branch that needs it, after the await.
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
          _error = AppLocalizations.of(context)!.failedToLoadGdprData(
            consentsResp.statusCode.toString(),
            requestsStatus.toString(),
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

  bool _isConsentGranted(String consentType) {
    return _consents.any(
      (c) => c['consentType'] == consentType && c['revokedAt'] == null,
    );
  }

  Future<void> _toggleConsent(String consentType, bool granted) async {
    final l10n = AppLocalizations.of(context)!;
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
      ).showSnackBar(SnackBar(content: Text(friendlyError(e, l10n))));
    }
  }

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/gdpr/export');

      if (resp.statusCode == 200) {
        await Clipboard.setData(ClipboardData(text: resp.body));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dataExportCopied)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed(friendlyError(e, l10n)))),
      );
    }
  }

  Future<void> _requestDeletion() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.requestDeletionDialogTitle),
        content: Text(l10n.requestDeletionDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.requestDeletionButton),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.deletionRequestSubmitted)));
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gdprScreenTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator.adaptive())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(friendlyError(_error, l10n)),
                  ElevatedButton(onPressed: _loadData, child: Text(l10n.retry)),
                ],
              ),
            )
          : ListView(
              children: [
                _buildConsentSection(l10n),
                _buildDataExportSection(l10n),
                _buildDeletionSection(l10n),
                if (_requests.isNotEmpty) _buildRequestsSection(l10n),
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

  Widget _buildConsentSection(AppLocalizations l10n) {
    final consentTypes = [
      (
        'DataProcessing',
        l10n.consentDataProcessingLabel,
        l10n.consentDataProcessingSubtitle,
        Icons.storage,
      ),
      (
        'Marketing',
        l10n.consentMarketingLabel,
        l10n.consentMarketingSubtitle,
        Icons.mail_outline,
      ),
      (
        'Analytics',
        l10n.consentAnalyticsLabel,
        l10n.consentAnalyticsSubtitle,
        Icons.analytics,
      ),
      (
        'ThirdPartySharing',
        l10n.consentThirdPartySharingLabel,
        l10n.consentThirdPartySharingSubtitle,
        Icons.share,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.consentManagementSectionTitle),
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

  Widget _buildDataExportSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.yourDataSectionTitle),
        ListTile(
          leading: const Icon(Icons.download, color: AppColors.info),
          title: Text(l10n.exportMyDataLabel),
          subtitle: Text(
            l10n.exportMyDataSubtitle,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _exportData,
        ),
      ],
    );
  }

  Widget _buildDeletionSection(AppLocalizations l10n) {
    final hasPendingDeletion = _requests.any(
      (r) => r['requestType'] == 'DELETION' && r['status'] == 'PENDING',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.dataDeletionSectionTitle),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: hasPendingDeletion
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : AppColors.error,
          ),
          title: Text(l10n.requestDeletionDialogTitle),
          subtitle: Text(
            hasPendingDeletion
                ? l10n.pendingDeletionSubtitle
                : l10n.requestDataDeletionSubtitle,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: hasPendingDeletion
              ? Chip(
                  label: Text(
                    l10n.pendingChipLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.warning.withAlpha(30),
                )
              : const Icon(Icons.chevron_right),
          onTap: hasPendingDeletion ? null : _requestDeletion,
        ),
      ],
    );
  }

  Widget _buildRequestsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.requestHistoryTitle),
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
            title: Text(
              type == 'DELETION'
                  ? l10n.dataDeletionRequestType
                  : l10n.dataExportRequestType,
            ),
            subtitle: Text(
              '${_formatDate(date)} • $status',
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
        return Theme.of(context).colorScheme.onSurfaceVariant;
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
