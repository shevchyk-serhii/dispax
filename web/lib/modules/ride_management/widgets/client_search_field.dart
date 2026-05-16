import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
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
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[600], size: 24),
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
            const SizedBox(height: AppDimensions.paddingMedium),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                    return _clients.where((p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.email.toLowerCase().contains(query) ||
                        (p.phone?.toLowerCase().contains(query) ?? false));
                  },
                  onSelected: (Person client) {
                    context.read<CreateRideFormBloc>().add(
                          ClientSelected(clientId: client.id, clientName: client.name),
                        );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    // Sync controller if form was cleared
                    if (formState.selectedClientId == null && controller.text.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        controller.clear();
                      });
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Client Name',
                        hintText: 'Search by name, email or phone',
                        prefixIcon:
                            Icon(Icons.search, color: AppColors.secretaryColor),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        suffixIcon: formState.selectedClientId != null
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      validator: (_) {
                        if (formState.selectedClientId == null) {
                          return 'Please select a client from the list';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => onSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final client = options.elementAt(index);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.secretaryColor,
                                  child: Text(
                                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(client.name),
                                subtitle: client.email.isNotEmpty ? Text(client.email) : null,
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
