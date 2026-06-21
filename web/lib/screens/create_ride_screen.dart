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
