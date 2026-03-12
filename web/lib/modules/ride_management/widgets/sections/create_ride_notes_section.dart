import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../../../../theme/app_theme.dart';

class CreateRideNotesSection extends StatelessWidget {
  final String notes;
  final List<String> specialRequirements;

  static const List<String> availableRequirements = [
    'Wheelchair',
    'Child Seat',
    'Extra Luggage',
    'Meet & Greet',
    'VIP',
  ];

  const CreateRideNotesSection({
    super.key,
    required this.notes,
    required this.specialRequirements,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_alt, color: AppColors.secretaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Notes & Special Requirements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          TextFormField(
            initialValue: notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Any special instructions...',
            ),
            maxLines: 3,
            onChanged: (value) {
              context.read<CreateRideFormBloc>().add(NotesChanged(value));
            },
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          const Text(
            'Special Requirements',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppDimensions.paddingSmall),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableRequirements.map((req) {
              final isSelected = specialRequirements.contains(req);
              return FilterChip(
                label: Text(req),
                selected: isSelected,
                onSelected: (_) {
                  context.read<CreateRideFormBloc>().add(SpecialRequirementToggled(req));
                },
                selectedColor: AppColors.secretaryColor.withAlpha(40),
                checkmarkColor: AppColors.secretaryColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
