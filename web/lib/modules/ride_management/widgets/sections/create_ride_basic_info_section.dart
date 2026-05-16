import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/services/user_service.dart';
import '../client_search_field.dart';

class CreateRideBasicInfoSection extends StatelessWidget {
  const CreateRideBasicInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<AuthBloc>().apiClient;
    final userService = UserService(apiClient: apiClient);
    return ClientSearchField(userService: userService);
  }
}
