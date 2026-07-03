/// Client-side mirror of the backend password policy
/// (`AuthService.validatePassword`): at least 8 characters with an uppercase
/// letter, a lowercase letter, and a digit.
///
/// Single source of truth for every password field in the app (change
/// password in settings, forced password change, admin/secretary create-user
/// forms) so the form rejects exactly what the backend would reject, instead
/// of letting a weak password through to a raw 400.
bool isPolicyCompliantPassword(String password) {
  return password.length >= 8 &&
      password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]')) &&
      password.contains(RegExp(r'[0-9]'));
}
