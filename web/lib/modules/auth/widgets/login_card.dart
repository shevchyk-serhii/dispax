import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import 'login_form.dart';
import 'error_message_card.dart';

/// The sign-in card: graphite header (logo + titles) + light content (form).
///
/// Pixel spec for the header:
///  • Logo box: 52×52 gradient #27272A→#09090B, radius15, border #3F3F46
///  • Title: "Welcome back" 24px w700 white
///  • Subtitle: "Sign in to your dispatch account." 13px #A1A1AA (textLight)
///
/// Content area: white/surface, rounded top corners radius24, form inside.
class LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> obscurePasswordNotifier;
  final VoidCallback onSubmit;
  final VoidCallback? onErrorDismiss;

  const LoginCard({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePasswordNotifier,
    required this.onSubmit,
    this.onErrorDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // The auth screen is a fixed graphite-header + light-content composition
    // (a branded sign-in surface), so the content panel stays light in both
    // themes. This keeps the graphite Sign-in button and white input fields
    // legible — a theme-following dark panel would hide the dark button.
    const surfaceColor = AppColors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Graphite header ─────────────────────────────────────────────────
        _GraphiteHeader(),

        // ── Light content area ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingLarge,
              AppDimensions.paddingXLarge,
              AppDimensions.paddingLarge,
              AppDimensions.paddingXLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Form ──────────────────────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    return LoginForm(
                      onSubmit: onSubmit,
                      formKey: formKey,
                      emailController: emailController,
                      passwordController: passwordController,
                      obscurePasswordNotifier: obscurePasswordNotifier,
                      showBiometric:
                          authState.biometricAvailable &&
                          authState.biometricEnabled,
                      onBiometricTap: () => context.read<AuthBloc>().add(
                        const AuthBiometricLoginRequested(),
                      ),
                    );
                  },
                ),

                // ── Error message ──────────────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    if (authState.hasError) {
                      return Column(
                        children: [
                          const SizedBox(height: AppDimensions.paddingMedium),
                          ErrorMessageCard(
                            message: authState.errorMessage!,
                            onDismiss: onErrorDismiss,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Graphite header with logo, title, and subtitle
// ---------------------------------------------------------------------------

class _GraphiteHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo box — 52×52 gradient, radius15, border brand600
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF27272A), Color(0xFF09090B)],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.brand600, width: 1.5),
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

          const SizedBox(height: 20),

          // Title — 24px w700 white
          Text(
            AppLocalizations.of(context)!.welcomeBack,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle — 13px #A1A1AA (textLight)
          Text(
            AppLocalizations.of(context)!.signInSubtitle,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
