import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../blocs/blocs.dart';
import '../modules/core/services/version_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/models/person.dart';
import '../modules/core/widgets/avatar_circle.dart';
import '../main.dart' show themeModeNotifier, themeFromString;
import '../locale_notifier.dart' show localeNotifier, localeFromString;
import '../l10n/app_localizations.dart';
import 'gdpr_screen.dart';
import 'session_management_screen.dart';
import '../dashboard/driver/earnings_screen.dart';
import '../dashboard/client/client_addresses_screen.dart';
import '../modules/core/services/error_messages.dart';
import '../modules/core/services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'system';
  String _language = 'en';
  bool _pushEnabled = true;
  bool _uploadingAvatar = false;
  int _sessionCount = 1;
  String? _appVersion;
  BackendVersion? _backendVersion;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSessionCount();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(
        () => _appVersion = '${info.version} (build ${info.buildNumber})',
      );
    } catch (_) {
      // Non-critical; the row falls back to a dash.
    }
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final backend = await VersionService(
        apiClient: apiClient,
      ).fetchBackendVersion();
      if (!mounted) return;
      setState(() => _backendVersion = backend);
    } catch (_) {
      // Backend unreachable — the row falls back to a dash.
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _language = prefs.getString('language') ?? 'en';
      _pushEnabled = prefs.getBool('push_enabled') ?? true;
    });
  }

  Future<void> _loadSessionCount() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/sessions');
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          setState(() => _sessionCount = decoded.length);
        }
      }
    } catch (_) {
      // Non-critical; keep default of 1
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = context.select(
      (AuthBloc bloc) => (
        user: bloc.state.user,
        biometricAvailable: bloc.state.biometricAvailable,
        biometricEnabled: bloc.state.biometricEnabled,
      ),
    );
    final user = authState.user;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _buildGraphiteHeader(),
          Expanded(
            child: ListView(
              children: [
                if (user != null) _buildUserCard(user),
                const SizedBox(height: 8),
                _buildPreferencesSection(
                  biometricAvailable: authState.biometricAvailable,
                  biometricEnabled: authState.biometricEnabled,
                  userId: user?.id,
                ),
                const SizedBox(height: 8),
                _buildGeneralSection(),
                if (user?.role == PersonRole.driver) ...[
                  const SizedBox(height: 8),
                  _buildEarningsSection(),
                ],
                if (user?.role == PersonRole.client) ...[
                  const SizedBox(height: 8),
                  _buildSavedAddressesSection(),
                ],
                const SizedBox(height: 8),
                _buildPrivacySection(),
                const SizedBox(height: 8),
                _buildAboutSection(),
                const SizedBox(height: 24),
                _buildSignOutRow(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphiteHeader() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                // Back button if we can pop
                if (Navigator.of(context).canPop())
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                Text(
                  AppLocalizations.of(context)!.settingsTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── User card ────────────────────────────────────────────────────────────

  Widget _buildUserCard(Person user) {
    final apiClient = context.read<AuthBloc>().apiClient;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.accent.withAlpha(25)
        : AppColors.accent.withAlpha(12);
    final cardBorder = AppColors.accent.withAlpha(isDark ? 50 : 35);

    return GestureDetector(
      onTap: () => _showEditProfileDialog(user),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            // Avatar 46
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: AvatarCircle(
                      user: user,
                      apiClient: apiClient,
                      radius: 23,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploadingAvatar
                        ? null
                        : () => _pickAndUploadAvatar(user),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: _uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 10,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roleLocationLabel(user),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _roleLocationLabel(Person user) {
    final role = _roleDisplayName(user.role);
    // Person has no city field; use email domain as location fallback
    return role;
  }

  String _roleDisplayName(PersonRole role) {
    final l10n = AppLocalizations.of(context)!;
    switch (role) {
      case PersonRole.driver:
        return l10n.roleDriver;
      case PersonRole.client:
        return l10n.roleClient;
      case PersonRole.secretary:
        return l10n.roleSecretary;
      case PersonRole.clientSecretary:
        return l10n.roleClientSecretary;
      case PersonRole.dispatcher:
        return l10n.roleDispatcher;
      case PersonRole.admin:
        return l10n.roleAdmin;
      case PersonRole.superAdmin:
        return l10n.roleSuperAdmin;
    }
  }

  // ─── Section label ────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ─── Preferences card ─────────────────────────────────────────────────────

  Widget _buildPreferencesSection({
    required bool biometricAvailable,
    required bool biometricEnabled,
    required String? userId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.preferences),
        _buildSettingsCard([
          _buildToggleRow(
            icon: Icons.notifications_outlined,
            label: l10n.pushNotifications,
            value: _pushEnabled,
            onChanged: (v) {
              setState(() => _pushEnabled = v);
              _savePreference('push_enabled', v);
            },
          ),
          _buildDivider(context),
          if (biometricAvailable) ...[
            _buildToggleRow(
              icon: Icons.face_outlined,
              label: l10n.faceIdUnlock,
              value: biometricEnabled,
              onChanged: (v) {
                context.read<AuthBloc>().add(
                  AuthBiometricSetupRequested(enabled: v, userId: userId),
                );
              },
            ),
            _buildDivider(context),
          ],
          _buildToggleRow(
            icon: Icons.dark_mode_outlined,
            label: l10n.darkMode,
            value: _themeMode == 'dark',
            onChanged: (v) {
              final mode = v ? 'dark' : 'light';
              setState(() => _themeMode = mode);
              _savePreference('theme_mode', mode);
              themeModeNotifier.value = themeFromString(mode);
            },
          ),
        ]),
      ],
    );
  }

  // ─── General card ─────────────────────────────────────────────────────────

  Widget _buildGeneralSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.general),
        _buildSettingsCard([
          _buildNavRow(
            icon: Icons.language,
            label: l10n.language,
            trailing: Text(
              _languageLabel(_language),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: _showLanguagePicker,
          ),
          _buildDivider(context),
          _buildNavRow(
            icon: Icons.devices_outlined,
            label: l10n.activeSessions,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_sessionCount device${_sessionCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SessionManagementScreen(),
              ),
            ),
          ),
          _buildDivider(context),
          _buildNavRow(
            icon: Icons.lock_outline,
            label: l10n.changePassword,
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: _showChangePasswordDialog,
          ),
        ]),
      ],
    );
  }

  // ─── Earnings section (driver only) ───────────────────────────────────────

  Widget _buildEarningsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.earnings),
        _buildSettingsCard([
          _buildNavRow(
            icon: Icons.bar_chart_outlined,
            label: l10n.myEarnings,
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EarningsScreen()),
            ),
          ),
        ]),
      ],
    );
  }

  // ─── Saved addresses section (client only) ────────────────────────────────

  Widget _buildSavedAddressesSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.manageAddresses),
        _buildSettingsCard([
          _buildNavRow(
            icon: Icons.bookmark_outline,
            label: l10n.manageAddresses,
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientAddressesScreen()),
            ),
          ),
        ]),
      ],
    );
  }

  // ─── Privacy section ──────────────────────────────────────────────────────

  Widget _buildPrivacySection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.privacy),
        _buildSettingsCard([
          _buildNavRow(
            icon: Icons.privacy_tip_outlined,
            label: l10n.privacyDataGdpr,
            trailing: Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GdprScreen()),
            ),
          ),
        ]),
      ],
    );
  }

  // ─── About / version ──────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.about),
        _buildSettingsCard([
          _buildInfoRow(
            icon: Icons.smartphone_outlined,
            label: l10n.appVersion,
            value: _appVersion ?? '—',
          ),
          _buildDivider(context),
          _buildInfoRow(
            icon: Icons.dns_outlined,
            label: l10n.backendVersion,
            value: _backendVersion?.display ?? '—',
          ),
        ]),
      ],
    );
  }

  /// A read-only settings row: icon + label on the left, a value on the right.
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sign out ─────────────────────────────────────────────────────────────

  Widget _buildSignOutRow() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: GestureDetector(
        onTap: _confirmSignOut,
        child: Text(
          l10n.signOut,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDC2626),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut() {
    final l10n = AppLocalizations.of(context)!;
    showAdaptiveDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              l10n.signOut,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Row builders ─────────────────────────────────────────────────────────

  Widget _buildSettingsCard(List<Widget> rows) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 0,
      color: isDark ? AppColors.borderDark : const Color(0xFFF4F4F5),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        child: Row(
          children: [
            _buildIconBox(icon),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  // ─── Language picker ──────────────────────────────────────────────────────

  String _languageLabel(String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'de':
        return l10n.german;
      case 'uk':
        return l10n.ukrainian;
      default:
        return l10n.english;
    }
  }

  void _showLanguagePicker() {
    final user = context.read<AuthBloc>().state.user;
    showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in {
              'en': 'English',
              'de': 'Deutsch',
              'uk': 'Ukrainian',
            }.entries)
              ListTile(
                title: Text(entry.value),
                trailing: _language == entry.key
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  // Apply optimistically — local state + shared prefs update
                  // immediately regardless of network so the UI switches at once.
                  setState(() => _language = entry.key);
                  _savePreference('language', entry.key);
                  localeNotifier.value = localeFromString(entry.key);

                  if (user != null) {
                    // Capture messenger and mounted check before the await so
                    // we never use BuildContext across an async gap.
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await context.read<AuthBloc>().apiClient.put(
                        '/users/${user.id}',
                        {'preferredLanguage': entry.key},
                      );
                    } catch (_) {
                      // Local language already applied; surface the failure so
                      // it is not silent, but do NOT revert the local choice.
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.languageSaveFailed,
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Avatar upload ────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar(Person user) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    final mime = xFile.mimeType ?? 'image/jpeg';

    if (!mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.postMultipart(
        '/users/${user.id}/avatar',
        'file',
        bytes,
        mime,
      );
      if (response.statusCode == 200) {
        if (mounted) {
          context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.photoUploadedSuccessfully,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.failedToUploadPhoto}: '
                '${friendlyError(ApiException('upload photo', statusCode: response.statusCode), l10n)}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.failedToUploadPhoto}: ${friendlyError(e, l10n)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _deleteAvatar(Person user) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.delete('/users/${user.id}/avatar');
      if ((response.statusCode == 204 || response.statusCode == 200) &&
          mounted) {
        context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.removePhoto)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToUploadPhoto}: $e',
            ),
          ),
        );
      }
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;

    showAdaptiveDialog(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(ctxL10n.changePassword),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ctxL10n.currentPassword,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? ctxL10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: ctxL10n.newPassword),
                  validator: (v) {
                    if (v == null || v.isEmpty) return ctxL10n.required;
                    if (v.length < 6) return ctxL10n.passwordTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: ctxL10n.confirmNewPassword,
                  ),
                  validator: (v) {
                    if (v != newCtrl.text) return ctxL10n.passwordsDoNotMatch;
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctxL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  try {
                    final authBloc = context.read<AuthBloc>();
                    final apiClient = authBloc.apiClient;
                    await apiClient.put('/users/change-password', {
                      'currentPassword': currentCtrl.text,
                      'newPassword': newCtrl.text,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passwordChanged)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${l10n.failedToChangePassword}: '
                            '${friendlyError(e, l10n)}',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(ctxL10n.change),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog(Person user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final l10n = AppLocalizations.of(context)!;

    showAdaptiveDialog(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(ctxL10n.editProfile),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: ctxL10n.name),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: ctxL10n.phone),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            if (user.hasAvatar)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteAvatar(user);
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(ctxL10n.removePhoto),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctxL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authBloc = context.read<AuthBloc>();
                  final apiClient = authBloc.apiClient;
                  await apiClient.put('/users/${user.id}', {
                    'name': nameCtrl.text,
                    'phone': phoneCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    context.read<AuthBloc>().add(
                      const AuthProfileRefreshRequested(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profileUpdated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyError(e, l10n))),
                    );
                  }
                }
              },
              child: Text(ctxL10n.save),
            ),
          ],
        );
      },
    );
  }
}
