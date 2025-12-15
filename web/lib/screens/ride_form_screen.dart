import 'package:flutter/material.dart';
import '../../modules/ride_management/models/ride.dart';
import '../modules/core/models/location.dart';
import '../modules/ride_management/services/mock_ride_service.dart';
import '../modules/ride_management/widgets/location_field.dart';
import '../modules/ride_management/widgets/date_time_picker.dart';

class RideFormScreen extends StatefulWidget {
  final Ride? ride;

  const RideFormScreen({super.key, this.ride});

  @override
  State<RideFormScreen> createState() => _RideFormScreenState();
}

class _RideFormScreenState extends State<RideFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final MockRideService _rideService = MockRideService();

  late TextEditingController _fromAddressController;
  late TextEditingController _toAddressController;

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final ride = widget.ride;
    _fromAddressController = TextEditingController(
      text: ride?.from.address ?? '',
    );
    _toAddressController = TextEditingController(text: ride?.to.address ?? '');

    _selectedDateTime =
        ride?.pickupDateTime ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _rideService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ride == null ? 'Новая поездка' : 'Редактировать поездку',
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Откуда',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LocationField(
                        controller: _fromAddressController,
                        hint: 'Адрес отправления',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Куда',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LocationField(
                        controller: _toAddressController,
                        hint: 'Адрес назначения',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Время поездки',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DateTimePicker(
                        selectedDateTime: _selectedDateTime,
                        onDateTimeSelected: (dateTime) {
                          setState(() {
                            _selectedDateTime = dateTime;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Маршрут на карте',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('Map functionality temporarily disabled'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRide,
                  child: Text(
                    widget.ride == null
                        ? 'Создать поездку'
                        : 'Сохранить изменения',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRide() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите время поездки')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final from = Location(address: _fromAddressController.text);

      final to = Location(address: _toAddressController.text);

      final ride = Ride(
        id: widget.ride?.id ?? 0,
        clientId: widget.ride?.clientId ?? 2,
        creatorId: widget.ride?.creatorId ?? 3,
        driverId: widget.ride?.driverId,
        companyId: widget.ride?.companyId ?? 1,
        scheduleDayId: widget.ride?.scheduleDayId,
        pickupDateTime: _selectedDateTime!,
        from: from,
        to: to,
        status: widget.ride?.status ?? RideStatus.requested,
        clientName: widget.ride?.clientName ?? 'Unknown Client',
      );

      if (widget.ride == null) {
        await _rideService.createRide(ride);
      } else {
        await _rideService.updateRide(widget.ride!.id, ride);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
