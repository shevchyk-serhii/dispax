import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/models/user_requests.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/ride_management/models/payment_method.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../screens/create_ride_screen.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_styles.dart';
import '../../../modules/core/services/error_messages.dart';
import '../../superadmin/widgets/billing_widgets.dart' show fmtEur;

class ClientDetailScreen extends StatefulWidget {
  final Person client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Ride>? _rides;
  bool _isLoading = true;
  Object? _error;
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
      // The screen may have been popped while the request was in flight —
      // calling setState on a disposed State crashes.
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _client.name,
          style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: AppDimensions.appBarElevation,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'client_detail_action',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        // Override the global theme's CircleBorder: an extended FAB is a pill,
        // and a circle clip would cut off both the icon and the label.
        shape: const StadiumBorder(),
        onPressed: () async {
          final rideBloc = context.read<RideBloc>();
          final authBloc = context.read<AuthBloc>();
          // Preselect this client so the secretary doesn't have to search for
          // and re-pick the very client whose detail screen they came from.
          final formBloc = CreateRideFormBloc()
            ..add(
              ClientPreselected(clientId: _client.id, clientName: _client.name),
            );
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CreateRideScreen(rideBloc: rideBloc, formBloc: formBloc),
            ),
          );
          await formBloc.close();
          final user = authBloc.state.user;
          if (user != null) rideBloc.add(RideLoadRequested(user: user));
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.newRideButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _client.isVip
                ? AppColors.warningBorder
                : AppColors.secretaryColor.withAlpha(30),
            child: _client.isVip
                ? const Icon(Icons.star, color: AppColors.warning, size: 28)
                : Text(
                    _client.name.isNotEmpty
                        ? _client.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
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
                      child: Text(
                        _client.name,
                        style: AppStyles.titleMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_client.isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningBorder,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _client.email,
                  style: AppStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_client.phone case final phone? when phone.isNotEmpty)
                  Text(
                    phone,
                    style: AppStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (_client.preferredDriverId != null)
                  Text(
                    l10n.preferredDriverAssigned,
                    style: AppStyles.bodySmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
          if (_rides case final rides?)
            Column(
              children: [
                Text(
                  '${rides.length}',
                  style: AppStyles.headlineMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(l10n.ridesCountLabel, style: AppStyles.labelSmall),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRideHistory() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    final error = _error == null ? null : friendlyError(_error, l10n);
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              error,
              style: AppStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadRides, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    final rides = _rides;
    if (rides == null || rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noRidesYet,
              style: AppStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          return _buildRideCard(rides[index]);
        },
      ),
    );
  }

  Widget _buildRideCard(Ride ride) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = RideStatusStyles.getStatusColor(ride.status);
    final driverName = ride.driverName;
    final price = ride.price;
    final paymentLabel = PaymentMethod.labelForWire(ride.paymentMethod, l10n);
    final flightNumber = ride.flightNumber;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // ClipRRect provides the rounded corners; the inner Container keeps the
      // left accent border. A borderRadius cannot be combined with a Border
      // that has non-uniform side colors, so we split the two responsibilities.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withAlpha(100)),
                    ),
                    child: Text(
                      ride.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ride.from.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ride.to.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (driverName != null || price != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (driverName != null)
                      Text(
                        l10n.driverLabel(driverName),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (price != null)
                      Text(
                        fmtEur(price),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              ],
              if (paymentLabel != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paymentLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              if (ride.isAirportTransfer && flightNumber != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      ride.isArrival ? Icons.flight_land : Icons.flight_takeoff,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      flightNumber,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: _client.name);
    final emailController = TextEditingController(text: _client.email);
    final phoneController = TextEditingController(text: _client.phone ?? '');
    bool isVip = _client.isVip;
    final formKey = GlobalKey<FormState>();

    final apiClient = context.read<AuthBloc>().apiClient;
    final userService = UserService(apiClient: apiClient);
    final messenger = ScaffoldMessenger.of(context);

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.editClientTitle),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.name,
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? l10n.nameRequired
                            : null,
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: const Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.emailRequired;
                          }
                          if (!v.contains('@')) return l10n.invalidEmail;
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: l10n.phoneOptional,
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      SwitchListTile(
                        title: Text(l10n.vipClientLabel),
                        subtitle: Text(l10n.vipClientHelpText),
                        secondary: Icon(
                          Icons.star,
                          color: isVip
                              ? AppColors.warning
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secretaryColor,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    try {
                      final updated = await userService.updateClient(
                        _client.id,
                        UpdateUserRequest(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          phone: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          isVip: isVip,
                        ),
                      );
                      // Guard against the screen being disposed while the
                      // request was in flight (setState-after-dispose crash).
                      if (mounted) setState(() => _client = updated);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.clientUpdatedSuccess)),
                      );
                    } catch (e) {
                      // Keep the dialog open and surface the failure instead of
                      // silently dropping it (the user must know it failed).
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.clientUpdateFailed),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
