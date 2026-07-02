import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/services/user_service.dart';
import '../services/client_address_service.dart';
import 'client_autocomplete_field.dart';

/// The create-ride form's client section: a card wrapping the shared
/// [ClientAutocompleteField], wired to the [CreateRideFormBloc] (selection
/// events + default-address prefill).
class ClientSearchField extends StatefulWidget {
  final UserService userService;

  const ClientSearchField({super.key, required this.userService});

  @override
  State<ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<ClientSearchField> {
  late final ClientAddressService _addressService;

  @override
  void initState() {
    super.initState();
    _addressService = ClientAddressService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
  }

  @override
  void dispose() {
    _addressService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.formCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.infoStrong, size: 24),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Client Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.formSectionGap),
            BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
              buildWhen: (prev, curr) =>
                  prev.clientName != curr.clientName ||
                  prev.selectedClientId != curr.selectedClientId,
              builder: (context, formState) {
                return ClientAutocompleteField(
                  userService: widget.userService,
                  selectedClientId: formState.selectedClientId,
                  onSelected: (client) async {
                    String? defaultAddress;
                    try {
                      final addresses = await _addressService.getAddresses(
                        client.id,
                      );
                      if (addresses.isNotEmpty) {
                        final home = addresses.firstWhere(
                          (a) => a.label.toLowerCase().contains('home'),
                          orElse: () => addresses.first,
                        );
                        defaultAddress = home.address;
                      }
                    } catch (_) {}
                    if (!context.mounted) return;
                    context.read<CreateRideFormBloc>().add(
                      ClientSelected(
                        clientId: client.id,
                        clientName: client.name,
                        defaultAddress: defaultAddress,
                      ),
                    );
                  },
                  onCleared: () => context.read<CreateRideFormBloc>().add(
                    const ClientCleared(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
