import 'package:flutter/material.dart';

/// Global notifier for the active locale. `null` means the system/device locale
/// is used. Mirrors the pattern of [themeModeNotifier] in main.dart.
///
/// Declared in a separate module so it can be imported independently by both
/// [main.dart] (to wire into [MaterialApp]) and [AuthBloc] (to apply the
/// server-side language preference on login/init) without creating a circular
/// import.
final localeNotifier = ValueNotifier<Locale?>(null);

/// Converts a BCP-47 language code string to a [Locale], or `null` when the
/// code is not one of the supported locales (en, de, uk).
Locale? localeFromString(String? code) => switch (code) {
  'en' => const Locale('en'),
  'de' => const Locale('de'),
  'uk' => const Locale('uk'),
  _ => null,
};
