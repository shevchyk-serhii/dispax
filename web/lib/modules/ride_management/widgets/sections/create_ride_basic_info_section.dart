import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../basic_info_card.dart';

class CreateRideBasicInfoSection extends StatelessWidget {
  final String clientName;

  const CreateRideBasicInfoSection({
    super.key,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return BasicInfoCard(
      clientName: clientName,
      onClientNameChanged: (value) {
        context.read<CreateRideFormBloc>().add(ClientNameChanged(value));
      },
    );
  }
}
