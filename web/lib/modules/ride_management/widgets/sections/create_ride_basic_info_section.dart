import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/models/person.dart';
import '../../../../modules/core/services/user_service.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
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

    final authState = authBloc.state;
    final role = authState.user?.role;
    // Клиент и водитель по умолчанию бронируют на себя
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
    final authState = context.read<AuthBloc>().state;
    final role = authState.user?.role;

    // Клиент — скрываем, он всегда себя выбирает
    if (role == PersonRole.client) return const SizedBox.shrink();

    // Водитель — показываем секцию выбора/создания клиента
    if (role == PersonRole.driver) {
      return _DriverClientSection(userService: _userService);
    }

    // Диспетчер/секретарь — стандартный поиск
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
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: AppColors.driverColor, size: 22),
                      const SizedBox(width: AppDimensions.paddingSmall),
                      const Text(
                        'Client',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context
                        .read<CreateRideFormBloc>()
                        .add(const NewClientModeToggled()),
                    icon: Icon(
                      state.isNewClient ? Icons.search : Icons.person_add_outlined,
                      size: 16,
                    ),
                    label: Text(state.isNewClient ? 'Find existing' : 'New client'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.driverColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
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
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Client name *',
            hintText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) =>
              context.read<CreateRideFormBloc>().add(ClientNameChanged(v)),
        ),
        const SizedBox(height: AppDimensions.paddingMedium),
        TextFormField(
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone (optional)',
            hintText: '+49 123 456 7890',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) =>
              context.read<CreateRideFormBloc>().add(NewClientPhoneChanged(v)),
        ),
      ],
    );
  }
}
