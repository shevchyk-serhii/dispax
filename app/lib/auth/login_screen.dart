import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../dashboard/dashboard_screen.dart';
import '../utils/navigation_helper.dart';
import '../utils/auth_helper.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
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
                      // Modern App Header
                      _buildModernHeader(),
                      const SizedBox(height: AppDimensions.paddingXXLarge + AppDimensions.paddingMedium),
                      
                      // Login Card
                      _buildLoginCard(context, authState),
                      
                      const SizedBox(height: AppDimensions.paddingLarge),
                      
                      // Quick Login Section
                      _buildQuickLoginSection(context),
                      
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

  Widget _buildModernHeader() {
    return Column(
      children: [
        Container(
          width: AppDimensions.iconHero,
          height: AppDimensions.iconHero,
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXXLarge),
            border: Border.all(color: AppColors.glassBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_taxi_rounded,
            size: AppDimensions.iconLogo,
            color: AppColors.textOnPrimary,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingLarge),
        Text(
          'Oktopus Taxi',
          style: AppStyles.glassHeadlineLarge,
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          'Professional Ride Management',
          style: AppStyles.glassBodyLarge,
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, AuthState authState) {
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
              onSubmit: () => login(context),
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              obscurePasswordNotifier: obscurePasswordNotifier,
            ),
            
            if (authState.hasError) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline, 
                      color: AppColors.error, 
                      size: AppDimensions.iconMedium,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Text(
                        authState.errorMessage!,
                        style: AppStyles.bodyMedium.copyWith(color: AppColors.error),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close, 
                        color: AppColors.error, 
                        size: AppDimensions.iconSmall,
                      ),
                      onPressed: () => AuthHelper.clearError(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLoginSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'Quick Access for Testing',
          style: AppStyles.glassTitleMedium,
        ),
        const SizedBox(height: AppDimensions.paddingMedium),
        
        TestCredentialsCard(
          onCredentialTap: (email, password) {
            emailController.text = email;
            passwordController.text = password;
          },
        ),
        
        const SizedBox(height: AppDimensions.paddingMedium),
        
        QuickLoginButtons(
          onQuickLogin: (email) => AuthHelper.quickLogin(context, email),
        ),
      ],
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
