import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/models/ride_template.dart';
import '../modules/core/models/person.dart';

class RideTemplatesScreen extends StatefulWidget {
  const RideTemplatesScreen({super.key});

  @override
  State<RideTemplatesScreen> createState() => _RideTemplatesScreenState();
}

class _RideTemplatesScreenState extends State<RideTemplatesScreen> {
  List<RideTemplate> _templates = [];
  List<Person> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final responses = await Future.wait([
        apiClient.get('/ride-templates'),
        apiClient.get('/users/clients'),
      ]);

      final templatesResponse = responses[0];
      final clientsResponse = responses[1];

      if (templatesResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(templatesResponse.body);
        _templates = data.map((e) => RideTemplate.fromJson(e)).toList();
      }

      if (clientsResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(clientsResponse.body);
        _clients = data.map((e) => Person.fromJson(e)).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deactivateTemplate(String templateId) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      await apiClient.delete('/ride-templates/$templateId');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _generateRides(String templateId) async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (dateRange == null || !mounted) return;

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient
          .post('/ride-templates/$templateId/generate', {
            'from': dateRange.start.toUtc().toIso8601String(),
            'to': dateRange.end.toUtc().toIso8601String(),
          });

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rides generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate rides: ${response.body}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final timeController = TextEditingController(text: '08:00');
    final notesController = TextEditingController();
    final priceController = TextEditingController();
    final apiClient = context.read<AuthBloc>().apiClient;
    final messenger = ScaffoldMessenger.of(context);
    String? selectedClientId;
    String recurrencePattern = 'Daily';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Template'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template Name',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Client'),
                      initialValue: selectedClientId,
                      items: _clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedClientId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: fromController,
                      decoration: const InputDecoration(
                        labelText: 'From Address',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: toController,
                      decoration: const InputDecoration(
                        labelText: 'To Address',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Pickup Time (HH:mm)',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Recurrence',
                      ),
                      initialValue: recurrencePattern,
                      items: const [
                        DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'Weekdays',
                          child: Text('Weekdays'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Mon',
                          child: Text('Weekly Monday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Tue',
                          child: Text('Weekly Tuesday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Wed',
                          child: Text('Weekly Wednesday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Thu',
                          child: Text('Weekly Thursday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Fri',
                          child: Text('Weekly Friday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Sat',
                          child: Text('Weekly Saturday'),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly-Sun',
                          child: Text('Weekly Sunday'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(
                        () => recurrencePattern = v ?? 'Daily',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (optional)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final navigator = Navigator.of(ctx);
                final request = CreateRideTemplateRequest(
                  name: nameController.text,
                  clientId: selectedClientId!,
                  fromAddress: fromController.text,
                  toAddress: toController.text,
                  pickupTime: timeController.text,
                  recurrencePattern: recurrencePattern,
                  notes: notesController.text.isNotEmpty
                      ? notesController.text
                      : null,
                  price: priceController.text.isNotEmpty
                      ? double.tryParse(priceController.text)
                      : null,
                );

                try {
                  final response = await apiClient.post(
                    '/ride-templates',
                    request.toJson(),
                  );

                  if (!mounted) return;
                  navigator.pop();
                  if (response.statusCode == 200 ||
                      response.statusCode == 201) {
                    _loadData();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed: ${response.body}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: 14,
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Expanded(
                child: const Text(
                  'Saved templates',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 22),
                onPressed: _showCreateDialog,
                tooltip: 'Add template',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No templates yet',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a template to schedule recurring rides',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add template'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: _TemplateListCard(
        templates: _templates,
        clients: _clients,
        onGenerate: _generateRides,
        onDeactivate: _deactivateTemplate,
      ),
    );
  }
}

// ─── Template List Card ───────────────────────────────────────────────────────

class _TemplateListCard extends StatelessWidget {
  final List<RideTemplate> templates;
  final List<Person> clients;
  final void Function(String) onGenerate;
  final void Function(String) onDeactivate;

  const _TemplateListCard({
    required this.templates,
    required this.clients,
    required this.onGenerate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowXs,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: templates.asMap().entries.map((entry) {
              final i = entry.key;
              final template = entry.value;
              final clientName =
                  clients
                      .where((c) => c.id == template.clientId)
                      .map((c) => c.name)
                      .firstOrNull ??
                  'Unknown';
              return _TemplateRow(
                template: template,
                clientName: clientName,
                isLast: i == templates.length - 1,
                onGenerate: () => onGenerate(template.id),
                onDeactivate: () => onDeactivate(template.id),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final RideTemplate template;
  final String clientName;
  final bool isLast;
  final VoidCallback onGenerate;
  final VoidCallback onDeactivate;

  const _TemplateRow({
    required this.template,
    required this.clientName,
    required this.isLast,
    required this.onGenerate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAirport = template.isAirportTransfer;

    // Icon box: accent-tint for airport/active, surfaceVariant otherwise
    final iconBgColor = (isAirport || template.isActive)
        ? AppColors.accent.withValues(alpha: 0.12)
        : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant);
    final iconColor = (isAirport || template.isActive)
        ? AppColors.accent
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    final scheduleLabel =
        '${template.recurrencePattern} ${template.pickupTime}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon box 36px
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAirport ? Icons.flight : Icons.repeat,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              // Name + schedule
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$scheduleLabel · $clientName',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textLightDark
                            : AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge + actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TemplateBadge(isActive: template.isActive),
                  const SizedBox(width: 4),
                  _TemplateActionsMenu(
                    onGenerate: onGenerate,
                    onDeactivate: onDeactivate,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.borderDark : const Color(0xFFF4F4F5),
            indent: 18,
            endIndent: 18,
          ),
      ],
    );
  }
}

class _TemplateBadge extends StatelessWidget {
  final bool isActive;

  const _TemplateBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isActive) {
      return _badge(
        label: 'Active',
        bg: isDark ? AppColors.rideCompletedBgDark : const Color(0xFFF0FDF4),
        border: isDark
            ? AppColors.rideCompletedBgDark
            : const Color(0xFF86EFAC),
        fg: isDark ? AppColors.rideCompletedTextDark : const Color(0xFF166534),
      );
    }
    return _badge(
      label: 'Paused',
      bg: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF4F4F5),
      border: isDark ? AppColors.borderDark : const Color(0xFFE4E4E7),
      fg: isDark ? AppColors.textSecondaryDark : const Color(0xFFA1A1AA),
    );
  }

  Widget _badge({
    required String label,
    required Color bg,
    required Color border,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _TemplateActionsMenu extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback onDeactivate;

  const _TemplateActionsMenu({
    required this.onGenerate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (value) {
        if (value == 'generate') onGenerate();
        if (value == 'deactivate') onDeactivate();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'generate',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 16),
              SizedBox(width: 8),
              Text('Generate rides'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'deactivate',
          child: Row(
            children: [
              Icon(Icons.block, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Deactivate', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
