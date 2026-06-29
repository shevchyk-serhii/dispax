import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_styles.dart';
import '../l10n/app_localizations.dart';
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
        final decoded = jsonDecode(response.body);
        final List<dynamic> body = decoded is List ? decoded : [];
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
    return Column(
      children: [
        _GraphiteHeader(
          onRefresh: () =>
              context.read<SuperAdminCompanyBloc>().add(LoadCompanies()),
        ),
        Expanded(
          child: BlocBuilder<SuperAdminCompanyBloc, SuperAdminCompanyState>(
            builder: (context, state) {
              if (state is CompaniesLoading) {
                return Center(child: CircularProgressIndicator.adaptive());
              }
              if (state is CompaniesError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error: ${state.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context
                            .read<SuperAdminCompanyBloc>()
                            .add(LoadCompanies()),
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                );
              }
              if (state is CompaniesLoaded) {
                return _CompaniesTable(companies: state.companies);
              }
              return Center(child: CircularProgressIndicator.adaptive());
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Graphite header
// ---------------------------------------------------------------------------

class _GraphiteHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _GraphiteHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<SuperAdminCompanyBloc, SuperAdminCompanyState>(
      builder: (context, state) {
        final count = state is CompaniesLoaded ? state.companies.length : null;
        final title = count != null
            ? l10n.tenantsWithCount(count)
            : l10n.tenantsTitle;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.business_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: onRefresh,
                    tooltip: l10n.refresh,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (ctx) => FilledButton.icon(
                      onPressed: () => _showAddDialog(ctx),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        l10n.onboardButton,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: AppStyles.accentButtonStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    showAdaptiveDialog<void>(
      context: context,
      builder: (_) =>
          _CompanyFormDialog(bloc: context.read<SuperAdminCompanyBloc>()),
    );
  }
}

// ---------------------------------------------------------------------------
// Companies table
// ---------------------------------------------------------------------------

class _CompaniesTable extends StatelessWidget {
  final List<CompanyInfo> companies;
  const _CompaniesTable({required this.companies});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;
    final headerBg = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.surfaceVariant;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            // Column header row
            Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 4, child: _ColHeader(l10n.colHeaderCompany)),
                  Expanded(flex: 2, child: _ColHeader(l10n.colHeaderPlan)),
                  Expanded(flex: 2, child: _ColHeader(l10n.colHeaderDrivers)),
                  Expanded(
                    flex: 2,
                    child: _ColHeader(l10n.colHeaderRidesPerMonth),
                  ),
                  Expanded(flex: 2, child: _ColHeader(l10n.colHeaderStatus)),
                  const SizedBox(width: 72), // actions column
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            // Data rows
            Expanded(
              child: companies.isEmpty
                  ? Center(child: Text(l10n.noTenantsFound))
                  : ListView.separated(
                      itemCount: companies.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: borderColor),
                      itemBuilder: (context, i) => _CompanyRow(
                        company: companies[i],
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  final CompanyInfo company;
  final Color surfaceColor;
  final Color borderColor;
  const _CompanyRow({
    required this.company,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Company (avatar + name)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _CompanyAvatar(name: company.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        company.email,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Plan
          Expanded(flex: 2, child: _PlanBadge(plan: company.subscriptionPlan)),
          // Drivers — not provided by backend
          const Expanded(
            flex: 2,
            child: Text(
              '—',
              style: TextStyle(fontSize: 13),
              // TODO: driversCount not in CompanyResponse; add when backend supports it
            ),
          ),
          // Rides/mo — not provided by backend
          const Expanded(
            flex: 2,
            child: Text(
              '—',
              style: TextStyle(fontSize: 13),
              // TODO: ridesMonth not in CompanyResponse; add when backend supports it
            ),
          ),
          // Status badge
          Expanded(flex: 2, child: _StatusBadge(status: company.status)),
          // Actions
          SizedBox(
            width: 72,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  tooltip: l10n.editCompanyMenu,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => showAdaptiveDialog<void>(
                    context: context,
                    builder: (_) => _CompanyFormDialog(
                      bloc: context.read<SuperAdminCompanyBloc>(),
                      company: company,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: l10n.moreActions,
                  icon: const Icon(Icons.more_vert, size: 17),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(context, company);
                    } else {
                      context.read<SuperAdminCompanyBloc>().add(
                        UpdateCompanyStatus(company.id, val),
                      );
                    }
                  },
                  itemBuilder: (ctx) {
                    final l10n = AppLocalizations.of(ctx)!;
                    return [
                      PopupMenuItem(
                        value: 'Active',
                        child: Text(l10n.setActiveAction),
                      ),
                      PopupMenuItem(
                        value: 'Trial',
                        child: Text(l10n.setTrialAction),
                      ),
                      PopupMenuItem(
                        value: 'Suspended',
                        child: Text(l10n.suspendAction),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          l10n.deactivateAction,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, CompanyInfo c) {
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<SuperAdminCompanyBloc>();
    showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deactivateCompanyDialogTitle),
        content: Text(l10n.deactivateCompanyDialogContent(c.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              bloc.add(DeleteCompany(c.id));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.deactivateAction),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class _CompanyAvatar extends StatelessWidget {
  final String name;
  const _CompanyAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan badge
// ---------------------------------------------------------------------------

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  static const _colors = <String, Color>{
    'Enterprise': Color(0xFF6D28D9),
    'Professional': AppColors.accentDark,
    'Starter': Color(0xFF0891B2),
    'Free': AppColors.textSecondary,
    'Trial': Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[plan] ?? AppColors.textSecondary;
    return Text(
      plan,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge pill
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, border, text) = switch (status) {
      'Active' =>
        isDark
            ? (
                AppColors.rideCompletedBgDark,
                AppColors.rideCompletedBorder,
                AppColors.rideCompletedTextDark,
              )
            : (
                AppColors.successBg,
                AppColors.rideCompletedBorder,
                AppColors.successStrong,
              ),
      'Trial' =>
        isDark
            ? (
                AppColors.rideRequestedBgDark,
                AppColors.rideRequestedBorder,
                AppColors.rideRequestedTextDark,
              )
            : (
                AppColors.warningBg,
                AppColors.rideRequestedBorder,
                AppColors.warningStrong,
              ),
      'Suspended' =>
        isDark
            ? (
                AppColors.rideCancelledBgDark,
                AppColors.rideCancelledBorder,
                AppColors.rideCancelledTextDark,
              )
            : (
                AppColors.errorBg,
                AppColors.rideCancelledBorder,
                AppColors.errorStrong,
              ),
      _ => (
        isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        isDark ? AppColors.borderDark : AppColors.borderPrimary,
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final company = widget.company;
    if (company != null) {
      widget.bloc.add(
        UpdateCompany(
          companyId: company.id,
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        _isEdit ? l10n.editCompanyDialogTitle : l10n.onboardCompanyDialogTitle,
      ),
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
                  decoration: InputDecoration(labelText: l10n.companyName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(labelText: l10n.companyEmail),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(labelText: l10n.companyPhone),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(labelText: l10n.companyAddress),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: InputDecoration(labelText: l10n.statusLabel),
                  items: _statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _plan,
                  decoration: InputDecoration(
                    labelText: l10n.subscriptionPlanLabel,
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? l10n.save : l10n.createButton),
        ),
      ],
    );
  }
}
