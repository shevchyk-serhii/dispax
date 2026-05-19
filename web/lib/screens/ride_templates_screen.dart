import 'dart:convert';
import 'package:flutter/material.dart';
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
      await apiClient.put('/ride-templates/$templateId/deactivate', {});
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deactivate: $e'), backgroundColor: AppColors.error),
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
      final response = await apiClient.post('/ride-templates/$templateId/generate', {
        'from': dateRange.start.toUtc().toIso8601String(),
        'to': dateRange.end.toUtc().toIso8601String(),
      });

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rides generated successfully'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate rides: ${response.body}'), backgroundColor: AppColors.error),
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
                      decoration: const InputDecoration(labelText: 'Template Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Client'),
                      value: selectedClientId,
                      items: _clients.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedClientId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: fromController,
                      decoration: const InputDecoration(labelText: 'From Address'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: toController,
                      decoration: const InputDecoration(labelText: 'To Address'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: timeController,
                      decoration: const InputDecoration(labelText: 'Pickup Time (HH:mm)'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Recurrence'),
                      value: recurrencePattern,
                      items: const [
                        DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'Weekdays', child: Text('Weekdays')),
                        DropdownMenuItem(value: 'Weekly-Mon', child: Text('Weekly Monday')),
                        DropdownMenuItem(value: 'Weekly-Tue', child: Text('Weekly Tuesday')),
                        DropdownMenuItem(value: 'Weekly-Wed', child: Text('Weekly Wednesday')),
                        DropdownMenuItem(value: 'Weekly-Thu', child: Text('Weekly Thursday')),
                        DropdownMenuItem(value: 'Weekly-Fri', child: Text('Weekly Friday')),
                        DropdownMenuItem(value: 'Weekly-Sat', child: Text('Weekly Saturday')),
                        DropdownMenuItem(value: 'Weekly-Sun', child: Text('Weekly Sunday')),
                      ],
                      onChanged: (v) => setDialogState(() => recurrencePattern = v ?? 'Daily'),
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppDimensions.paddingSmall),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price (optional)'),
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

                final request = CreateRideTemplateRequest(
                  name: nameController.text,
                  clientId: selectedClientId!,
                  fromAddress: fromController.text,
                  toAddress: toController.text,
                  pickupTime: timeController.text,
                  recurrencePattern: recurrencePattern,
                  notes: notesController.text.isNotEmpty ? notesController.text : null,
                  price: priceController.text.isNotEmpty ? double.tryParse(priceController.text) : null,
                );

                try {
                  final response = await apiClient.post('/ride-templates', request.toJson());

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  if (response.statusCode == 200 || response.statusCode == 201) {
                    _loadData();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: AppColors.error),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secretaryColor,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.secretaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.secretaryGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.repeat, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ride Templates',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadData,
            ),
          ],
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
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final activeTemplates = _templates.where((t) => t.isActive).toList();

    if (activeTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No active templates',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a template to schedule recurring rides',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        itemCount: activeTemplates.length,
        itemBuilder: (context, index) {
          final template = activeTemplates[index];
          final clientName = _clients
              .where((c) => c.id == template.clientId)
              .map((c) => c.name)
              .firstOrNull ?? 'Unknown';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secretaryColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          template.recurrencePattern,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secretaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(clientName, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(template.pickupTime, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${template.fromAddress} -> ${template.toAddress}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (template.price != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.euro, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          template.price!.toStringAsFixed(2),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _generateRides(template.id),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Generate Rides'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secretaryColor,
                            side: const BorderSide(color: AppColors.secretaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deactivateTemplate(template.id),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Deactivate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
