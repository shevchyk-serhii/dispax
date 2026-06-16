import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../core/services/location_clarification_service.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class LocationClarificationDialog extends StatefulWidget {
  final Ride ride;

  const LocationClarificationDialog({super.key, required this.ride});

  @override
  State<LocationClarificationDialog> createState() =>
      _LocationClarificationDialogState();
}

class _LocationClarificationDialogState
    extends State<LocationClarificationDialog> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final LocationClarificationService _service =
      LocationClarificationService.instance;

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedQuickLocation = '';

  final List<String> _quickLocations = [
    'At main entrance',
    'At baggage claim',
    'At cafe',
    'At parking',
    'At information desk',
    'On second floor',
    'At exit #1',
    'At exit #2',
    'Other location',
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _updateLocation() async {
    final location = _selectedQuickLocation.isNotEmpty
        ? _selectedQuickLocation
        : _locationController.text.trim();

    if (location.isEmpty) {
      setState(() {
        _errorMessage = 'Please specify your location';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _service.updateClientLocation(
        rideId: widget.ride.id.toString(),
        newLocation: location,
        additionalInstructions: _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to update location. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Icon(
            Icons.my_location,
            color: Theme.of(context).colorScheme.primary,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              'Update Location',
              style: AppStyles.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell the driver where you are now:',
              style: AppStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            Text(
              'Quick select:',
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            Wrap(
              spacing: AppDimensions.paddingSmall,
              runSpacing: AppDimensions.paddingSmall,
              children: _quickLocations
                  .map((location) => _buildQuickLocationChip(location))
                  .toList(),
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            Text(
              'Or specify exactly:',
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Example: "At Terminal A entrance"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                contentPadding: const EdgeInsets.all(
                  AppDimensions.paddingMedium,
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            Text(
              'Additional instructions (optional):',
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'Example: "Standing near the coffee shop"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                contentPadding: const EdgeInsets.all(
                  AppDimensions.paddingMedium,
                ),
              ),
              maxLines: 3,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(50),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: AppColors.error,
                      size: AppDimensions.iconSmall,
                    ),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppStyles.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Widget _buildQuickLocationChip(String location) {
    final isSelected = _selectedQuickLocation == location;

    return FilterChip(
      label: Text(
        location,
        style: AppStyles.labelSmall.copyWith(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedQuickLocation = location;
            if (location != 'Other location') {
              _locationController.clear();
            }
          } else {
            _selectedQuickLocation = '';
          }
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
      ),
    );
  }
}

Future<bool?> showLocationClarificationDialog({
  required BuildContext context,
  required Ride ride,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => LocationClarificationDialog(ride: ride),
  );
}
