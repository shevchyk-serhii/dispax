import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/core/models/location.dart';
import '../blocs/blocs.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../constants/app_dimensions.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _flightNumberController = TextEditingController();
  
  DateTime _pickupDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _isAirportTransfer = false;
  bool _isArrival = false;
  String? _selectedGate;
  String? _selectedTerminal;

  final List<String> _gates = [
    'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A10',
    'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10',
    'C1', 'C2', 'C3', 'C4', 'C5',
  ];

  final List<String> _terminals = ['1', '2', '3'];

  @override
  void dispose() {
    _clientNameController.dispose();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _flightNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Ride', style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppDimensions.appBarElevation,
      ),
      body: AppTheme.buildGradientContainer(
        colors: AppColors.secretaryGradient,
        stops: const [0.0, 0.15, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BasicInfoCard(clientNameController: _clientNameController),
                const SizedBox(height: AppDimensions.paddingMedium),
                LocationCard(
                  fromAddressController: _fromAddressController,
                  toAddressController: _toAddressController,
                  onFromAddressChanged: _checkAirportTransfer,
                  onToAddressChanged: _checkAirportTransfer,
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                ScheduleCard(
                  pickupDateTime: _pickupDateTime,
                  onSelectDateTime: _selectDateTime,
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                AirportTransferCard(
                  isAirportTransfer: _isAirportTransfer,
                  isArrival: _isArrival,
                  flightNumberController: _flightNumberController,
                  selectedGate: _selectedGate,
                  selectedTerminal: _selectedTerminal,
                  gates: _gates,
                  terminals: _terminals,
                  onAirportTransferChanged: (value) {
                    setState(() {
                      _isAirportTransfer = value;
                      if (!value) {
                        _flightNumberController.clear();
                        _selectedGate = null;
                        _selectedTerminal = null;
                        _isArrival = false;
                      }
                    });
                  },
                  onArrivalChanged: (value) {
                    setState(() {
                      _isArrival = value;
                    });
                  },
                  onGateChanged: (value) {
                    setState(() {
                      _selectedGate = value;
                    });
                  },
                  onTerminalChanged: (value) {
                    setState(() {
                      _selectedTerminal = value;
                    });
                  },
                ),
                const SizedBox(height: AppDimensions.paddingLarge),
                CreateRideActionButtons(
                  onCreateRide: _createRide,
                  onClearForm: _clearForm,
                ),
                const SizedBox(height: AppDimensions.paddingXLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }






  void _checkAirportTransfer() {
    final from = _fromAddressController.text.toLowerCase();
    final to = _toAddressController.text.toLowerCase();
    
    final hasAirport = from.contains('airport') || 
                      from.contains('muc') || 
                      to.contains('airport') || 
                      to.contains('muc');
    
    if (hasAirport && !_isAirportTransfer) {
      setState(() {
        _isAirportTransfer = true;
        _isArrival = from.contains('airport') || from.contains('muc');
      });
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickupDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_pickupDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _pickupDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _createRide() {
    if (_formKey.currentState!.validate()) {
      final authState = context.read<AuthBloc>().state;
      if (!authState.isAuthenticated || authState.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create new ride object
      final newRide = Ride(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        clientId: 0, // Will be set by backend
        creatorId: authState.user!.id,
        companyId: authState.user!.companyId ?? 0,
        pickupDateTime: _pickupDateTime,
        from: Location(address: _fromAddressController.text.trim()),
        to: Location(address: _toAddressController.text.trim()),
        status: RideStatus.requested,
        clientName: _clientNameController.text.trim(),
        flightNumber: _isAirportTransfer ? _flightNumberController.text.trim() : null,
        isAirportTransfer: _isAirportTransfer,
        isArrival: _isArrival,
        gate: _selectedGate,
        terminal: _selectedTerminal,
      );

      // Dispatch create ride event
      context.read<RideBloc>().add(RideCreateRequested(ride: newRide));
    }
  }

  void _clearForm() {
    _clientNameController.clear();
    _fromAddressController.clear();
    _toAddressController.clear();
    _flightNumberController.clear();
    
    setState(() {
      _pickupDateTime = DateTime.now().add(const Duration(hours: 1));
      _isAirportTransfer = false;
      _isArrival = false;
      _selectedGate = null;
      _selectedTerminal = null;
    });
  }
}