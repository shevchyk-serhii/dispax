import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../ride_management/models/ride.dart';
import '../../core/services/location_clarification_service.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/services/error_messages.dart';

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

  @override
  void dispose() {
    _locationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _updateLocation(AppLocalizations l10n) async {
    final location = _selectedQuickLocation.isNotEmpty
        ? _selectedQuickLocation
        : _locationController.text.trim();

    if (location.isEmpty) {
      setState(() {
        _errorMessage = l10n.specifyLocationError;
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
          _errorMessage = l10n.failedToUpdateLocationError;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e, l10n);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorMessage = _errorMessage;
    final quickLocations = [
      l10n.locationQuickMainEntrance,
      l10n.locationQuickBaggageClaim,
      l10n.locationQuickCafe,
      l10n.locationQuickParking,
      l10n.locationQuickInformationDesk,
      l10n.locationQuickSecondFloor,
      l10n.locationQuickExit1,
      l10n.locationQuickExit2,
      l10n.locationQuickOther,
    ];

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
              l10n.updateLocationTitle,
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
              l10n.tellDriverWhereYouAreLabel,
              style: AppStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            Text(
              l10n.quickSelectLabel,
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            Wrap(
              spacing: AppDimensions.paddingSmall,
              runSpacing: AppDimensions.paddingSmall,
              children: quickLocations
                  .map((location) => _buildQuickLocationChip(location, l10n))
                  .toList(),
            ),

            const SizedBox(height: AppDimensions.paddingLarge),

            Text(
              l10n.orSpecifyExactlyLabel,
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: l10n.locationExampleHint,
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
              l10n.additionalInstructionsLabel,
              style: AppStyles.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingSmall),

            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: l10n.additionalInstructionsExampleHint,
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

            if (errorMessage != null) ...[
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
                        errorMessage,
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
            l10n.cancel,
            style: AppStyles.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _updateLocation(l10n),
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
              : Text(l10n.send),
        ),
      ],
    );
  }

  Widget _buildQuickLocationChip(String location, AppLocalizations l10n) {
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
            if (location != l10n.locationQuickOther) {
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
  return showAdaptiveDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => LocationClarificationDialog(ride: ride),
  );
}
