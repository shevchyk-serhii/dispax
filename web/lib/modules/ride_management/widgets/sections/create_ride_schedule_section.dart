import 'package:flutter/material.dart';
import '../../helpers/create_ride_form_helper.dart';
import '../schedule_card.dart';

class CreateRideScheduleSection extends StatelessWidget {
  final DateTime pickupDateTime;

  const CreateRideScheduleSection({
    super.key,
    required this.pickupDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return ScheduleCard(
      pickupDateTime: pickupDateTime,
      onSelectDateTime: () => CreateRideFormHelper.selectDateTime(
        context,
        pickupDateTime,
      ),
    );
  }
}
