import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/client/client_bloc.dart';
import '../../../blocs/client/client_event.dart';
import '../../../blocs/client/client_state.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/models/user_requests.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';
import 'client_detail_screen.dart';

class ClientListPanel extends StatefulWidget {
  const ClientListPanel({super.key});

  @override
  State<ClientListPanel> createState() => _ClientListPanelState();
}

class _ClientListPanelState extends State<ClientListPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ClientBloc>().add(const ClientLoadRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Clients',
          style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary),
        ),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: AppDimensions.appBarElevation,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ClientBloc>().add(const ClientLoadRequested());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secretaryColor,
        onPressed: () => _showCreateClientDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ClientBloc>().add(
                            const ClientSearchRequested(query: ''),
                          );
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
              ),
              onChanged: (query) {
                context.read<ClientBloc>().add(
                  ClientSearchRequested(query: query),
                );
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<ClientBloc, ClientState>(
              builder: (context, state) {
                if (state.isLoading && state.clients.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.hasError && state.clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 12),
                        Text(state.errorMessage ?? 'An error occurred'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ClientBloc>().add(
                              const ClientLoadRequested(),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final clients = state.filteredClients;

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.searchQuery.isNotEmpty
                              ? 'No clients match your search'
                              : 'No clients yet',
                          style: AppStyles.bodyLarge.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ClientBloc>().add(const ClientLoadRequested());
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMedium,
                    ),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      return _buildClientCard(context, clients[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, Person client) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: client.isVip
              ? AppColors.warningBorder
              : AppColors.secretaryColor.withAlpha(30),
          child: client.isVip
              ? const Icon(Icons.star, color: AppColors.warning, size: 20)
              : Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.secretaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(client.name, style: AppStyles.titleSmall)),
            if (client.isVip) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warningBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client.email, style: AppStyles.bodySmall),
            if (client.phone != null && client.phone!.isNotEmpty)
              Text(client.phone!, style: AppStyles.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditClientDialog(context, client);
            } else if (value == 'deactivate') {
              _showDeactivateConfirmation(context, client);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'deactivate',
              child: Text(
                'Deactivate',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(client: client),
            ),
          );
        },
      ),
    );
  }

  void _showCreateClientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Client'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.paddingMedium),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.paddingMedium),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secretaryColor,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<ClientBloc>().add(
                    ClientCreateRequested(
                      request: CreateUserRequest(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim().isNotEmpty
                            ? phoneController.text.trim()
                            : null,
                      ),
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditClientDialog(BuildContext context, Person client) {
    final nameController = TextEditingController(text: client.name);
    final emailController = TextEditingController(text: client.email);
    final phoneController = TextEditingController(text: client.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Client'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: AppDimensions.paddingMedium),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.paddingMedium),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secretaryColor,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<ClientBloc>().add(
                    ClientUpdateRequested(
                      clientId: client.id,
                      request: UpdateUserRequest(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim().isNotEmpty
                            ? phoneController.text.trim()
                            : null,
                      ),
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeactivateConfirmation(BuildContext context, Person client) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Client'),
          content: Text('Are you sure you want to deactivate ${client.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                context.read<ClientBloc>().add(
                  ClientDeactivateRequested(clientId: client.id),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }
}
