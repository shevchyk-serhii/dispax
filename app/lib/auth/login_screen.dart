import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../dashboard/dashboard_screen.dart';
import '../utils/navigation_helper.dart';
import '../utils/auth_helper.dart';
import '../widgets/widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static final formKey = GlobalKey<FormState>();
  static final emailController = TextEditingController();
  static final passwordController = TextEditingController();
  static final obscurePasswordNotifier = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                  return const LoadingWidget();
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppHeader(),
                      const SizedBox(height: 48),
                      LoginForm(
                        onSubmit: () => login(context),
                        formKey: formKey,
                        emailController: emailController,
                        passwordController: passwordController,
                        obscurePasswordNotifier: obscurePasswordNotifier,
                      ),
                      if (authState.hasError) ...[
                        const SizedBox(height: 16),
                        ErrorMessageCard(
                          message: authState.errorMessage!,
                          onClose: () => AuthHelper.clearError(context),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TestCredentialsCard(
                        onCredentialTap: (email, password) {
                          emailController.text = email;
                          passwordController.text = password;
                        },
                      ),
                      const SizedBox(height: 16),
                      QuickLoginButtons(
                        onQuickLogin: (email) =>
                            AuthHelper.quickLogin(context, email),
                      ),
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

  static void login(BuildContext context) {
    if (formKey.currentState!.validate()) {
      AuthHelper.performLogin(
        context,
        emailController.text,
        passwordController.text,
      );
    }
  }
}
