import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/services/user_service.dart';
import '../../../modules/core/widgets/avatar_circle.dart';

/// A controlled client autocomplete: loads the company's clients once and lets
/// the user pick one by name/email/phone. The parent owns the selection state —
/// pass [selectedClientId] and react via [onSelected]/[onCleared]. Used by the
/// create-ride form (through [ClientSearchField]) and the edit-ride dialog.
class ClientAutocompleteField extends StatefulWidget {
  final UserService userService;

  /// The currently selected client, or null when nothing is selected. Drives
  /// the check icon and the "sync controller when cleared" behavior.
  final String? selectedClientId;

  /// Pre-fills the search field (e.g. the ride's current client name in the
  /// edit dialog). Only read once, when the field is first built.
  final String? initialClientName;

  /// When true (create flow) an empty selection fails form validation; when
  /// false (edit flow) clearing the field is allowed and means "keep as is".
  final bool requireSelection;

  final ValueChanged<Person> onSelected;
  final VoidCallback onCleared;

  const ClientAutocompleteField({
    super.key,
    required this.userService,
    required this.selectedClientId,
    required this.onSelected,
    required this.onCleared,
    this.initialClientName,
    this.requireSelection = true,
  });

  @override
  State<ClientAutocompleteField> createState() =>
      _ClientAutocompleteFieldState();
}

class _ClientAutocompleteFieldState extends State<ClientAutocompleteField> {
  List<Person> _clients = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
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

  Widget _clearButton(TextEditingController controller) {
    return IconButton(
      icon: const Icon(Icons.close, size: 18),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: 'Clear',
      splashRadius: 18,
      onPressed: () {
        controller.clear();
        widget.onCleared();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error ?? '',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        Autocomplete<Person>(
          displayStringForOption: (p) => p.name,
          initialValue: widget.initialClientName != null
              ? TextEditingValue(text: widget.initialClientName ?? '')
              : null,
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
          onSelected: widget.onSelected,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // Sync controller if the selection was cleared by the parent
            if (widget.selectedClientId == null &&
                widget.initialClientName == null &&
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
                  prefixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                  suffixIcon: widget.selectedClientId != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                            _clearButton(controller),
                          ],
                        )
                      : (controller.text.isNotEmpty
                            ? _clearButton(controller)
                            : null),
                ),
                validator: (_) {
                  if (widget.requireSelection &&
                      widget.selectedClientId == null) {
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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
                          apiClient: widget.userService.privateApiClient,
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
        ),
      ],
    );
  }
}
