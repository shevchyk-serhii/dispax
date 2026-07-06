import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_actions_section.dart';

/// Regression for the "silent no-save" report: the Create button stays tappable
/// even when a non-text control (client / pickup time / flight number) is unset,
/// and the submit handler no-ops when !isValid. Tapping used to do nothing at
/// all. Now the tap must surface the first missing requirement as a SnackBar and
/// must NOT move the form into `submitting`.
class _FakeCreateRideFormBloc
    extends MockBloc<CreateRideFormEvent, CreateRideFormState>
    implements CreateRideFormBloc {}

void main() {
  late _FakeCreateRideFormBloc formBloc;

  setUp(() => formBloc = _FakeCreateRideFormBloc());
  tearDown(() => formBloc.close());

  // An empty FormState with the text fields filled and distinct addresses, but
  // no pickup time → firstMissingRequirement == pickupTime.
  CreateRideFormState noPickupTimeState() =>
      CreateRideFormState.initial().copyWith(
        selectedClientId: 'c-1',
        fromAddress: 'Munich Airport',
        toAddress: 'City Center',
        clearManualPickupDateTime: true,
      );

  // An empty FormState with EMPTY From/To addresses → the inline text-field
  // validators fail (formKey.validate() == false) AND firstMissingRequirement ==
  // fromAddress. This is the exact screenshot case.
  CreateRideFormState emptyAddressesState() => CreateRideFormState.initial()
      .copyWith(selectedClientId: 'c-1', fromAddress: '', toAddress: '');

  Widget mount(GlobalKey<FormState> formKey) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<CreateRideFormBloc>.value(
        value: formBloc,
        child: Form(
          key: formKey,
          child: CreateRideActionsSection(formKey: formKey),
        ),
      ),
    ),
  );

  // Like [mount] but the Form contains a real always-failing TextFormField so
  // formKey.validate() returns false — reproducing the empty-From/To prod path
  // where the inline validators reject the tap.
  Widget mountWithFailingValidator(GlobalKey<FormState> formKey) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<CreateRideFormBloc>.value(
        value: formBloc,
        child: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(validator: (_) => 'required'),
              CreateRideActionsSection(formKey: formKey),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'tapping Create with no pickup time shows a specific SnackBar and does not '
    'dispatch FormSubmitted',
    (tester) async {
      whenListen(
        formBloc,
        Stream<CreateRideFormState>.empty(),
        initialState: noPickupTimeState(),
      );
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(mount(formKey));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // let the SnackBar appear

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The specific "what's missing" message is shown...
      expect(find.text(l10n.selectPickupTimeError), findsOneWidget);
      // ...and the form was NOT submitted (no FormSubmitted dispatched).
      verifyNever(() => formBloc.add(const FormSubmitted()));
    },
  );

  testWidgets(
    'tapping Create on a fully valid form dispatches FormSubmitted and shows no '
    'error SnackBar',
    (tester) async {
      whenListen(
        formBloc,
        Stream<CreateRideFormState>.empty(),
        initialState: noPickupTimeState().copyWith(
          manualPickupDateTime: DateTime(2090, 1, 1, 10),
        ),
      );
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(mount(formKey));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.selectPickupTimeError), findsNothing);
      verify(() => formBloc.add(const FormSubmitted())).called(1);
    },
  );

  testWidgets(
    'tapping Create with empty From/To (inline validators fail) shows an error '
    'SnackBar and does not dispatch FormSubmitted',
    (tester) async {
      // Regression for the screenshot case: empty From/To made the inline
      // validators fail, and the handler used to early-return BEFORE the
      // SnackBar — so the user saw the red field labels but no toast.
      whenListen(
        formBloc,
        Stream<CreateRideFormState>.empty(),
        initialState: emptyAddressesState(),
      );
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(mountWithFailingValidator(formKey));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // let the SnackBar appear

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // First missing requirement for empty addresses is the pickup address.
      expect(find.text(l10n.enterFromAddressError), findsOneWidget);
      // The form must NOT be submitted while required fields are empty.
      verifyNever(() => formBloc.add(const FormSubmitted()));
    },
  );
}
