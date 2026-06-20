import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../modules/core/auth_helper.dart';
import '../modules/auth/widgets/widgets.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2.5,
                ),
              );
            }

            return SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sign-in card: graphite header + white content
                    LoginCard(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      obscurePasswordNotifier: _obscurePasswordNotifier,
                      onSubmit: _login,
                      onErrorDismiss: () => AuthHelper.clearError(context),
                    ),

                    // Quick-access dev section on white background
                    Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceDark
                          : AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingLarge,
                        0,
                        AppDimensions.paddingLarge,
                        AppDimensions.paddingXLarge,
                      ),
                      child: TestCredentialsSection(
                        onCredentialTap: (email, password) {
                          _emailController.text = email;
                          _passwordController.text = password;
                        },
                        onQuickLogin: (email) =>
                            AuthHelper.quickLogin(context, email),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
