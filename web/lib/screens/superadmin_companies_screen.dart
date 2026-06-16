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
// BLoC
// ---------------------------------------------------------------------------

abstract class SuperAdminCompanyEvent {}

class LoadCompanies extends SuperAdminCompanyEvent {}

class UpdateCompanyStatus extends SuperAdminCompanyEvent {
  final String companyId;
  final String status;
  UpdateCompanyStatus(this.companyId, this.status);
}

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

class SuperAdminCompanyBloc
    extends Bloc<SuperAdminCompanyEvent, SuperAdminCompanyState> {
  final ApiClient _api;

  SuperAdminCompanyBloc(this._api) : super(CompaniesInitial()) {
    on<LoadCompanies>(_onLoad);
    on<UpdateCompanyStatus>(_onUpdateStatus);
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
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Platform admin screen: list all tenant companies with status and plan.
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

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) {
      return const Center(child: Text('No companies found'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Companies (${companies.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
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
        ],
      ),
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
        ),
      ],
    );
  }
}

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
