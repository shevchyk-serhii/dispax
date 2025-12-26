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
    performLogin(context, email, 'password123');
  }

  static void logout(BuildContext context) {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  static void clearError(BuildContext context) {
    context.read<AuthBloc>().add(const AuthErrorCleared());
  }
}
