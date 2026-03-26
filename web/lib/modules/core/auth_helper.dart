import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';

class AuthHelper {
  static void performLogin(
    BuildContext context,
    String email,
    String password,
  ) {
    context.read<AuthBloc>().add(
      AuthLoginRequested(email: email, password: password),
    );
  }

  static void quickLogin(BuildContext context, String email) {
    assert(kDebugMode, 'quickLogin must not be used in release builds');
    if (!kDebugMode) return;
    performLogin(context, email, 'password123');
  }

  static void logout(BuildContext context) {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  static void clearError(BuildContext context) {
    context.read<AuthBloc>().add(const AuthErrorCleared());
  }
}
