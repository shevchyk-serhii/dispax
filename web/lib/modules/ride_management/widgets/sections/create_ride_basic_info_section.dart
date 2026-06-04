import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/models/person.dart';
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
    final authBloc = context.read<AuthBloc>();
    _userService = UserService(apiClient: authBloc.apiClient);

    // For CLIENT and DRIVER roles: auto-select themselves, no need to search
    final authState = authBloc.state;
    final role = authState.user?.role;
    if (authState.status == AuthStatus.authenticated &&
        (role == PersonRole.client || role == PersonRole.driver)) {
      final user = authState.user!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CreateRideFormBloc>().add(
          ClientSelected(clientId: user.id, clientName: user.name),
        );
      });
    }
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    final isSelfBooking = authState.status == AuthStatus.authenticated &&
        (authState.user?.role == PersonRole.client ||
         authState.user?.role == PersonRole.driver);

    if (isSelfBooking) {
      return const SizedBox.shrink();
    }

    return ClientSearchField(userService: _userService);
  }
}
