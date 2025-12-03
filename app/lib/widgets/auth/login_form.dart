import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../utils/validators.dart';

class LoginForm extends StatelessWidget {
  final VoidCallback onSubmit;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> obscurePasswordNotifier;

  const LoginForm({
    super.key,
    required this.onSubmit,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePasswordNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: obscurePasswordNotifier,
            builder: (context, obscurePassword, child) {
              return TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      obscurePasswordNotifier.value =
                          !obscurePasswordNotifier.value;
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: Validators.password,
              );
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.defaultBorderRadius,
                ),
              ),
            ),
            child: const Text('Login', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
