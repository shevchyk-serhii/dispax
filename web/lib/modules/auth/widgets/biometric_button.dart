import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../auth/services/biometric_service.dart';

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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

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

  String _getBiometricText(AppLocalizations l10n) {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return l10n.faceId;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return l10n.touchIdLabel;
    } else {
      return l10n.biometricsLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (!state.biometricAvailable || !state.biometricEnabled) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.orLabel,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
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
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.3),
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
                      decoration: const BoxDecoration(shape: BoxShape.circle),
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
              _getBiometricText(l10n),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  const BiometricSetupDialog({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.biometricSetupTitle),
      content: Text(l10n.biometricSetupMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.laterButton),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<AuthBloc>().add(
              AuthBiometricSetupRequested(enabled: true, userId: userId),
            );
            Navigator.of(context).pop();
          },
          child: Text(l10n.enableButton),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, {String? userId}) {
    return showAdaptiveDialog<void>(
      context: context,
      builder: (context) => BiometricSetupDialog(userId: userId),
    );
  }
}
