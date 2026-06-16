import 'package:flutter/material.dart';
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
    return BlocListener<InitializationBloc, InitializationState>(
      listener: (context, state) {
        if (state is InitializationCompleted) {
          widget.onInitializationComplete();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.primaryGradient,
            ),
          ),
          child: SafeArea(
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
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_taxi,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        'Dispax',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Professional Ride Management',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),

                      const SizedBox(height: 80),

                      if (isLoading) ...[
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (showRetry)
                        ElevatedButton(
                          onPressed: () {
                            context.read<InitializationBloc>().add(
                              const RetryInitialization(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Retry'),
                        ),

                      const SizedBox(height: 40),

                      const Text(
                        'MVP Version 1.0',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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
