import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/error_messages.dart';
import '../modules/core/services/api_client.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/sessions');
      if (!mounted) return;

      if (resp.statusCode == 200) {
        setState(() {
          _sessions = (jsonDecode(resp.body) as List)
              .cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = ApiException(
            'Failed to load sessions',
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

  Future<void> _revokeSession(String sessionId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.revokeSessionDialogTitle),
        content: Text(l10n.revokeSessionDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.revokeSessionButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/sessions/$sessionId');
      _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.sessionRevoked)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, AppLocalizations.of(context)!)),
        ),
      );
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.revokeAllOtherSessionsDialogTitle),
        content: Text(l10n.revokeAllOtherSessionsDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.revokeAllButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/sessions');
      _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.allOtherSessionsRevoked),
        ),
      );
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
    final otherSessions = _sessions
        .where((s) => s['isCurrent'] != true)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activeSessions),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        actions: [
          if (otherSessions.isNotEmpty)
            TextButton(
              onPressed: _revokeAllOtherSessions,
              child: Text(
                l10n.revokeAllButton,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
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
                  ElevatedButton(
                    onPressed: _loadSessions,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : _sessions.isEmpty
          ? Center(child: Text(l10n.noActiveSessions))
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _sessions.length,
                itemBuilder: (context, index) =>
                    _buildSessionCard(_sessions[index]),
              ),
            ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = session['isCurrent'] == true;
    final deviceInfo = session['deviceInfo'] as String? ?? 'Unknown device';
    final ipAddress = session['ipAddress'] as String? ?? 'Unknown IP';
    final lastActive = session['lastActiveAt'] as String? ?? '';
    final createdAt = session['createdAt'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: AppColors.success, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _deviceIcon(deviceInfo),
                  color: isCurrent
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deviceInfo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                l10n.sessionCurrentLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.sessionIpLabel(ipAddress),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.sessionCreatedLabel(_formatDateTime(createdAt)),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.sessionLastActiveLabel(_formatDateTime(lastActive)),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
            if (!isCurrent) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _revokeSession(session['id']),
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text(
                    l10n.revokeSessionAction,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon(String deviceInfo) {
    final lower = deviceInfo.toLowerCase();
    if (lower.contains('iphone') || lower.contains('ios')) {
      return Icons.phone_iphone;
    }
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ipad') || lower.contains('tablet')) return Icons.tablet;
    if (lower.contains('web') || lower.contains('browser')) {
      return Icons.language;
    }
    if (lower.contains('mac') ||
        lower.contains('windows') ||
        lower.contains('linux')) {
      return Icons.laptop;
    }
    return Icons.devices;
  }

  String _formatDateTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
