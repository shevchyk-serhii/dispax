import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../modules/core/services/api_client.dart';

// ---------------------------------------------------------------------------
// Domain model
// ---------------------------------------------------------------------------

class CompanyInfo {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String status;
  final String subscriptionPlan;
  final String? createdAt;

  const CompanyInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    required this.subscriptionPlan,
    this.createdAt,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) => CompanyInfo(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    status: json['status']?.toString() ?? 'Active',
    subscriptionPlan: json['subscriptionPlan']?.toString() ?? 'Free',
    createdAt: json['createdAt']?.toString(),
  );
}

// ---------------------------------------------------------------------------
// BLoC — events
// ---------------------------------------------------------------------------

abstract class SuperAdminCompanyEvent {}

class LoadCompanies extends SuperAdminCompanyEvent {}

class UpdateCompanyStatus extends SuperAdminCompanyEvent {
  final String companyId;
  final String status;
  UpdateCompanyStatus(this.companyId, this.status);
}

class CreateCompany extends SuperAdminCompanyEvent {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String status;
  final String subscriptionPlan;

  CreateCompany({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    required this.subscriptionPlan,
  });
}

class UpdateCompany extends SuperAdminCompanyEvent {
  final String companyId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String status;
  final String subscriptionPlan;

  UpdateCompany({
    required this.companyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    required this.subscriptionPlan,
  });
}

class DeleteCompany extends SuperAdminCompanyEvent {
  final String companyId;
  DeleteCompany(this.companyId);
}

// ---------------------------------------------------------------------------
// BLoC — states
// ---------------------------------------------------------------------------

abstract class SuperAdminCompanyState {}

class CompaniesInitial extends SuperAdminCompanyState {}

class CompaniesLoading extends SuperAdminCompanyState {}

class CompaniesLoaded extends SuperAdminCompanyState {
  final List<CompanyInfo> companies;
  CompaniesLoaded(this.companies);
}

