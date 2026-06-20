import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../core/validators.dart';

/// The credential fields + action buttons for the sign-in screen.
///
/// Pixel spec:
/// • Email/Password label: 11px w600 uppercase textSecondary
/// • Input: h48, white fill, radius12, border borderPrimary (#E4E4E7)
///   – focused: border accent (#0EA5E9) + subtle glow
///   – password focused lock icon turns accent
/// • Prefix icons: 17px textLight; lock icon = accent (#0EA5E9)
/// • "Forgot password?" — 12.5px w600 accent, right-aligned
/// • "Sign in" button — graphite (#18181B) fill, white text, 15px w600, h50, radius13
/// • "or" divider — 11px textLight
/// • "Face ID" outlined button — white bg, border #D4D4D8, icon 18px, "Face ID" 14px w600, h50, radius13
class LoginForm extends StatelessWidget {
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> obscurePasswordNotifier;

  /// Called when the "Face ID" button is tapped. Wired to [AuthBiometricLoginRequested].
  final VoidCallback? onBiometricTap;

  /// Whether the Face ID button should be shown. Driven by [AuthState.biometricAvailable]
  /// and [AuthState.biometricEnabled].
  final bool showBiometric;

  const LoginForm({
    super.key,
    required this.onSubmit,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePasswordNotifier,
    this.onBiometricTap,
    this.showBiometric = false,
  });

  // ── Input decorations ──────────────────────────────────────────────────────

  static final _defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.borderPrimary),
  );

  static final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
  );

  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.error, width: 1.5),
  );

  InputDecoration _labeledFieldDecoration({
    required String label,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      // Floating label replaced by the uppercase label row above the field.
      // We use hintText only so the decoration doesn't shift.
      hintText: label,
      hintStyle: const TextStyle(
        color: AppColors.textLight,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: _defaultBorder,
      enabledBorder: _defaultBorder,
      focusedBorder: _focusedBorder,
      errorBorder: _errorBorder,
      focusedErrorBorder: _errorBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      isDense: false,
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Email field ──────────────────────────────────────────────────
          _fieldLabel('Email'),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: _labeledFieldDecoration(
                label: 'you@company.com',
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.email_outlined,
                    size: 17,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              validator: Validators.email,
            ),
          ),

          const SizedBox(height: 16),

          // ── Password field ───────────────────────────────────────────────
          _fieldLabel('Password'),
          const SizedBox(height: 6),
          ValueListenableBuilder<bool>(
            valueListenable: obscurePasswordNotifier,
            builder: (context, obscure, _) {
              return SizedBox(
                height: 48,
                child: TextFormField(
                  controller: passwordController,
                  obscureText: obscure,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: _labeledFieldDecoration(
                    label: '••••••••',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.lock_outline,
                        size: 17,
                        color: AppColors.accent,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 17,
                        color: AppColors.textLight,
                      ),
                      onPressed: () => obscurePasswordNotifier.value = !obscure,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  validator: Validators.password,
                ),
              );
            },
          ),

          // ── Forgot password link ─────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: implement forgot password flow
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Sign in button — graphite ────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── "or" divider + Face ID button ────────────────────────────────
          if (showBiometric) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Divider(color: AppColors.borderSecondary, height: 1),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: AppColors.borderSecondary, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FaceIdButton(onTap: onBiometricTap),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helper: the "Face ID" outlined button
// ---------------------------------------------------------------------------

class _FaceIdButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _FaceIdButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderSecondary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face, size: 18, color: AppColors.textPrimary),
            SizedBox(width: 8),
            Text(
              'Face ID',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
