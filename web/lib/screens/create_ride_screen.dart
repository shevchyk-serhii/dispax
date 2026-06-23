import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../modules/ride_management/helpers/create_ride_form_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class CreateRideScreen extends StatelessWidget {
  final RideBloc rideBloc;
  final VoidCallback? onCreated;
  final CreateRideFormBloc? formBloc;

  const CreateRideScreen({
    super.key,
    required this.rideBloc,
    this.onCreated,
    this.formBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        formBloc != null
            ? BlocProvider.value(value: formBloc!)
            : BlocProvider(create: (_) => CreateRideFormBloc()),
        BlocProvider.value(value: rideBloc),
      ],
      child: CreateRideScreenContent(onCreated: onCreated),
    );
  }
}

class CreateRideScreenContent extends StatefulWidget {
  final VoidCallback? onCreated;

  const CreateRideScreenContent({super.key, this.onCreated});

  @override
  State<CreateRideScreenContent> createState() =>
      _CreateRideScreenContentState();
}

class _CreateRideScreenContentState extends State<CreateRideScreenContent> {
  final _formKey = GlobalKey<FormState>();

  /// Shown after a driver created a ride with "Assign to me" on, but the
  /// self-assignment hit a schedule conflict. The ride already exists in the
  /// pool; the driver can assign anyway (override) or leave it for the
  /// dispatcher.
  void _showCreateSelfAssignConflictDialog(
    BuildContext context, {
    required String rideId,
    required String driverId,
    String? message,
  }) {
    final rideBloc = context.read<RideBloc>();
    showAdaptiveDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Schedule conflict'),
        content: Text(
          message != null
              ? '$message\n\nThe ride was created and is in the dispatcher pool. '
                    'Assign it to yourself anyway?'
              : 'You already have a ride around this time. The ride was created '
                    'and is in the dispatcher pool. Assign it to yourself anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Keep in pool'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              rideBloc.add(
                RideAssignRequested(
                  rideId: rideId,
                  driverId: driverId,
                  overrideScheduleConflict: true,
                ),
              );
            },
            child: const Text('Assign anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CreateRideFormBloc, CreateRideFormState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == CreateRideFormStatus.submitting) {
              CreateRideFormHelper.handleFormSubmission(context, state);
            }
          },
        ),
        BlocListener<RideBloc, RideState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == RideStateStatus.created) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ride created successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              // The ride is persisted, so reset the form: the submit button
              // re-enables and no stale data triggers the "Discard changes?"
              // dialog next time. Without this the shared CreateRideFormBloc
              // stays in `submitting` forever — the button is stuck on
              // "Creating Ride..." — because the success branch (unlike the
              // error branch) never clears the status.
              context.read<CreateRideFormBloc>().add(const FormCleared());
              if (widget.onCreated != null) {
                widget.onCreated!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            } else if (state.status == RideStateStatus.assignConflict &&
                state.hasAssignConflict) {
              // The ride was created into the pool, but the driver's opt-in
              // "Assign to me" hit a schedule conflict so it came back
              // unassigned. The ride is NOT lost — offer to assign anyway
              // (override) or leave it in the pool for the dispatcher.
              _showCreateSelfAssignConflictDialog(
                context,
                rideId: state.conflictRideId!,
                driverId: state.conflictDriverId!,
                message: state.errorMessage,
              );
              if (widget.onCreated != null) {
                widget.onCreated!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            } else if (state.status == RideStateStatus.error) {
              // Leave the submitting state so the "Create Ride" button
              // re-enables and the user can fix the field and retry.
              context.read<CreateRideFormBloc>().add(const SubmissionFailed());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Failed to create ride'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () =>
                        context.read<CreateRideFormBloc>().add(FormSubmitted()),
                  ),
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Create New Ride',
            style: AppStyles.titleLarge.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
          backgroundColor: AppColors.secretaryColor,
          foregroundColor: AppColors.textOnPrimary,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: AppDimensions.appBarElevation,
        ),
        body: CreateRideFormBody(formKey: _formKey),
      ),
    );
  }
}
