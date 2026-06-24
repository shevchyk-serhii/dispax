import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';

class EmergencyReassignmentScreen extends StatefulWidget {
  const EmergencyReassignmentScreen({super.key});

  @override
  State<EmergencyReassignmentScreen> createState() =>
      _EmergencyReassignmentScreenState();
}

class _EmergencyReassignmentScreenState
    extends State<EmergencyReassignmentScreen> {
  List<Map<String, dynamic>> _reassignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReassignments();
  }

  Future<void> _loadReassignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/emergency/reassignments');
      setState(() {
        _reassignments = (jsonDecode(resp.body) as List)
            .cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _reasonLabel(BuildContext context, String reason) {
    final l10n = AppLocalizations.of(context)!;
    switch (reason) {
      case 'DriverIllness':
        return l10n.emergencyReasonDriverIllness;
      case 'VehicleBreakdown':
        return l10n.emergencyReasonVehicleBreakdown;
      case 'DriverNoShow':
        return l10n.emergencyReasonDriverNoShow;
      case 'Accident':
        return l10n.emergencyReasonAccident;
      case 'PersonalEmergency':
        return l10n.emergencyReasonPersonalEmergency;
      default:
        return l10n.emergencyReasonOther;
    }
  }

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final rideIdCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final newDriverIdCtrl = TextEditingController();
    String selectedReason = 'DriverIllness';
    List<Map<String, dynamic>> suggestedDrivers = [];

    final reasons = [
      'DriverIllness',
      'VehicleBreakdown',
      'DriverNoShow',
      'Accident',
      'PersonalEmergency',
      'Other',
    ];

    final reasonLabels = {
      'DriverIllness': l10n.emergencyReasonDriverIllness,
      'VehicleBreakdown': l10n.emergencyReasonVehicleBreakdown,
      'DriverNoShow': l10n.emergencyReasonDriverNoShow,
      'Accident': l10n.emergencyReasonAccident,
      'PersonalEmergency': l10n.emergencyReasonPersonalEmergency,
      'Other': l10n.emergencyReasonOther,
    };

    final reasonIcons = {
      'DriverIllness': Icons.sick,
      'VehicleBreakdown': Icons.car_crash,
      'DriverNoShow': Icons.person_off,
      'Accident': Icons.warning,
      'PersonalEmergency': Icons.emergency,
      'Other': Icons.more_horiz,
    };

    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.emergencyReassignmentDialogTitle),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: rideIdCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.rideIdLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: () async {
                          if (rideIdCtrl.text.isEmpty) return;
                          try {
                            final apiClient = this.context
                                .read<AuthBloc>()
                                .apiClient;
                            final resp = await apiClient.get(
                              '/emergency/suggest-drivers/${rideIdCtrl.text}',
                            );
                            setDialogState(() {
                              suggestedDrivers = (jsonDecode(resp.body) as List)
                                  .cast<Map<String, dynamic>>();
                            });
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      dialogContext,
                                    )!.genericError(e.toString()),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      labelText: l10n.emergencyReasonLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: reasons
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                Icon(reasonIcons[r], size: 20),
                                const SizedBox(width: 8),
                                Text(reasonLabels[r]!),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedReason = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (suggestedDrivers.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.availableDriversLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...suggestedDrivers.map((d) {
                      final isPreferred = d['isPreferred'] == 'true';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isPreferred
                              ? AppColors.warning.withAlpha(30)
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            isPreferred ? Icons.star : Icons.person,
                            size: 16,
                            color: isPreferred
                                ? AppColors.warning
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          d['name'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          d['phone'] ?? '',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isPreferred
                            ? const Text(
                                'Preferred',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                        onTap: () {
                          setDialogState(() {
                            newDriverIdCtrl.text = d['id'] ?? '';
                          });
                        },
                        selected: newDriverIdCtrl.text == d['id'],
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(15),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: newDriverIdCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.newDriverIdLabel,
                      border: const OutlineInputBorder(),
                      helperText: l10n.newDriverIdHelper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.notesOptionalLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (rideIdCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(dialogContext)!.rideIdRequired,
                      ),
                    ),
                  );
                  return;
                }
                try {
                  final apiClient = this.context.read<AuthBloc>().apiClient;
                  await apiClient.post('/emergency/reassign', {
                    'rideId': rideIdCtrl.text,
                    'reason': selectedReason,
                    if (newDriverIdCtrl.text.isNotEmpty)
                      'newDriverId': newDriverIdCtrl.text,
                    if (notesCtrl.text.isNotEmpty) 'notes': notesCtrl.text,
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            dialogContext,
                          )!.genericError(e.toString()),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.emergency, size: 18),
              label: Text(l10n.reassignButton),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadReassignments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.emergencyReassignmentCreated,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildHeader(l10n),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _loadReassignments,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : _reassignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emergency,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noEmergencyReassignments,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReassignments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _reassignments.length,
                    itemBuilder: (context, index) =>
                        _buildReassignmentCard(_reassignments[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.errorStrong, AppColors.error],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.emergencyReassignmentTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _showCreateDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadReassignments,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReassignmentCard(Map<String, dynamic> r) {
    final l10n = AppLocalizations.of(context)!;
    final reason = r['reason'] as String? ?? 'Unknown';
    final status = r['status'] as String? ?? 'PENDING';
    final notes = r['notes'] as String?;
    final createdAt = r['createdAt'] as String? ?? '';
    final originalDriverId =
        r['originalDriverId']?['value'] ?? r['originalDriverId'] ?? '';
    final newDriverId = r['newDriverId']?['value'] ?? r['newDriverId'];
    final rideId = r['rideId']?['value'] ?? r['rideId'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _statusColor(status).withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_reasonIcon(reason), color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _reasonLabel(context, reason),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emergencyRideLabel(_shortId(rideId.toString())),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              l10n.emergencyOriginalDriverLabel(
                _shortId(originalDriverId.toString()),
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (newDriverId != null)
              Text(
                l10n.emergencyNewDriverLabel(_shortId(newDriverId.toString())),
                style: const TextStyle(fontSize: 12, color: AppColors.success),
              ),
            if (notes != null && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _reasonIcon(String reason) {
    switch (reason) {
      case 'DriverIllness':
        return Icons.sick;
      case 'VehicleBreakdown':
        return Icons.car_crash;
      case 'DriverNoShow':
        return Icons.person_off;
      case 'Accident':
        return Icons.warning;
      case 'PersonalEmergency':
        return Icons.emergency;
      default:
        return Icons.more_horiz;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'REASSIGNED':
        return AppColors.success;
      case 'CANCELLED':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _shortId(String id) {
    if (id.length > 8) return '${id.substring(0, 8)}...';
    return id;
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
