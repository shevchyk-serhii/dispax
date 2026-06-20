import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../blocs/initialization/initialization_bloc.dart';
import '../../blocs/initialization/initialization_event.dart';
import '../../blocs/initialization/initialization_state.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({super.key, required this.onInitializationComplete});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InitializationBloc()..add(const InitializeApp()),
      child: SplashScreenContent(
        onInitializationComplete: onInitializationComplete,
      ),
    );
  }
}

class SplashScreenContent extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreenContent({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<SplashScreenContent> createState() => SplashScreenContentState();
}

class SplashScreenContentState extends State<SplashScreenContent>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeIn),
    );

    animationController.forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocListener<InitializationBloc, InitializationState>(
        listener: (context, state) {
          if (state is InitializationCompleted) {
            widget.onInitializationComplete();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: BlocBuilder<InitializationBloc, InitializationState>(
                builder: (context, state) {
                  String statusText = 'Initializing Dispax...';
                  bool isLoading = true;
                  bool showRetry = false;

                  if (state is InitializationLoading) {
                    statusText = state.statusMessage;
                    isLoading = true;
                  } else if (state is InitializationCompleted) {
                    statusText = 'Welcome to Dispax!';
                    isLoading = false;
                  } else if (state is InitializationError) {
                    statusText = state.errorMessage;
                    isLoading = false;
                    showRetry = true;
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo box — gradient #27272A → #09090B, 74×74, border #3F3F46
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF27272A), Color(0xFF09090B)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.brand600,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.5),
                          child: Image.asset(
                            'assets/dispax_icon.png',
                            width: 46,
                            height: 46,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // "Dispax" — 30px w700 white
                      const Text(
                        'Dispax',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Tagline — 13px textSecondary (#A1A1AA)
                      const Text(
                        'Ride dispatch, in control.',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 64),

                      // Spinner — accent color
                      if (isLoading) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Status text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (showRetry)
                        TextButton(
                          onPressed: () {
                            context.read<InitializationBloc>().add(
                              const RetryInitialization(),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
