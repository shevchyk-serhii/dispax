import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/core/services/location_service.dart';
import '../modules/core/services/api_client.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/flight_management/widgets/widgets.dart';
import '../modules/core/widgets/widgets.dart';

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

      final response = await _apiClient.patch('/rides/${widget.ride.id}/flight-confirmation', {
        'arrived': true,
        'arrivalTime': DateTime.now().toIso8601String(),
        'clientLocation': finalLocation,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      });

      if (response.statusCode == 200) {

        if (context.mounted) {
          context.read<RideBloc>().add(RideStatusUpdateRequested(
            rideId: widget.ride.id,
            status: RideStatus.inProgress,
          ));

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

    final delay = await showDialog<int>(
      context: context,
      builder: (context) => const DelayPickupDialog(),
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
                FlightInfoCard(ride: widget.ride),

                const SizedBox(height: AppDimensions.paddingLarge),

                LocationSelectionCard(
                  selectedLocation: _selectedLocation,
                  customLocationController: _customLocationController,
                  onLocationSelected: (location) {
                    setState(() {
                      _selectedLocation = location;
                    });
                  },
                  locationOptions: _commonAirportLocations,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppDimensions.paddingMedium),
                  ErrorMessageWidget(message: _errorMessage!),
                ],

                const SizedBox(height: AppDimensions.paddingXLarge),

                FlightActionButtons(
                  isLoading: _isLoading,
                  onConfirmArrival: _confirmArrival,
                  onDelayPickup: _delayPickup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
