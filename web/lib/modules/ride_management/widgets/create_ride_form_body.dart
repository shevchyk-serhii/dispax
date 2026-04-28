import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';
import 'sections/create_ride_form_sections.dart';

class CreateRideFormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const CreateRideFormBody({
    super.key,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.secretaryGradient,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: CreateRideFormSections(formKey: formKey),
        ),
      ),
    );
  }
}
