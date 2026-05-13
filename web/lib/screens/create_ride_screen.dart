import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../modules/ride_management/helpers/create_ride_form_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class CreateRideScreen extends StatelessWidget {
  final RideBloc rideBloc;

  const CreateRideScreen({super.key, required this.rideBloc});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CreateRideFormBloc()),
        BlocProvider.value(value: rideBloc),
      ],
      child: const CreateRideScreenContent(),
    );
  }
}

class CreateRideScreenContent extends StatefulWidget {
  const CreateRideScreenContent({super.key});

  @override
  State<CreateRideScreenContent> createState() => _CreateRideScreenContentState();
}

class _CreateRideScreenContentState extends State<CreateRideScreenContent> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateRideFormBloc, CreateRideFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CreateRideFormStatus.submitting) {
          CreateRideFormHelper.handleFormSubmission(context, state);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Create New Ride',
            style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary),
          ),
          backgroundColor: AppColors.secretaryColor,
          foregroundColor: AppColors.textOnPrimary,
          elevation: AppDimensions.appBarElevation,
        ),
        body: CreateRideFormBody(formKey: _formKey),
      ),
    );
  }
}
