import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/error_messages.dart';
import '../modules/schedule_management/models/calendar_share.dart';
import '../modules/schedule_management/services/calendar_share_service.dart';

/// Driver/Dispatcher screen: share my personal calendar with drivers or
/// dispatchers of other companies via invite codes, and manage both sides of
/// the resulting grants (who sees my calendar / calendars shared with me).
class CalendarSharingScreen extends StatefulWidget {
  /// Injectable for widget tests; defaults to a service built on the
  /// authenticated ApiClient from AuthBloc.
  final CalendarShareService? service;

  /// Whether to render the screen with its own AppBar (pushed route) instead
  /// of the embedded dashboard header.
  final bool withAppBar;

  const CalendarSharingScreen({
    super.key,
    this.service,
    this.withAppBar = false,
  });

  /// Accepts either a raw invite code or a pasted link; the code is the last
  /// path segment matching the token charset.
  static String extractCode(String raw) {
    final trimmed = raw.trim();
    final segments = trimmed
        .split(RegExp(r'[/\s]'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return trimmed;
    final tokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,64}$');
    for (final segment in segments.reversed) {
      if (tokenPattern.hasMatch(segment)) return segment;
    }
    return trimmed;
  }

  @override
  State<CalendarSharingScreen> createState() => _CalendarSharingScreenState();
}

class _CalendarSharingScreenState extends State<CalendarSharingScreen> {
  late final CalendarShareService _service;

  List<CalendarShareInvite> _invites = [];
  List<CalendarShareGrant> _granted = [];
  List<CalendarShareGrant> _sharedWithMe = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Never instantiate a bare ApiClient() — always the authenticated one.
    _service =
        widget.service ??
        CalendarShareService(apiClient: context.read<AuthBloc>().apiClient);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getMyInvites(),
        _service.getGranted(),
        _service.getSharedWithMe(),
      ]);
      if (mounted) {
        setState(() {
          _invites = results[0] as List<CalendarShareInvite>;
          _granted = results[1] as List<CalendarShareGrant>;
          _sharedWithMe = results[2] as List<CalendarShareGrant>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _showError(Object e) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.shareActionFailed(friendlyError(e, l10n))),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Invites ────────────────────────────────────────────────────────────────

  Future<void> _createInvite() async {
    final l10n = AppLocalizations.of(context)!;
    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.shareCreateInvite),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 1),
            child: Text(l10n.shareInviteExpiry1Day),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 7),
            child: Text(l10n.shareInviteExpiry7Days),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 30),
            child: Text(l10n.shareInviteExpiry30Days),
          ),
        ],
      ),
    );
    if (days == null) return;
    try {
      final invite = await _service.createInvite(expiresInDays: days);
      if (!mounted) return;
      setState(() => _invites = [invite, ..._invites]);
      await _showInviteCodeDialog(invite);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _showInviteCodeDialog(CalendarShareInvite invite) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareInviteCreatedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareInviteCreatedHint,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  dialogContext,
                ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                invite.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.shareCopyCode),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.code));
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.shareCodeCopied)));
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeInvite(CalendarShareInvite invite) async {
    final previous = _invites;
    setState(
      () => _invites = _invites.where((i) => i.id != invite.id).toList(),
    );
    try {
      await _service.revokeInvite(invite.id);
    } catch (e) {
      if (mounted) {
        setState(() => _invites = previous);
        _showError(e);
      }
    }
  }

  // ── Grants ────────────────────────────────────────────────────────────────

  Future<void> _revokeGranted(CalendarShareGrant grant) async {
    final previous = _granted;
    setState(() => _granted = _granted.where((g) => g.id != grant.id).toList());
    try {
      await _service.revokeGranted(grant.id);
    } catch (e) {
      if (mounted) {
        setState(() => _granted = previous);
        _showError(e);
      }
    }
  }

  Future<void> _unlinkSharedWithMe(CalendarShareGrant grant) async {
    final previous = _sharedWithMe;
    setState(
      () =>
          _sharedWithMe = _sharedWithMe.where((g) => g.id != grant.id).toList(),
    );
    try {
      await _service.unlinkSharedWithMe(grant.id);
    } catch (e) {
      if (mounted) {
        setState(() => _sharedWithMe = previous);
        _showError(e);
      }
    }
  }

  // ── Redeem ────────────────────────────────────────────────────────────────

  Future<void> _redeemDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareRedeemTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.shareRedeemHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              CalendarSharingScreen.extractCode(controller.text),
            ),
            child: Text(l10n.shareRedeemConnect),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final grant = await _service.redeem(code);
      if (!mounted) return;
      setState(() => _sharedWithMe = [grant, ..._sharedWithMe]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.shareRedeemSuccess(grant.grantorName),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.withAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.calendarSharingTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: l10n.refresh,
            ),
          ],
        ),
        body: _buildBody(),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: 14,
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.calendarSharingTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadData,
                tooltip: l10n.refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final error = _error == null ? null : friendlyError(_error, l10n);
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(error, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        _sectionTitle(l10n.shareSharedWithMeSection),
        _SharedWithMeCard(
          grants: _sharedWithMe,
          emptyLabel: l10n.shareNoSharedWithMe,
          onEnterCode: _redeemDialog,
          onUnlink: _unlinkSharedWithMe,
        ),
        const SizedBox(height: 20),
        _sectionTitle(l10n.shareInvitesSection),
        _InvitesCard(
          invites: _invites,
          emptyLabel: l10n.shareNoInvites,
          onCreate: _createInvite,
          onShowCode: _showInviteCodeDialog,
          onRevoke: _revokeInvite,
        ),
        const SizedBox(height: 20),
        _sectionTitle(l10n.shareGrantedSection),
        _GrantedCard(
          grants: _granted,
          emptyLabel: l10n.shareNoGrants,
          onRevoke: _revokeGranted,
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

// ─── Cards ────────────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? AppColors.surfaceDark : AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowXs,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Card shell: the decorated container plus a transparent Material so the
/// ListTiles inside can paint their ink splashes (a bare DecoratedBox would
/// swallow them and trip the framework assertion).
Widget _card(BuildContext context, Widget child) {
  return Container(
    decoration: _cardDecoration(context),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: child,
    ),
  );
}

String _shortDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  return MaterialLocalizations.of(context).formatShortDate(local);
}

