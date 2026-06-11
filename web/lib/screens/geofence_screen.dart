import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/models/geofence.dart';

class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Geofence> _geofences = [];
  List<GeofenceAlert> _alerts = [];
  bool _isLoadingGeofences = true;
  bool _isLoadingAlerts = true;
  String? _geofenceError;
  String? _alertError;
  String _alertFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGeofences();
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGeofences() async {
    setState(() {
      _isLoadingGeofences = true;
      _geofenceError = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/geofences');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          _geofences = jsonList.map((j) => Geofence.fromJson(j)).toList();
          _isLoadingGeofences = false;
        });
      } else {
        setState(() {
          _geofenceError = 'Failed to load geofences (${response.statusCode})';
          _isLoadingGeofences = false;
        });
      }
    } catch (e) {
      setState(() {
        _geofenceError = e.toString();
        _isLoadingGeofences = false;
      });
    }
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
      _alertError = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/geofences/alerts?limit=20');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          _alerts = jsonList.map((j) => GeofenceAlert.fromJson(j)).toList();
          _isLoadingAlerts = false;
        });
      } else {
        setState(() {
          _alertError = 'Failed to load alerts (${response.statusCode})';
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      setState(() {
        _alertError = e.toString();
        _isLoadingAlerts = false;
      });
    }
  }

  Future<void> _deleteGeofence(String id) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.delete('/geofences/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _geofences.removeWhere((g) => g.id == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geofence deleted')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _createGeofence(CreateGeofenceRequest request) async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.post('/geofences', request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadGeofences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geofence created')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create geofence (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedType = 'Airport';
    double radiusMeters = 500;
    bool notifyOnEntry = true;
    bool notifyOnExit = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Geofence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Airport', child: Text('Airport')),
                    DropdownMenuItem(value: 'ServiceArea', child: Text('Service Area')),
                    DropdownMenuItem(value: 'ClientPickup', child: Text('Client Pickup')),
                    DropdownMenuItem(value: 'CustomZone', child: Text('Custom Zone')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radius: ${radiusMeters.toInt()}m',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Slider(
                      value: radiusMeters,
                      min: 100,
                      max: 10000,
                      divisions: 99,
                      label: '${radiusMeters.toInt()}m',
                      onChanged: (v) => setDialogState(() => radiusMeters = v),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Notify on entry', style: TextStyle(fontSize: 14)),
                  value: notifyOnEntry,
                  onChanged: (v) => setDialogState(() => notifyOnEntry = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Notify on exit', style: TextStyle(fontSize: 14)),
                  value: notifyOnExit,
                  onChanged: (v) => setDialogState(() => notifyOnExit = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final lat = double.tryParse(latController.text.trim());
                final lng = double.tryParse(lngController.text.trim());

                if (name.isEmpty || lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _createGeofence(CreateGeofenceRequest(
                  name: name,
                  geofenceType: selectedType,
                  centerLatitude: lat,
                  centerLongitude: lng,
                  radiusMeters: radiusMeters.toInt(),
                  notifyOnEntry: notifyOnEntry,
                  notifyOnExit: notifyOnExit,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Airport':
        return Icons.flight;
      case 'ServiceArea':
        return Icons.fence;
      case 'ClientPickup':
        return Icons.person_pin_circle;
      case 'CustomZone':
        return Icons.my_location;
      default:
        return Icons.location_on;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Airport':
        return AppColors.info;
      case 'ServiceArea':
        return AppColors.success;
      case 'ClientPickup':
        return AppColors.warning;
      case 'CustomZone':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.dispatcherColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppColors.dispatcherColor,
          tabs: const [
            Tab(text: 'Geofences'),
            Tab(text: 'Recent Alerts'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeofenceList(),
              _buildAlertsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.share_location, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Geofencing',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: () {
                _loadGeofences();
                _loadAlerts();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceList() {
    if (_isLoadingGeofences) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_geofenceError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_geofenceError!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadGeofences, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_geofences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_location, size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No geofences yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Geofence'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadGeofences,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _geofences.length,
            itemBuilder: (context, index) {
              final geofence = _geofences[index];
              final typeColor = _getTypeColor(geofence.geofenceType);

              return Dismissible(
                key: ValueKey(geofence.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Geofence'),
                      content: Text('Delete "${geofence.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ) ?? false;
                },
                onDismissed: (_) => _deleteGeofence(geofence.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: typeColor.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: Icon(_getTypeIcon(geofence.geofenceType), color: typeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              geofence.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${geofence.geofenceType} - ${geofence.radiusMeters}m radius',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (geofence.notifyOnEntry)
                                Tooltip(
                                  message: 'Entry notifications',
                                  child: Icon(Icons.arrow_downward, size: 16, color: AppColors.success),
                                ),
                              if (geofence.notifyOnExit)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Tooltip(
                                    message: 'Exit notifications',
                                    child: Icon(Icons.arrow_upward, size: 16, color: AppColors.error),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: geofence.isActive ? AppColors.success.withAlpha(25) : Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              geofence.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: geofence.isActive ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
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
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showCreateDialog,
            backgroundColor: AppColors.dispatcherColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsList() {
    if (_isLoadingAlerts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alertError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_alertError!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadAlerts, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filteredAlerts = _alertFilter == 'All'
        ? _alerts
        : _alerts.where((a) => a.alertType == _alertFilter.toLowerCase()).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Text('Filter:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _alertFilter == 'All',
                onSelected: (_) => setState(() => _alertFilter = 'All'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Entry'),
                selected: _alertFilter == 'Entry',
                onSelected: (_) => setState(() => _alertFilter = 'Entry'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Exit'),
                selected: _alertFilter == 'Exit',
                onSelected: (_) => setState(() => _alertFilter = 'Exit'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredAlerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 56, color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text('No alerts found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = filteredAlerts[index];
                      final isEntry = alert.alertType == 'entry';
                      final color = isEntry ? AppColors.success : AppColors.error;
                      final icon = isEntry ? Icons.arrow_downward : Icons.arrow_upward;
                      final text = isEntry
                          ? 'Driver entered ${alert.geofenceName}'
                          : 'Driver left ${alert.geofenceName}';

                      final driverLabel = alert.driverId.length > 8
                          ? '${alert.driverId.substring(0, 8)}...'
                          : alert.driverId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 18),
                                ),
                                if (index < filteredAlerts.length - 1)
                                  Container(width: 2, height: 40, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Driver: $driverLabel',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                    Text(
                                      _formatTimestamp(alert.createdAt),
                                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
