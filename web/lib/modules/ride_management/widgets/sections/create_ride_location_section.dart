import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../address_autocomplete_field.dart';
import '../../models/client_address.dart';
import '../../services/client_address_service.dart';
import '../../../core/services/api_client.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../../../../theme/app_theme.dart';

class CreateRideLocationSection extends StatefulWidget {
  final String fromAddress;
  final String toAddress;

  const CreateRideLocationSection({
    super.key,
    required this.fromAddress,
    required this.toAddress,
  });

  @override
  State<CreateRideLocationSection> createState() => _CreateRideLocationSectionState();
}

class _CreateRideLocationSectionState extends State<CreateRideLocationSection> {
  late final ClientAddressService _addressService;
  List<ClientAddress> _savedAddresses = [];
  String? _loadedForClientId;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthBloc>().apiClient;
    _addressService = ClientAddressService(apiClient: apiClient);
  }

  @override
  void dispose() {
    _addressService.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses(String clientId) async {
    if (_loadedForClientId == clientId) return;
    _loadedForClientId = clientId;
    try {
      final addresses = await _addressService.getAddresses(clientId);
      if (mounted) setState(() => _savedAddresses = addresses);
    } catch (_) {
      _loadedForClientId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateRideFormBloc, CreateRideFormState>(
      listenWhen: (prev, curr) => prev.selectedClientId != curr.selectedClientId,
      listener: (context, state) {
        if (state.selectedClientId != null) {
          _loadAddresses(state.selectedClientId!);
        } else {
          setState(() {
            _savedAddresses = [];
            _loadedForClientId = null;
          });
        }
      },
      child: Container(
        decoration: AppTheme.cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green[600], size: 24),
                  const SizedBox(width: AppDimensions.paddingSmall),
                  const Text(
                    'Ride Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              AddressAutocompleteField(
                labelText: 'From',
                hintText: 'Pick-up location',
                prefixIconData: Icons.trip_origin,
                initialValue: widget.fromAddress,
                suggestions: _savedAddresses,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Pick-up location is required';
                  return null;
                },
                onChanged: (value) {
                  context.read<CreateRideFormBloc>().add(FromAddressChanged(value));
                },
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              AddressAutocompleteField(
                labelText: 'To',
                hintText: 'Drop-off location',
                prefixIconData: Icons.location_on,
                initialValue: widget.toAddress,
                suggestions: _savedAddresses,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Drop-off location is required';
                  return null;
                },
                onChanged: (value) {
                  context.read<CreateRideFormBloc>().add(ToAddressChanged(value));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