class CompaniesError extends SuperAdminCompanyState {
  final String message;
  CompaniesError(this.message);
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

class SuperAdminCompanyBloc
    extends Bloc<SuperAdminCompanyEvent, SuperAdminCompanyState> {
  final ApiClient _api;

  SuperAdminCompanyBloc(this._api) : super(CompaniesInitial()) {
    on<LoadCompanies>(_onLoad);
    on<UpdateCompanyStatus>(_onUpdateStatus);
    on<CreateCompany>(_onCreateCompany);
    on<UpdateCompany>(_onUpdateCompany);
    on<DeleteCompany>(_onDeleteCompany);
  }

  Future<void> _onLoad(
    LoadCompanies event,
    Emitter<SuperAdminCompanyState> emit,
  ) async {
    emit(CompaniesLoading());
    try {
      final response = await _api.get('/superadmin/companies');
      if (response.statusCode == 200) {
        final List<dynamic> body = (response.body as dynamic) is List
            ? response.body as List
            : [];
        emit(
          CompaniesLoaded(
            body
                .map((e) => CompanyInfo.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
      } else {
        emit(CompaniesError('Failed to load companies'));
      }
    } catch (e) {
      emit(CompaniesError(e.toString()));
    }
  }

  Future<void> _onUpdateStatus(
    UpdateCompanyStatus event,
    Emitter<SuperAdminCompanyState> emit,
  ) async {
    try {
      await _api.patch('/superadmin/companies/${event.companyId}', {
        'status': event.status,
      });
      add(LoadCompanies());
    } catch (e) {
      emit(CompaniesError(e.toString()));
    }
  }

  Future<void> _onCreateCompany(
    CreateCompany event,
    Emitter<SuperAdminCompanyState> emit,
  ) async {
    try {
      final response = await _api.post('/superadmin/companies', {
        'name': event.name,
        'email': event.email,
        'phone': event.phone,
        'address': event.address,
        'status': event.status,
        'subscriptionPlan': event.subscriptionPlan,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        add(LoadCompanies());
      } else {
        emit(
          CompaniesError('Failed to create company: ${response.statusCode}'),
        );
      }
    } catch (e) {
      emit(CompaniesError(e.toString()));
    }
  }

  Future<void> _onUpdateCompany(
    UpdateCompany event,
    Emitter<SuperAdminCompanyState> emit,
  ) async {
    try {
      final response = await _api
          .patch('/superadmin/companies/${event.companyId}', {
            'name': event.name,
            'email': event.email,
            'phone': event.phone,
            'address': event.address,
            'status': event.status,
            'subscriptionPlan': event.subscriptionPlan,
          });
      if (response.statusCode == 200) {
        add(LoadCompanies());
      } else {
        emit(
          CompaniesError('Failed to update company: ${response.statusCode}'),
        );
      }
    } catch (e) {
      emit(CompaniesError(e.toString()));
    }
  }

  Future<void> _onDeleteCompany(
    DeleteCompany event,
    Emitter<SuperAdminCompanyState> emit,
  ) async {
    try {
      final response = await _api.delete(
        '/superadmin/companies/${event.companyId}',
      );
      if (response.statusCode == 200) {
        add(LoadCompanies());
      } else {
        emit(
          CompaniesError(
            'Failed to deactivate company: ${response.statusCode}',
          ),
        );
      }
    } catch (e) {
      emit(CompaniesError(e.toString()));
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Platform admin screen: full CRUD for tenant companies.
/// Accessible only to SuperAdmin users.
class SuperAdminCompaniesScreen extends StatelessWidget {
  const SuperAdminCompaniesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SuperAdminCompanyBloc(context.read<AuthBloc>().apiClient)
            ..add(LoadCompanies()),
      child: const _CompaniesView(),
    );
  }
}

class _CompaniesView extends StatelessWidget {
  const _CompaniesView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuperAdminCompanyBloc, SuperAdminCompanyState>(
      builder: (context, state) {
        if (state is CompaniesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CompaniesError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<SuperAdminCompanyBloc>().add(
                    LoadCompanies(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is CompaniesLoaded) {
          return _CompaniesTable(companies: state.companies);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _CompaniesTable extends StatelessWidget {
  final List<CompanyInfo> companies;
  const _CompaniesTable({required this.companies});

  void _showAddDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _CompanyFormDialog(bloc: context.read<SuperAdminCompanyBloc>()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Companies (${companies.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (companies.isEmpty)
                const Center(child: Text('No companies found'))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Plan')),
                      DataColumn(label: Text('Created')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: companies.map((c) => _buildRow(context, c)).toList(),
                  ),
                ),
              // bottom padding so FAB doesn't obscure last row
              const SizedBox(height: 80),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Company'),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(BuildContext context, CompanyInfo c) {
    return DataRow(
      cells: [
        DataCell(Text(c.name)),
        DataCell(Text(c.email)),
        DataCell(_StatusChip(status: c.status)),
        DataCell(Text(c.subscriptionPlan)),
        DataCell(Text(c.createdAt ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _CompanyFormDialog(
                    bloc: context.read<SuperAdminCompanyBloc>(),
                    company: c,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Deactivate',
                onPressed: () => _confirmDelete(context, c),
              ),
              PopupMenuButton<String>(
                onSelected: (newStatus) => context
                    .read<SuperAdminCompanyBloc>()
                    .add(UpdateCompanyStatus(c.id, newStatus)),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Active', child: Text('Set Active')),
                  PopupMenuItem(value: 'Suspended', child: Text('Suspend')),
                  PopupMenuItem(value: 'Trial', child: Text('Set Trial')),
                  PopupMenuItem(value: 'Inactive', child: Text('Set Inactive')),
                ],
                child: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, CompanyInfo c) {
    final bloc = context.read<SuperAdminCompanyBloc>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Company?'),
        content: Text(
          'Are you sure you want to deactivate "${c.name}"?\n\n'
          'The company will be marked as Inactive but all data '
          '(rides, invoices, users) will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              bloc.add(DeleteCompany(c.id));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Company form dialog — used for both create and edit
// ---------------------------------------------------------------------------

class _CompanyFormDialog extends StatefulWidget {
  final SuperAdminCompanyBloc bloc;
  final CompanyInfo? company; // null = create, non-null = edit

  const _CompanyFormDialog({required this.bloc, this.company});

  @override
  State<_CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<_CompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late String _status;
  late String _plan;

  static const _statusOptions = ['Active', 'Trial', 'Suspended', 'Inactive'];
  static const _planOptions = ['Free', 'Starter', 'Professional', 'Enterprise'];

  bool get _isEdit => widget.company != null;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _status = c?.status ?? 'Active';
    _plan = c?.subscriptionPlan ?? 'Free';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_isEdit) {
      widget.bloc.add(
        UpdateCompany(
          companyId: widget.company!.id,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          status: _status,
          subscriptionPlan: _plan,
        ),
      );
    } else {
      widget.bloc.add(
        CreateCompany(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          status: _status,
          subscriptionPlan: _plan,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Company' : 'Add Company'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Company Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Company Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Company Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Address',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _plan,
                  decoration: const InputDecoration(
                    labelText: 'Subscription Plan',
                  ),
                  items: _planOptions
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _plan = v ?? _plan),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip widget
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Active' => Colors.green,
      'Suspended' => Colors.red,
      'Trial' => Colors.orange,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