class _SharedWithMeCard extends StatelessWidget {
  final List<CalendarShareGrant> grants;
  final String emptyLabel;
  final VoidCallback onEnterCode;
  final void Function(CalendarShareGrant) onUnlink;

  const _SharedWithMeCard({
    required this.grants,
    required this.emptyLabel,
    required this.onEnterCode,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      context,
      Column(
        children: [
          if (grants.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...grants.map(
              (grant) => ListTile(
                leading: const Icon(Icons.calendar_month, size: 22),
                title: Text(
                  grant.grantorName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${grant.grantorCompanyName} · ${l10n.shareSince(_shortDate(context, grant.createdAt))}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: TextButton(
                  onPressed: () => onUnlink(grant),
                  child: Text(l10n.shareUnlink),
                ),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.key,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              l10n.shareEnterCode,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: onEnterCode,
          ),
        ],
      ),
    );
  }
}

class _InvitesCard extends StatelessWidget {
  final List<CalendarShareInvite> invites;
  final String emptyLabel;
  final VoidCallback onCreate;
  final void Function(CalendarShareInvite) onShowCode;
  final void Function(CalendarShareInvite) onRevoke;

  const _InvitesCard({
    required this.invites,
    required this.emptyLabel,
    required this.onCreate,
    required this.onShowCode,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      context,
      Column(
        children: [
          if (invites.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...invites.map(
              (invite) => ListTile(
                leading: const Icon(Icons.qr_code_2, size: 22),
                title: Text(
                  '${invite.code.substring(0, 8)}…',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.shareValidUntil(_shortDate(context, invite.expiresAt)),
                  style: const TextStyle(fontSize: 11.5),
                ),
                onTap: () => onShowCode(invite),
                trailing: TextButton(
                  onPressed: () => onRevoke(invite),
                  child: Text(l10n.shareRevoke),
                ),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.add,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              l10n.shareCreateInvite,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _GrantedCard extends StatelessWidget {
  final List<CalendarShareGrant> grants;
  final String emptyLabel;
  final void Function(CalendarShareGrant) onRevoke;

  const _GrantedCard({
    required this.grants,
    required this.emptyLabel,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (grants.isEmpty) {
      return Container(
        decoration: _cardDecoration(context),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Text(
          emptyLabel,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return _card(
      context,
      Column(
        children: grants
            .map(
              (grant) => ListTile(
                leading: const Icon(Icons.visibility, size: 22),
                title: Text(
                  grant.granteeName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${grant.granteeCompanyName} · ${l10n.shareSince(_shortDate(context, grant.createdAt))}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: TextButton(
                  onPressed: () => onRevoke(grant),
                  child: Text(l10n.shareRevoke),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
