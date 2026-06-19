// Lucide icon constants for Dispax. These are the raw codepoint + font family
// values extracted from lucide_icons 0.257.0 so that tests can compile without
// the broken `LucideIconData extends IconData` pattern that fails in Dart 3.x
// unit-test (VM) compilation.
//
// Usage: import this file instead of `package:lucide_icons/lucide_icons.dart`
// for any widget that needs to be unit-tested. The visual output is identical
// because the same font and codepoints are used; only the class hierarchy
// declaration is different.

import 'package:flutter/widgets.dart';

const String _fontFamily = 'Lucide';
const String _fontPackage = 'lucide_icons';

// ignore: avoid_classes_with_only_static_members
class LucideCompat {
  const LucideCompat._();

  static const IconData alertTriangle = IconData(
    0xf10d,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData arrowDown = IconData(
    0xf13c,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData building2 = IconData(
    0xf1cd,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData calendarDays = IconData(
    0xf1d6,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData car = IconData(
    0xf1e5,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData check = IconData(
    0xf1ee,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData clipboardList = IconData(
    0xf21c,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData clock = IconData(
    0xf221,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData download = IconData(
    0xf287,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData fileText = IconData(
    0xf2d3,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData list = IconData(
    0xf39b,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData map = IconData(
    0xf3bf,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData moreVertical = IconData(
    0xf3ee,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData receipt = IconData(
    0xf477,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData settings = IconData(
    0xf4b9,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData share2 = IconData(
    0xf4bd,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData user = IconData(
    0xf564,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData userCheck = IconData(
    0xf566,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData users = IconData(
    0xf574,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );

  static const IconData x = IconData(
    0xf59e,
    fontFamily: _fontFamily,
    fontPackage: _fontPackage,
  );
}
