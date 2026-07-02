import 'dart:math';

/// Generates a temporary password that satisfies the backend policy
/// (AuthService.validatePassword): at least 8 characters with an uppercase
/// letter, a lowercase letter, and a digit. Ambiguous characters (0/O,
/// 1/l/I) are excluded so the password is easy to read out and retype when
/// shared out-of-band.
String generateTempPassword({int length = 10, Random? random}) {
  assert(length >= 8, 'the backend requires at least 8 characters');
  final rng = random ?? Random.secure();
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnpqrstuvwxyz';
  const digits = '23456789';
  const all = upper + lower + digits;
  final chars = [
    upper[rng.nextInt(upper.length)],
    lower[rng.nextInt(lower.length)],
    digits[rng.nextInt(digits.length)],
    for (var i = 3; i < length; i++) all[rng.nextInt(all.length)],
  ]..shuffle(rng);
  return chars.join();
}

/// Mirrors the backend password policy so the form can reject a manually
/// edited temporary password before the request is sent.
bool isValidTempPassword(String password) {
  return password.length >= 8 &&
      password.contains(RegExp(r'[A-Z]')) &&
      password.contains(RegExp(r'[a-z]')) &&
      password.contains(RegExp(r'[0-9]'));
}
