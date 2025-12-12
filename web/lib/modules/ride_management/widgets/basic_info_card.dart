import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';

class BasicInfoCard extends StatelessWidget {
  final TextEditingController clientNameController;
  final String? Function(String?)? validator;

  const BasicInfoCard({
    Key? key,
    required this.clientNameController,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.secretaryColor, size: AppDimensions.iconLarge),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  'Client Information',
                  style: AppStyles.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              controller: clientNameController,
              decoration: InputDecoration(
                labelText: 'Client Name *',
                hintText: 'Enter client full name',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.secretaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              validator: validator ?? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client name is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}