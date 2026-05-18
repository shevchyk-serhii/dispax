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
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ClientAddress> _getFilteredSuggestions(String query) {
    if (query.isEmpty) return widget.suggestions.take(5).toList();
    final lower = query.toLowerCase();
    return widget.suggestions
        .where((a) => a.address.toLowerCase().contains(lower) || a.label.toLowerCase().contains(lower))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ClientAddress>(
      optionsBuilder: (textEditingValue) {
        if (widget.suggestions.isEmpty) return const Iterable.empty();
        return _getFilteredSuggestions(textEditingValue.text);
      },
      displayStringForOption: (addr) => addr.address,
      onSelected: (addr) {
        _controller.text = addr.address;
        widget.onChanged(addr.address);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        // Sync external controller changes into the Autocomplete's internal controller
        fieldController.text = _controller.text;
        return TextFormField(
          controller: fieldController,
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
          onChanged: (value) {
            _controller.text = value;
            widget.onChanged(value);
          },
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
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final addr = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(addr),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(addr.label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(addr.address, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          if (addr.useCount > 1)
                            Text(
                              '×${addr.useCount}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
