import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

/// Optional ride price input for the create-ride form. The operator may leave it
/// empty — the ride is then created without a price and one can be set later. The
/// value is independent of the auto-computed estimate; it is typed manually.
class CreateRidePriceSection extends StatefulWidget {
  final double? price;

  const CreateRidePriceSection({super.key, this.price});

  @override
  State<CreateRidePriceSection> createState() => _CreateRidePriceSectionState();
}

class _CreateRidePriceSectionState extends State<CreateRidePriceSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.price));
  }

  @override
  void didUpdateWidget(CreateRidePriceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync when the state's price is cleared externally
    // (e.g. Clear Form), without clobbering the user's in-progress typing.
    final expected = _format(widget.price);
    if (widget.price != oldWidget.price && _controller.text != expected) {
      _controller.text = expected;
    }
  }

  static String _format(double? price) {
    if (price == null) return '';
    // Drop a trailing ".0" so a whole-euro price reads "45", not "45.0".
    return price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
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
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // Allow digits and a single decimal separator (dot or comma).
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: l10n.priceOptionalLabel,
          prefixIcon: Icon(
            Icons.euro,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        onChanged: (value) {
          final normalized = value.trim().replaceAll(',', '.');
          final parsed = double.tryParse(normalized);
          // Empty or invalid input clears the price; a value <= 0 is rejected by
          // the backend, so we still forward it to surface the validation error.
          context.read<CreateRideFormBloc>().add(
            RidePriceChanged(normalized.isEmpty ? null : parsed),
          );
        },
      ),
    );
  }
}
