import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../blocs/blocs.dart';
import '../utils/navigation_helper.dart';

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
        title: const Text('Create New Ride'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade600, Colors.grey.shade50],
            stops: const [0.0, 0.15],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBasicInfoCard(),
                const SizedBox(height: 16),
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildScheduleCard(),
                const SizedBox(height: 16),
                _buildAirportTransferCard(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.purple[600], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Client Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'Client Name *',
                hintText: 'Enter client full name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
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

  Widget _buildLocationCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.purple[600], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Route Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromAddressController,
              decoration: const InputDecoration(
                labelText: 'Pickup Address *',
                hintText: 'Enter pickup location',
                prefixIcon: Icon(Icons.trip_origin),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pickup address is required';
                }
                return null;
              },
              onChanged: (value) {
                _checkAirportTransfer();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _toAddressController,
              decoration: const InputDecoration(
                labelText: 'Destination Address *',
                hintText: 'Enter destination location',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Destination address is required';
                }
                return null;
              },
              onChanged: (value) {
                _checkAirportTransfer();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple[600], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pickup Date & Time *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy - HH:mm').format(_pickupDateTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirportTransferCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight, color: Colors.purple[600], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Airport Transfer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Airport Transfer'),
              subtitle: const Text('Enable if this is an airport pickup/drop-off'),
              value: _isAirportTransfer,
              onChanged: (value) {
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
            ),
            if (_isAirportTransfer) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Departure ✈️↑'),
                      subtitle: const Text('To airport'),
                      value: false,
                      groupValue: _isArrival,
                      onChanged: (value) {
                        setState(() {
                          _isArrival = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Arrival ✈️↓'),
                      subtitle: const Text('From airport'),
                      value: true,
                      groupValue: _isArrival,
                      onChanged: (value) {
                        setState(() {
                          _isArrival = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _flightNumberController,
                decoration: const InputDecoration(
                  labelText: 'Flight Number',
                  hintText: 'e.g. LH123, BA456',
                  prefixIcon: Icon(Icons.flight_takeoff),
                  border: OutlineInputBorder(),
                ),
                validator: _isAirportTransfer ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Flight number is required for airport transfers';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Gate',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedGate,
                      items: _gates.map((gate) => DropdownMenuItem(
                        value: gate,
                        child: Text('Gate $gate'),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGate = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Terminal',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedTerminal,
                      items: _terminals.map((terminal) => DropdownMenuItem(
                        value: terminal,
                        child: Text('Terminal $terminal'),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTerminal = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return BlocConsumer<RideBloc, RideState>(
      listener: (context, state) {
        if (state.hasError) {
          NavigationHelper.showSnackBar(
            context,
            state.errorMessage!,
            isError: true,
          );
        } else if (state.status == RideStateStatus.loaded && !state.isLoading) {
          // Ride was successfully created, check if we just added a new ride
          NavigationHelper.showSnackBar(
            context,
            'Ride created successfully!',
            isError: false,
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _createRide,
                icon: state.isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline),
                label: Text(state.isLoading ? 'Creating Ride...' : 'Create Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Form'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
        NavigationHelper.showSnackBar(
          context,
          'Authentication required',
          isError: true,
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