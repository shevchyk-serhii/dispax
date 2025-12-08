import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../services/biometric_service.dart';

class BiometricButton extends StatefulWidget {
  const BiometricButton({super.key});

  @override
  State<BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<BiometricButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  BiometricService? _biometricService;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    _biometricService = BiometricService();
    _availableBiometrics = await _biometricService!.availableBiometrics;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _animationController.forward();
    await _animationController.reverse();
    
    if (mounted) {
      context.read<AuthBloc>().add(const AuthBiometricLoginRequested());
    }
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else {
      return Icons.security;
    }
  }

  String _getBiometricText() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else {
      return 'Биометрия';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Show biometric button only if available and enabled
        if (!state.biometricAvailable || !state.biometricEnabled) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'или',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 16),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Theme.of(context).primaryColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: state.isLoading ? null : _onTap,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: state.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _getBiometricIcon(),
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getBiometricText(),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class BiometricSetupDialog extends StatelessWidget {
  final String? userId;
  
  const BiometricSetupDialog({
    super.key,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Настройка биометрии'),
      content: const Text(
        'Хотите включить быстрый вход с помощью биометрии?\n\n'
        'Это позволит входить в приложение с помощью Face ID, Touch ID или отпечатка пальца.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Позже'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<AuthBloc>().add(
              AuthBiometricSetupRequested(enabled: true, userId: userId),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Включить'),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, {String? userId}) {
    return showDialog<void>(
      context: context,
      builder: (context) => BiometricSetupDialog(userId: userId),
    );
  }
}