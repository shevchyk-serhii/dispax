import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../blocs/blocs.dart';
import '../models/ride.dart';
import '../services/location_service.dart';
import '../services/api_client.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';

class FlightConfirmationScreen extends StatefulWidget {
  final Ride ride;

  const FlightConfirmationScreen({
    super.key,
    required this.ride,
  });

  @override
  State<FlightConfirmationScreen> createState() => _FlightConfirmationScreenState();
}

class _FlightConfirmationScreenState extends State<FlightConfirmationScreen> {
  final ApiClient _apiClient = ApiClient();
  final LocationService _locationService = LocationService.instance;
  
  bool _isLoading = false;
  String? _errorMessage;
  geo.Position? _currentPosition;
  String _selectedLocation = '';
  final TextEditingController _customLocationController = TextEditingController();
  
  final List<String> _commonAirportLocations = [
    'Baggage Claim',
    'Arrivals Hall',
    'Arrivals Cafe',
    'Terminal Exit',
    'Parking P1',
    'Parking P2',
    'Bus Stop',
    'Other location (specify below)',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _customLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _confirmArrival() async {
    if (_selectedLocation.isEmpty) {
      setState(() {
        _errorMessage = 'Please select your location';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String finalLocation = _selectedLocation;
      if (_selectedLocation == 'Other location (specify below)') {
        if (_customLocationController.text.trim().isEmpty) {
          throw Exception('Please specify your location');
        }
        finalLocation = _customLocationController.text.trim();
      }

      // Send flight confirmation
      final response = await _apiClient.patch('/rides/${widget.ride.id}/flight-confirmation', {
        'arrived': true,
        'arrivalTime': DateTime.now().toIso8601String(),
        'clientLocation': finalLocation,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      if (response.statusCode == 200) {
        // Update ride status
        if (context.mounted) {
          context.read<RideBloc>().add(RideStatusUpdateRequested(
            rideId: widget.ride.id,
            status: RideStatus.inProgress,
          ));

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your driver has been notified of your arrival'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );

          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Confirmation error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _delayPickup() async {
    // Show dialog for delay time selection
    final delay = await showDialog<int>(
      context: context,
      builder: (context) => const _DelayPickupDialog(),
    );

    if (delay != null && delay > 0) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final response = await _apiClient.patch('/rides/${widget.ride.id}/delay-pickup', {
          'delayMinutes': delay,
          'reason': 'Client requested pickup delay',
        });

        if (response.statusCode == 200) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pickup delayed by $delay minutes'),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(false);
          }
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Delay error: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Flight Confirmation'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFlightInfoCard(),
                
                const SizedBox(height: AppDimensions.paddingLarge),
                
                _buildLocationSelection(),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppDimensions.paddingMedium),
                  _buildErrorMessage(),
                ],
                
                const SizedBox(height: AppDimensions.paddingXLarge),
                
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlightInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight_land,
                color: AppColors.primary,
                size: AppDimensions.iconLarge,
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flight ${widget.ride.flightNumber}',
                      style: AppStyles.titleLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    Text(
                      'Terminal ${widget.ride.terminal} • Gate ${widget.ride.gate}',
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppDimensions.paddingMedium),
          
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(150),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withAlpha(100),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Scheduled pickup:',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        AppDateUtils.formatDateTime(widget.ride.pickupDateTime),
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppDimensions.paddingSmall),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Driver:',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        widget.ride.driverName ?? 'Not assigned',
                        style: AppStyles.bodyMedium.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where are you now?',
            style: AppStyles.titleMedium.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
          
          const SizedBox(height: AppDimensions.paddingMedium),
          
          Text(
            'Select your current location so the driver can easily find you',
            style: AppStyles.bodyMedium.copyWith(
              color: AppColors.textOnPrimary.withAlpha(180),
            ),
          ),
          
          const SizedBox(height: AppDimensions.paddingLarge),
          
          ..._commonAirportLocations.map((location) => _buildLocationOption(location)),
          
          if (_selectedLocation == 'Other location (specify below)') ...[
            const SizedBox(height: AppDimensions.paddingMedium),
            TextField(
              controller: _customLocationController,
              decoration: InputDecoration(
                hintText: 'Specify your location',
                filled: true,
                fillColor: AppColors.surface.withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                hintStyle: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textOnPrimary.withAlpha(128),
                ),
              ),
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.textOnPrimary,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationOption(String location) {
    final isSelected = _selectedLocation == location;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLocation = location;
          });
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.clientColor.withAlpha(100)
                : AppColors.surface.withAlpha(50),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isSelected 
                  ? AppColors.clientColor
                  : AppColors.textOnPrimary.withAlpha(50),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected 
                    ? AppColors.clientColor 
                    : AppColors.textOnPrimary.withAlpha(128),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Text(
                  location,
                  style: AppStyles.bodyMedium.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(50),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: AppColors.error,
          width: 1,
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
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmArrival,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingLarge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    Text(
                      'Confirm Arrival',
                      style: AppStyles.labelLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ],
                ),
        ),
        
        const SizedBox(height: AppDimensions.paddingMedium),
        
        OutlinedButton(
          onPressed: _isLoading ? null : _delayPickup,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
            side: BorderSide(
              color: AppColors.textOnPrimary.withAlpha(100),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingLarge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule),
              const SizedBox(width: AppDimensions.paddingSmall),
              Text(
                'Delay Pickup',
                style: AppStyles.labelLarge.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DelayPickupDialog extends StatefulWidget {
  const _DelayPickupDialog();
  
  @override
  State<_DelayPickupDialog> createState() => _DelayPickupDialogState();
}

class _DelayPickupDialogState extends State<_DelayPickupDialog> {
  int _selectedDelay = 15;
  final List<int> _delayOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Delay by how long?',
        style: AppStyles.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _delayOptions.map((delay) => RadioListTile<int>(
          title: Text(
            '$delay minutes',
            style: AppStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          value: delay,
          groupValue: _selectedDelay,
          onChanged: (value) {
            setState(() {
              _selectedDelay = value!;
            });
          },
          activeColor: AppColors.clientColor,
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppStyles.labelMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedDelay),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}