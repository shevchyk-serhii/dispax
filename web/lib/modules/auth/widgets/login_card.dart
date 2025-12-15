import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';
import 'login_form.dart';
import 'error_message_card.dart';

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
    return Container(
      width: double.infinity,
      decoration: AppTheme.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back',
              style: AppStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'Sign in to continue',
              style: AppStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingXLarge + AppDimensions.paddingSmall),

            LoginForm(
              onSubmit: onSubmit,
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              obscurePasswordNotifier: obscurePasswordNotifier,
            ),

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
    );
  }
}