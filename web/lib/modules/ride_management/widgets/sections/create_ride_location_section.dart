import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../address_autocomplete_field.dart';
import '../../models/client_address.dart';
import '../../services/client_address_service.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

class CreateRideLocationSection extends StatefulWidget {
  const CreateRideLocationSection({super.key});

  @override
  State<CreateRideLocationSection> createState() =>
      _CreateRideLocationSectionState();
}

class _CreateRideLocationSectionState extends State<CreateRideLocationSection> {
  late final ClientAddressService _addressService;
  late final CreateRideFormBloc _formBloc;
  late final StreamSubscription<CreateRideFormState> _subscription;
  List<ClientAddress> _savedAddresses = [];
  String? _loadedForClientId;

  @override
  void initState() {
    super.initState();
    _formBloc = context.read<CreateRideFormBloc>();
    _addressService = ClientAddressService(
      apiClient: context.read<AuthBloc>().apiClient,
    );

    final currentClientId = _formBloc.state.selectedClientId;
    if (currentClientId != null) {
      _loadAddresses(currentClientId);
    }

    _subscription = _formBloc.stream.listen((state) {
      if (!mounted) return;
      final clientId = state.selectedClientId;
      if (clientId == null) {
        setState(() {
          _savedAddresses = [];
          _loadedForClientId = null;
        });
      } else if (clientId != _loadedForClientId) {
        _loadAddresses(clientId);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _addressService.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses(String clientId) async {
    _loadedForClientId = clientId;
    try {
      final addresses = await _addressService.getAddresses(clientId);
      if (mounted && _loadedForClientId == clientId) {
        setState(() => _savedAddresses = addresses);
      }
    } catch (_) {
      _loadedForClientId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      buildWhen: (prev, curr) =>
          prev.fromAddress != curr.fromAddress ||
          prev.toAddress != curr.toAddress,
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.successStrong,
                      size: 24,
                    ),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    const Text(
                      'Ride Locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                AddressAutocompleteField(
                  labelText: 'From',
                  hintText: 'Pick-up location',
                  prefixIconData: Icons.trip_origin,
                  initialValue: state.fromAddress,
                  suggestions: _savedAddresses,
                  excludeAddress: state.toAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Pick-up location is required';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    context.read<CreateRideFormBloc>().add(
                      FromAddressChanged(value),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.paddingSmall),
                Center(
                  child: IconButton(
                    onPressed: () {
                      // Drop focus first so both address fields re-sync their
                      // text from the swapped state. AddressAutocompleteField
                      // skips the controller sync while focused, so without
                      // this the focused field would keep its stale text and
                      // the swap would look like it did nothing.
                      FocusScope.of(context).unfocus();
                      context.read<CreateRideFormBloc>().add(
                        const AddressesSwapped(),
                      );
                    },
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Swap From / To',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.secretaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingSmall),
                AddressAutocompleteField(
                  labelText: 'To',
                  hintText: 'Drop-off location',
                  prefixIconData: Icons.location_on,
                  initialValue: state.toAddress,
                  suggestions: _savedAddresses,
                  excludeAddress: state.fromAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Drop-off location is required';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    context.read<CreateRideFormBloc>().add(
                      ToAddressChanged(value),
                    );
                  },
                ),
                if (state.fromAddress.trim().isNotEmpty &&
                    state.toAddress.trim().isNotEmpty &&
                    state.fromAddress.trim().toLowerCase() ==
                        state.toAddress.trim().toLowerCase())
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.paddingSmall / 2,
                    ),
                    child: Text(
                      'Pick-up and drop-off cannot be the same address.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
