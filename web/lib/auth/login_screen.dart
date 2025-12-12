import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../dashboard/dashboard_screen.dart';
import '../modules/core/navigation_helper.dart';
import '../modules/core/auth_helper.dart';
import '../modules/auth/widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static final formKey = GlobalKey<FormState>();
  static final emailController = TextEditingController();
  static final passwordController = TextEditingController();
  static final obscurePasswordNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTheme.buildGradientContainer(
        colors: AppColors.primaryGradient,
        stops: const [0.0, 0.5, 1.0],
        child: SafeArea(
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state.isAuthenticated) {
                    NavigationHelper.pushReplacement(
                      context,
                      const DashboardScreen(),
                    );
                  }
                },
              ),
            ],
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.paddingXXLarge + AppDimensions.paddingMedium),
                      
                      // App Header
                      const AppHeader(),
                      
                      const SizedBox(height: AppDimensions.paddingXXLarge + AppDimensions.paddingMedium),
                      
                      // Login Card
                      LoginCard(
                        formKey: formKey,
                        emailController: emailController,
                        passwordController: passwordController,
                        obscurePasswordNotifier: obscurePasswordNotifier,
                        onSubmit: () => _login(context),
                        onErrorDismiss: () => AuthHelper.clearError(context),
                      ),
                      
                      const SizedBox(height: AppDimensions.paddingLarge),
                      
                      // Test Credentials Section
                      TestCredentialsSection(
                        onCredentialTap: (email, password) {
                          emailController.text = email;
                          passwordController.text = password;
                        },
                        onQuickLogin: (email) => AuthHelper.quickLogin(context, email),
                      ),
                      
                      const SizedBox(height: AppDimensions.paddingXLarge),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static void _login(BuildContext context) {
    if (formKey.currentState!.validate()) {
      AuthHelper.performLogin(
        context,
        emailController.text,
        passwordController.text,
      );
    }
  }
}