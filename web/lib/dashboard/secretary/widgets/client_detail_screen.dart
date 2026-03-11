import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/models/user_requests.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../screens/create_ride_screen.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';

class ClientDetailScreen extends StatefulWidget {
  final Person client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Ride>? _rides;
  bool _isLoading = true;
  String? _error;
  late Person _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final rideService = RideService(apiClient: apiClient);
      final rides = await rideService.getClientRides(_client.id);
      rides.sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client.name, style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppDimensions.appBarElevation,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secretaryColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateRideScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Ride'),
      ),
      body: Column(
        children: [
          _buildClientInfo(),
          const Divider(height: 1),
          Expanded(child: _buildRideHistory()),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      color: AppColors.surface,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _client.isVip
                ? Colors.amber.shade100
                : AppColors.secretaryColor.withAlpha(30),
            child: _client.isVip
                ? const Icon(Icons.star, color: Colors.amber, size: 28)
                : Text(
                    _client.name.isNotEmpty ? _client.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.secretaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_client.name, style: AppStyles.titleMedium),
                    ),
                    if (_client.isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(_client.email, style: AppStyles.bodySmall),
                if (_client.phone != null && _client.phone!.isNotEmpty)
                  Text(_client.phone!, style: AppStyles.bodySmall),
                if (_client.preferredDriverId != null)
                  Text(
                    'Preferred driver assigned',
                    style: AppStyles.bodySmall.copyWith(color: AppColors.success),
                  ),
              ],
            ),
          ),
          if (_rides != null)
            Column(
              children: [
                Text(
                  '${_rides!.length}',
                  style: AppStyles.headlineMedium.copyWith(color: AppColors.secretaryColor),
                ),
                Text('rides', style: AppStyles.labelSmall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRideHistory() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: AppStyles.bodyMedium),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadRides, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_rides == null || _rides!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No rides yet', style: AppStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        itemCount: _rides!.length,
        itemBuilder: (context, index) {
          return _buildRideCard(_rides![index]);
        },
      ),
    );
  }

  Widget _buildRideCard(Ride ride) {
    final statusColor = _getStatusColor(ride.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(ride.pickupDateTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    ride.statusDisplayName,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.green.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ride.from.address,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.red.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ride.to.address,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (ride.driverName != null || ride.price != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ride.driverName != null)
                    Text(
                      'Driver: ${ride.driverName}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  if (ride.price != null)
                    Text(
                      '\u20AC${ride.price!.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                ],
              ),
            ],
            if (ride.isAirportTransfer && ride.flightNumber != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(ride.isArrival ? Icons.flight_land : Icons.flight_takeoff,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    ride.flightNumber!,
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequested;
      case RideStatus.assigned:
        return AppColors.rideAssigned;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
    }
  }

  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: _client.name);
    final emailController = TextEditingController(text: _client.email);
    final phoneController = TextEditingController(text: _client.phone ?? '');
    bool isVip = _client.isVip;
    final formKey = GlobalKey<FormState>();

    // Get available drivers for preferred driver selection
    final apiClient = context.read<AuthBloc>().apiClient;
    final userService = UserService(apiClient: apiClient);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Client'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      SwitchListTile(
                        title: const Text('VIP Client'),
                        subtitle: const Text('Priority service and preferred driver'),
                        secondary: Icon(
                          Icons.star,
                          color: isVip ? Colors.amber : Colors.grey,
                        ),
                        value: isVip,
                        onChanged: (v) => setDialogState(() => isVip = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secretaryColor),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      userService.updateClient(
                        _client.id,
                        UpdateUserRequest(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          phone: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          isVip: isVip,
                        ),
                      ).then((updated) {
                        setState(() => _client = updated);
                      });
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
