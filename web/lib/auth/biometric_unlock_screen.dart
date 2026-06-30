import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/models/person.dart';
import '../modules/core/services/error_messages.dart';

/// Biometric unlock screen — shown when biometrics are available + enabled and
/// the user has a saved session. Allows the user to unlock with Face ID / Touch
/// ID, switch accounts, or fall back to password entry.
///
/// Auth is wired to [AuthBiometricLoginRequested] (the real [local_auth] flow).
/// Falling back to password taps [onUsePassword] which navigates to [LoginScreen].
class BiometricUnlockScreen extends StatelessWidget {
  /// Called when the user taps "Use password instead".
  final VoidCallback onUsePassword;

  const BiometricUnlockScreen({super.key, required this.onUsePassword});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final person = state.user;
              // Network-class biometric failures carry a typed cause → localized
              // message; domain messages ("not available/configured") verbatim.
              final l10n = AppLocalizations.of(context);
              final errorMessage = (state.error != null && l10n != null)
                  ? friendlyError(state.error, l10n)
                  : state.errorMessage;
              return Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Small logo box
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF27272A),
                                    Color(0xFF09090B),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: AppColors.brand600,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13.5),
                                child: Image.asset(
                                  'assets/dispax_icon.png',
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Face ID icon pill — 96px white pill
                            _BiometricIconPill(state: state),

                            const SizedBox(height: 32),

                            // Title
                            const Text(
                              'Unlock Dispax',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subtitle with user name
                            if (person != null) ...[
                              Text(
                                'Continue as ${person.name}',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 32),

                              // Role-switch panel
                              _RoleSwitchPanel(person: person),
                            ] else ...[
                              const Text(
                                'Authenticate to continue.',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom actions ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: Column(
                      children: [
                        // Error message
                        if (state.hasError && errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],

                        // "Use password instead" link
                        TextButton(
                          onPressed: onUsePassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Use password instead',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated biometric icon pill (96px white pill with Face ID icon)
// ---------------------------------------------------------------------------

class _BiometricIconPill extends StatefulWidget {
  final AuthState state;

  const _BiometricIconPill({required this.state});

  @override
  State<_BiometricIconPill> createState() => _BiometricIconPillState();
}

class _BiometricIconPillState extends State<_BiometricIconPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(BuildContext context) async {
    // Capture the bloc reference before the async gap.
    final bloc = context.read<AuthBloc>();
    await _controller.forward();
    await _controller.reverse();
    if (mounted) {
      bloc.add(const AuthBiometricLoginRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state.isLoading;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: isLoading ? null : () => _onTap(context),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.face, size: 48, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role-switch panel: shows current user avatar + name + role + chevron
// ---------------------------------------------------------------------------

class _RoleSwitchPanel extends StatelessWidget {
  final Person person;

  const _RoleSwitchPanel({required this.person});

  String _roleLabel(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return 'Driver';
      case PersonRole.client:
        return 'Client';
      case PersonRole.secretary:
        return 'Secretary';
      case PersonRole.dispatcher:
        return 'Dispatcher';
      case PersonRole.admin:
        return 'Admin';
      case PersonRole.clientSecretary:
        return 'Client Secretary';
      case PersonRole.superAdmin:
        return 'Super Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Avatar initials
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleLabel(person.role),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
