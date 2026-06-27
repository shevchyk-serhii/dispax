// Guards the compact spacing of the Create New Ride form.
//
// The form had too much vertical whitespace on a phone: 16dp gaps between every
// section and 24dp (paddingLarge) padding inside each card. The fix routes those
// through two dedicated constants so the whole form's density is tunable in one
// place. This test locks in that they stay COMPACT — strictly tighter than the
// generic section/card spacing — so a later edit can't quietly inflate them back.

import 'package:dispax/constants/app_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('form section gap is tighter than the default medium padding', () {
    // Between-section gap was paddingMedium (16); compact target is smaller.
    expect(AppDimensions.formSectionGap, lessThan(AppDimensions.paddingMedium));
    expect(AppDimensions.formSectionGap, greaterThanOrEqualTo(8.0));
  });

  test('form card padding is tighter than the default large padding', () {
    // Card padding was paddingLarge (24); compact target is smaller.
    expect(AppDimensions.formCardPadding, lessThan(AppDimensions.paddingLarge));
    expect(AppDimensions.formCardPadding, greaterThanOrEqualTo(12.0));
  });
}
