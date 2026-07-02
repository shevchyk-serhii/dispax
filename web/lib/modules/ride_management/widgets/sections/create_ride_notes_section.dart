import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../clearable_text_field.dart';
import '../tag_input_field.dart';

class CreateRideNotesSection extends StatelessWidget {
  final String notes;
  final List<String> specialRequirements;
  final List<String> tags;

  /// Previously-used tags offered as quick-add chips in the tag editor.
  final List<String> tagSuggestions;

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
    this.tags = const [],
    this.tagSuggestions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_alt,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Notes & Special Requirements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          ClearableTextField(
            value: notes,
            labelText: 'Notes',
            hintText: 'Any special instructions...',
            maxLines: 3,
            minLines: 3,
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
                  context.read<CreateRideFormBloc>().add(
                    SpecialRequirementToggled(req),
                  );
                },
                selectedColor: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha(40),
                checkmarkColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          TagInputField(
            tags: tags,
            suggestions: tagSuggestions,
            onAdded: (tag) =>
                context.read<CreateRideFormBloc>().add(TagAdded(tag)),
            onRemoved: (tag) =>
                context.read<CreateRideFormBloc>().add(TagRemoved(tag)),
          ),
        ],
      ),
    );
  }
}
