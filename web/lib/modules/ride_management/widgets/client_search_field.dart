import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/core/widgets/avatar_circle.dart';
import '../services/client_address_service.dart';

class ClientSearchField extends StatefulWidget {
  final UserService userService;

  const ClientSearchField({super.key, required this.userService});

  @override
  State<ClientSearchField> createState() => _ClientSearchFieldState();
}

class _ClientSearchFieldState extends State<ClientSearchField> {
  List<Person> _clients = [];
  bool _loading = false;
  String? _error;
  late final ClientAddressService _addressService;

  @override
  void initState() {
    super.initState();
    _addressService = ClientAddressService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
    _loadClients();
  }

  @override
  void dispose() {
    _addressService.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clients = await widget.userService.getClients();
      if (mounted) {
        setState(() {
          _clients = clients;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load clients';
          _loading = false;
        });
      }
    }
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
                if (_loading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.formSectionGap),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error ?? '',
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
              buildWhen: (prev, curr) =>
                  prev.clientName != curr.clientName ||
                  prev.selectedClientId != curr.selectedClientId,
              builder: (context, formState) {
                return Autocomplete<Person>(
                  displayStringForOption: (p) => p.name,
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _clients;
                    final query = textEditingValue.text.toLowerCase();
                    return _clients.where(
                      (p) =>
                          p.name.toLowerCase().contains(query) ||
                          p.email.toLowerCase().contains(query) ||
                          (p.phone?.toLowerCase().contains(query) ?? false),
                    );
                  },
                  onSelected: (Person client) async {
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
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                        // Sync controller if form was cleared
                        if (formState.selectedClientId == null &&
                            controller.text.isNotEmpty &&
                            !focusNode.hasFocus) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.clear();
                          });
                        }
                        return ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) => TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Client Name',
                              hintText: 'Search by name, email or phone',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                              ),
                              suffixIcon: formState.selectedClientId != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          tooltip: 'Clear',
                                          splashRadius: 18,
                                          onPressed: () {
                                            controller.clear();
                                            context
                                                .read<CreateRideFormBloc>()
                                                .add(const ClientCleared());
                                          },
                                        ),
                                      ],
                                    )
                                  : (controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            tooltip: 'Clear',
                                            splashRadius: 18,
                                            onPressed: () {
                                              controller.clear();
                                              context
                                                  .read<CreateRideFormBloc>()
                                                  .add(const ClientCleared());
                                            },
                                          )
                                        : null),
                            ),
                            validator: (_) {
                              if (formState.selectedClientId == null) {
                                return 'Please select a client from the list';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => onSubmitted(),
                          ),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final client = options.elementAt(index);
                              return ListTile(
                                // Show the client's profile photo when set,
                                // falling back to initials.
                                leading: AvatarCircle(
                                  user: client,
                                  apiClient:
                                      widget.userService.privateApiClient,
                                  radius: 20,
                                ),
                                title: Text(client.name),
                                subtitle: client.email.isNotEmpty
                                    ? Text(client.email)
                                    : null,
                                onTap: () => onSelected(client),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
