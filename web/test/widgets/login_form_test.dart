// Widget tests for LoginForm — the email/password fields of the sign-in screen.
//
// The form itself is a StatelessWidget whose two TextFormFields carry
// Validators.email / Validators.password. The parent screen drives submit via
// `formKey.currentState!.validate()` (see lib/auth/login_screen.dart), so these
// tests own the form key, enter text, run validate(), and assert which error
// messages surface and whether the form is considered valid.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/auth/widgets/login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GlobalKey<FormState> formKey;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late ValueNotifier<bool> obscure;
  late int submitCount;

  setUp(() {
    formKey = GlobalKey<FormState>();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    obscure = ValueNotifier<bool>(true);
    submitCount = 0;
  });

  tearDown(() {
    emailController.dispose();
    passwordController.dispose();
    obscure.dispose();
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LoginForm(
          onSubmit: () {
            // Mirror the screen: only count a submit that passes validation.
            if (formKey.currentState?.validate() ?? false) submitCount++;
          },
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          obscurePasswordNotifier: obscure,
        ),
      ),
    ),
  );

  testWidgets('empty fields fail validation and show errors', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Enter email'), findsOneWidget);
    expect(find.text('Enter password'), findsOneWidget);
    expect(submitCount, 0);
  });

  testWidgets('malformed email fails validation', (tester) async {
    await tester.pumpWidget(buildSubject());

    emailController.text = 'test@'; // no domain/dot
    passwordController.text = 'goodpass';

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter correct email'), findsOneWidget);
  });

  testWidgets('too-short password fails validation', (tester) async {
    await tester.pumpWidget(buildSubject());

    emailController.text = 'a@b.de';
    passwordController.text = 'abc'; // shorter than minPasswordLength (6)

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.textContaining('at least'), findsOneWidget);
  });

  testWidgets('valid credentials pass and trigger onSubmit', (tester) async {
    await tester.pumpWidget(buildSubject());

    emailController.text = 'a@b.de';
    passwordController.text = 'goodpass';

    expect(formKey.currentState!.validate(), isTrue);

    await tester.tap(find.byType(ElevatedButton)); // Sign in
    await tester.pump();
    expect(submitCount, 1);
  });
}
