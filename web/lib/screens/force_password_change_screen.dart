import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/models/person.dart';

/// Full-screen gate shown right after a user logs in with a temporary password.
/// It cannot be dismissed (no back button / skip) — the only way forward is to
/// set a new password, which clears the [Person.mustChangePassword] flag on the
/// backend and re-authenticates the user into the app.
class ForcePasswordChangeScreen extends StatefulWidget {
  final Person user;

  const ForcePasswordChangeScreen({super.key, required this.user});

  @override
  State<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthPasswordChangeRequested(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.forcePasswordChangeTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final busy = state.isLoading;
          final errorMessage = state.errorMessage;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.forcePasswordChangeMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _currentCtrl,
                        obscureText: true,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: l10n.temporaryPassword,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? l10n.required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newCtrl,
                        obscureText: true,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: l10n.newPassword,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return l10n.required;
                          if (v.length < 6) return l10n.passwordTooShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: l10n.confirmNewPassword,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v != _newCtrl.text
                            ? l10n.passwordsDoNotMatch
                            : null,
                        onFieldSubmitted: (_) => busy ? null : _submit(),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.setNewPassword),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
