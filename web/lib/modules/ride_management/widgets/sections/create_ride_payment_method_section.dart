import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../../models/payment_method.dart';

/// Payment-method selector for the create-ride form. Defaults to
/// [PaymentMethod.invoice] (Rechnung); the operator may switch to any of the
/// four offered methods. The selection is always submitted with the ride.
class CreateRidePaymentMethodSection extends StatelessWidget {
  final PaymentMethod selectedPaymentMethod;

  const CreateRidePaymentMethodSection({
    super.key,
    required this.selectedPaymentMethod,
  });

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
      child: DropdownButtonFormField<PaymentMethod>(
        initialValue: selectedPaymentMethod,
        decoration: InputDecoration(
          labelText: l10n.paymentMethodSelectLabel,
          prefixIcon: Icon(
            Icons.payments_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        items: [
          for (final method in PaymentMethod.values)
            DropdownMenuItem<PaymentMethod>(
              value: method,
              child: Text(method.label(l10n)),
            ),
        ],
        onChanged: (method) {
          if (method != null) {
            context.read<CreateRideFormBloc>().add(
              PaymentMethodSelected(method),
            );
          }
        },
      ),
    );
  }
}
