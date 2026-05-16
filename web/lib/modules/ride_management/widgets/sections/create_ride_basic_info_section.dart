import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/services/user_service.dart';
import '../client_search_field.dart';

class CreateRideBasicInfoSection extends StatefulWidget {
  const CreateRideBasicInfoSection({super.key});

  @override
  State<CreateRideBasicInfoSection> createState() => _CreateRideBasicInfoSectionState();
}

class _CreateRideBasicInfoSectionState extends State<CreateRideBasicInfoSection> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(apiClient: context.read<AuthBloc>().apiClient);
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClientSearchField(userService: _userService);
  }
}
