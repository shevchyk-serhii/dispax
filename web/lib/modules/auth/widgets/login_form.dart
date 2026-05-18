import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/app_colors.dart';
import '../../core/validators.dart';
import 'biometric_button.dart';

class LoginForm extends StatelessWidget {
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> obscurePasswordNotifier;

  const LoginForm({
    super.key,
    required this.onSubmit,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePasswordNotifier,
  });

  static final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
  );

  static final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
    borderSide: const BorderSide(color: AppColors.primary, width: 2),
  );

  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
    borderSide: const BorderSide(color: AppColors.error, width: 2),
  );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData prefixIconData,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(prefixIconData, color: Colors.white.withValues(alpha: 0.5), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: _inputBorder,
      enabledBorder: _inputBorder,
      focusedBorder: _focusedBorder,
      errorBorder: _errorBorder,
      focusedErrorBorder: _errorBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration(
              label: 'Email',
              prefixIconData: Icons.email_outlined,
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: obscurePasswordNotifier,
            builder: (context, obscurePassword, _) {
              return TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration(
                  label: 'Password',
                  prefixIconData: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () => obscurePasswordNotifier.value = !obscurePasswordNotifier.value,
                  ),
                ),
                validator: Validators.password,
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const BiometricButton(),
        ],
      ),
    );
  }
}
