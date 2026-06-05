import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../models/client_address.dart';

class AddressAutocompleteField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final IconData prefixIconData;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final List<ClientAddress> suggestions;
  final String? Function(String?)? validator;

  const AddressAutocompleteField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.prefixIconData,
    required this.initialValue,
    required this.onChanged,
    required this.suggestions,
    this.validator,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  // Bump this key when initialValue is reset to '' to force Autocomplete to
  // rebuild and clear its internal controller (e.g. after form clear).
  late int _resetKey;

  @override
  void initState() {
    super.initState();
    _resetKey = 0;
  }

  @override
  void didUpdateWidget(AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force Autocomplete rebuild whenever initialValue changes externally
    // (e.g. form clear → '', address swap, template fill).
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() => _resetKey++);
    }
  }

  List<ClientAddress> _getFiltered(String query) {
    if (query.isEmpty) return widget.suggestions.take(5).toList();
    final lower = query.toLowerCase();
    return widget.suggestions
        .where((a) =>
            a.address.toLowerCase().contains(lower) ||
            a.label.toLowerCase().contains(lower) ||
            a.aliases.any((alias) => alias.toLowerCase().contains(lower)))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ClientAddress>(
      key: ValueKey(_resetKey),
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (textEditingValue) {
        if (widget.suggestions.isEmpty) return const Iterable.empty();
        return _getFiltered(textEditingValue.text);
      },
      displayStringForOption: (addr) => addr.address,
      onSelected: (addr) => widget.onChanged(addr.address),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: Icon(widget.prefixIconData, color: AppColors.secretaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
          ),
          validator: widget.validator,
          onChanged: widget.onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final addr = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.history, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      title: Text(addr.address, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(addr.label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: addr.useCount > 1
                          ? Text('×${addr.useCount}',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outlineVariant))
                          : null,
                      onTap: () => onSelected(addr),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
