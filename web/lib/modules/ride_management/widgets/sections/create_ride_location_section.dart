import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../location_card.dart';

class CreateRideLocationSection extends StatelessWidget {
  final String fromAddress;
  final String toAddress;

  const CreateRideLocationSection({
    super.key,
    required this.fromAddress,
    required this.toAddress,
  });

  @override
  Widget build(BuildContext context) {
    return LocationCard(
      fromAddress: fromAddress,
      toAddress: toAddress,
      onFromAddressChanged: (value) {
        context.read<CreateRideFormBloc>().add(FromAddressChanged(value));
      },
      onToAddressChanged: (value) {
        context.read<CreateRideFormBloc>().add(ToAddressChanged(value));
      },
    );
  }
}
