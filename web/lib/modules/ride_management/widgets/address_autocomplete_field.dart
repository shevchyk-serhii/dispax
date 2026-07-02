import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final String? excludeAddress;

  const AddressAutocompleteField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.prefixIconData,
    required this.initialValue,
    required this.onChanged,
    required this.suggestions,
    this.validator,
    this.excludeAddress,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  // We own the controller and focus node so we can sync the displayed text on
  // external changes (form clear, address swap, template fill) WITHOUT
  // rebuilding Autocomplete. Rebuilding (the old _resetKey/ValueKey trick)
  // dropped focus, which bounced it back to the first form field (the client
  // search) every time the user picked an address.
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the field text only on EXTERNAL changes — i.e. when this field is not
    // focused. While the user is typing/selecting in this very field it holds
    // focus, and its own onChanged already drives the value, so we must not
    // touch the controller (doing so would move the caret / steal focus).
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text &&
        !_focusNode.hasFocus) {
      _syncControllerText(widget.initialValue);
    }
  }

  /// Writes [next] into the controller. Setting controller.text synchronously
  /// notifies listeners, which bubbles up to Form._forceRebuild → setState().
  /// If didUpdateWidget runs inside the parent's build (e.g. the location
  /// section's BlocBuilder on an address swap), that setState() lands during
  /// build and Flutter throws. So when we're mid-build/layout we defer the write
  /// to the next frame; otherwise we write synchronously so the value is
  /// immediately visible to Form validation (Create Ride reads it right away).
  void _syncControllerText(String next) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final midFrame =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!midFrame) {
      _controller.text = next;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Re-check: state may have changed before this callback ran.
      if (next != _controller.text && !_focusNode.hasFocus) {
        _controller.text = next;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<ClientAddress> _getFiltered(String query) {
    final excluded = widget.excludeAddress?.trim().toLowerCase();
    final bool hasExcluded = excluded != null && excluded.isNotEmpty;

    if (query.isEmpty) {
      return widget.suggestions
          .where(
            (a) => !hasExcluded || a.address.trim().toLowerCase() != excluded,
          )
          .take(5)
          .toList();
    }

    final lower = query.toLowerCase();
    return widget.suggestions
        .where(
          (a) =>
              a.address.toLowerCase().contains(lower) ||
              a.label.toLowerCase().contains(lower) ||
              a.aliases.any((alias) => alias.toLowerCase().contains(lower)),
        )
        .where(
          (a) => !hasExcluded || a.address.trim().toLowerCase() != excluded,
        )
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ClientAddress>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        if (widget.suggestions.isEmpty) return const Iterable.empty();
        return _getFiltered(textEditingValue.text);
      },
      displayStringForOption: (addr) => addr.address,
      onSelected: (addr) => widget.onChanged(addr.address),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: Icon(
                  widget.prefixIconData,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        tooltip: 'Clear',
                        splashRadius: 18,
                        onPressed: () {
                          controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
              ),
              validator: widget.validator,
              onChanged: widget.onChanged,
            );
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
                      leading: Icon(
                        Icons.history,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        addr.address,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        addr.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: addr.useCount > 1
                          ? Text(
                              '×${addr.useCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            )
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
