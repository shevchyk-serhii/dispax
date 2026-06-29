import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/person.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/services/api_client.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

/// Profile dialog shown from the dashboard. Graphite design, matching the
/// patterns in `settings_screen.dart` but kept as a centered dialog rather than
/// a full screen. Shows the resolved company name (not the raw companyId).
class ProfileDialog extends StatelessWidget {
  final Person user;

  const ProfileDialog({super.key, required this.user});

  static void show(BuildContext context, Person user) {
    showAdaptiveDialog(
      context: context,
      builder: (_) => ProfileDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final apiClient = context.read<AuthBloc>().apiClient;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserCard(context, apiClient, isDark),
                        const SizedBox(height: 16),
                        _buildSectionLabel(context, 'Account'),
                        _buildInfoCard(context, isDark),
                        if (authState.biometricAvailable) ...[
                          const SizedBox(height: 16),
                          _buildSectionLabel(context, 'Security'),
                          _buildSecurityCard(context, authState, isDark),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildCloseBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: const Text(
        'Profile',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ─── User card ──────────────────────────────────────────────────────────────

  Widget _buildUserCard(
    BuildContext context,
    ApiClient apiClient,
    bool isDark,
  ) {
    final cardBg = isDark
        ? AppColors.accent.withAlpha(25)
        : AppColors.accent.withAlpha(12);
    final cardBorder = AppColors.accent.withAlpha(isDark ? 50 : 35);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: SizedBox(
              width: 46,
              height: 46,
              child: AvatarCircle(user: user, apiClient: apiClient, radius: 23),
            ),
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
                  _roleDisplayName(user.role),
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
    );
  }

  // ─── Section label ────────────────────────────────────────────────────────

  Widget _buildSectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
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

  // ─── Account card ───────────────────────────────────────────────────────────

  Widget _buildInfoCard(BuildContext context, bool isDark) {
    final rows = <Widget>[
      _buildInfoRow(context, Icons.email_outlined, 'Email', user.email),
    ];
    final companyName = user.companyName;
    if (companyName != null) {
      rows.add(
        _buildInfoRow(
          context,
          Icons.business_outlined,
          'Company',
          companyName,
        ),
      );
    }
    final licenseNumber = user.licenseNumber;
    if (licenseNumber != null) {
      rows.add(
        _buildInfoRow(
          context,
          Icons.badge_outlined,
          'License',
          licenseNumber,
        ),
      );
    }
    final phone = user.phone;
    if (phone != null) {
      rows.add(
        _buildInfoRow(context, Icons.phone_outlined, 'Phone', phone),
      );
    }

    // Interleave dividers between the rows.
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(_buildDivider(context, isDark));
      children.add(rows[i]);
    }

    return _buildCard(context, isDark, children);
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBox(context, icon),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Security card ──────────────────────────────────────────────────────────

  Widget _buildSecurityCard(
    BuildContext context,
    AuthState authState,
    bool isDark,
  ) {
    return _buildCard(context, isDark, [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconBox(context, Icons.fingerprint),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Biometric Login',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: authState.biometricEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.accent,
                  onChanged: (value) {
                    context.read<AuthBloc>().add(
                      AuthBiometricSetupRequested(
                        enabled: value,
                        userId: user.id.toString(),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 43, bottom: 4),
              child: Text(
                authState.biometricEnabled
                    ? 'Quick login with Face ID/Touch ID enabled'
                    : 'Use biometrics for quick login',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ─── Close bar ────────────────────────────────────────────────────────────

  Widget _buildCloseBar(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
    );
  }

  // ─── Shared builders ────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context, bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 0,
      color: isDark ? AppColors.borderDark : const Color(0xFFF4F4F5),
    );
  }

  Widget _buildIconBox(BuildContext context, IconData icon) {
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

  String _roleDisplayName(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return 'Driver';
      case PersonRole.client:
        return 'Client';
      case PersonRole.secretary:
        return 'Secretary';
      case PersonRole.clientSecretary:
        return 'Client Secretary';
      case PersonRole.dispatcher:
        return 'Dispatcher';
      case PersonRole.admin:
        return 'Admin';
      case PersonRole.superAdmin:
        return 'Platform Admin';
    }
  }
}
