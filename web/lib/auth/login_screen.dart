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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _obscurePasswordNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      AuthHelper.performLogin(
        context,
        _emailController.text,
        _passwordController.text,
      );
    }
  }

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
                      const SizedBox(
                        height:
                            AppDimensions.paddingXXLarge +
                            AppDimensions.paddingMedium,
                      ),

                      const AppHeader(),

                      const SizedBox(
                        height:
                            AppDimensions.paddingXXLarge +
                            AppDimensions.paddingMedium,
                      ),

                      LoginCard(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePasswordNotifier: _obscurePasswordNotifier,
                        onSubmit: _login,
                        onErrorDismiss: () => AuthHelper.clearError(context),
                      ),

                      const SizedBox(height: AppDimensions.paddingLarge),

                      TestCredentialsSection(
                        onCredentialTap: (email, password) {
                          _emailController.text = email;
                          _passwordController.text = password;
                        },
                        onQuickLogin: (email) =>
                            AuthHelper.quickLogin(context, email),
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
}
