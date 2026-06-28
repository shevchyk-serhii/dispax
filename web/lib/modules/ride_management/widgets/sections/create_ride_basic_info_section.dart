import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/models/person.dart';
import '../../../../modules/core/services/user_service.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../client_search_field.dart';
import '../clearable_text_field.dart';

class CreateRideBasicInfoSection extends StatefulWidget {
  const CreateRideBasicInfoSection({super.key});

  @override
  State<CreateRideBasicInfoSection> createState() =>
      _CreateRideBasicInfoSectionState();
}

class _CreateRideBasicInfoSectionState
    extends State<CreateRideBasicInfoSection> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    _userService = UserService(apiClient: authBloc.apiClient);

    final authState = authBloc.state;
    final user = authState.user;
    final role = user?.role;
    // Client and driver book for themselves by default
    if (authState.status == AuthStatus.authenticated &&
        user != null &&
        (role == PersonRole.client || role == PersonRole.driver)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CreateRideFormBloc>().add(
          ClientPreselected(clientId: user.id, clientName: user.name),
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
    final authState = context.read<AuthBloc>().state;
    final role = authState.user?.role;

    // Client — hidden, they always select themselves
    if (role == PersonRole.client) return const SizedBox.shrink();

    // Driver — show the client select/create section
    if (role == PersonRole.driver) {
      return _DriverClientSection(userService: _userService);
    }

    // Dispatcher/secretary — standard search
    return ClientSearchField(userService: _userService);
  }
}

class _DriverClientSection extends StatelessWidget {
  final UserService userService;

  const _DriverClientSection({required this.userService});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      buildWhen: (prev, curr) =>
          prev.isNewClient != curr.isNewClient ||
          prev.selectedClientId != curr.selectedClientId ||
          prev.clientName != curr.clientName,
      builder: (context, state) {
        return Container(
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
          padding: const EdgeInsets.all(AppDimensions.formCardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppDimensions.paddingSmall),
                      const Text(
                        'Client',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.read<CreateRideFormBloc>().add(
                      const NewClientModeToggled(),
                    ),
                    icon: Icon(
                      state.isNewClient
                          ? Icons.search
                          : Icons.person_add_outlined,
                      size: 16,
                    ),
                    label: Text(
                      state.isNewClient ? 'Find existing' : 'New client',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.formSectionGap),
              if (state.isNewClient)
                _NewClientFields()
              else
                ClientSearchField(userService: userService),
            ],
          ),
        );
      },
    );
  }
}

class _NewClientFields extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      buildWhen: (prev, curr) =>
          prev.clientName != curr.clientName ||
          prev.newClientPhone != curr.newClientPhone,
      builder: (context, state) {
        return Column(
          children: [
            ClearableTextField(
              value: state.clientName,
              labelText: 'Client name *',
              hintText: 'Full name',
              prefixIconData: Icons.person_outline,
              onChanged: (v) =>
                  context.read<CreateRideFormBloc>().add(ClientNameChanged(v)),
            ),
            const SizedBox(height: AppDimensions.formSectionGap),
            ClearableTextField(
              value: state.newClientPhone,
              keyboardType: TextInputType.phone,
              labelText: 'Phone (optional)',
              hintText: '+49 123 456 7890',
              prefixIconData: Icons.phone_outlined,
              onChanged: (v) => context.read<CreateRideFormBloc>().add(
                NewClientPhoneChanged(v),
              ),
            ),
          ],
        );
      },
    );
  }
}
