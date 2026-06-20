import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_styles.dart';
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

  // Optimistic toggle state: tracks geofence IDs that are being toggled
  final Set<String> _togglingIds = {};

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

  // ── API calls ─────────────────────────────────────────────────────────────

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

  Future<void> _toggleGeofence(Geofence geofence) async {
    // Optimistic update
    setState(() {
      _togglingIds.add(geofence.id);
      final idx = _geofences.indexWhere((g) => g.id == geofence.id);
      if (idx >= 0) {
        // Replace with a toggled copy — Geofence is immutable so rebuild list
        final toggled = Geofence(
          id: geofence.id,
          companyId: geofence.companyId,
          name: geofence.name,
          geofenceType: geofence.geofenceType,
          centerLatitude: geofence.centerLatitude,
          centerLongitude: geofence.centerLongitude,
          radiusMeters: geofence.radiusMeters,
          isActive: !geofence.isActive,
          notifyOnEntry: geofence.notifyOnEntry,
          notifyOnExit: geofence.notifyOnExit,
          createdAt: geofence.createdAt,
        );
        _geofences = List.from(_geofences)..[idx] = toggled;
      }
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final action = geofence.isActive ? 'deactivate' : 'activate';
      // TODO: replace with real PATCH /geofences/:id/toggle or similar
      // when backend endpoint exists.
      final response = await apiClient.post(
        '/geofences/${geofence.id}/$action',
        {},
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        // Revert optimistic update on error
        await _loadGeofences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to toggle geofence (${response.statusCode})',
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Revert on exception
      await _loadGeofences();
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(geofence.id));
      }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Geofence deleted')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Geofence created')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to create geofence (${response.statusCode})',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Create dialog ─────────────────────────────────────────────────────────

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
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMedium,
                    vertical: AppDimensions.paddingMedium,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_location_alt_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Create Geofence',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: AppStyles.textFieldDecoration(
                            labelText: 'Zone name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: AppStyles.textFieldDecoration(
                            labelText: 'Type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Airport',
                              child: Text('Airport'),
                            ),
                            DropdownMenuItem(
                              value: 'ServiceArea',
                              child: Text('Service Area'),
                            ),
                            DropdownMenuItem(
                              value: 'ClientPickup',
                              child: Text('Client Pickup'),
                            ),
                            DropdownMenuItem(
                              value: 'CustomZone',
                              child: Text('Custom Zone'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedType = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: latController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: AppStyles.textFieldDecoration(
                                  labelText: 'Latitude',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: lngController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: AppStyles.textFieldDecoration(
                                  labelText: 'Longitude',
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Slider(
                              value: radiusMeters,
                              min: 100,
                              max: 10000,
                              divisions: 99,
                              label: '${radiusMeters.toInt()}m',
                              activeColor: AppColors.accent,
                              onChanged: (v) =>
                                  setDialogState(() => radiusMeters = v),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Notify on entry',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: notifyOnEntry,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) =>
                              setDialogState(() => notifyOnEntry = v),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Notify on exit',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: notifyOnExit,
                          activeThumbColor: AppColors.accent,
                          onChanged: (v) =>
                              setDialogState(() => notifyOnExit = v),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: AppStyles.textButtonStyle,
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: AppStyles.accentButtonStyle,
                        onPressed: () {
                          final name = nameController.text.trim();
                          final lat = double.tryParse(
                            latController.text.trim(),
                          );
                          final lng = double.tryParse(
                            lngController.text.trim(),
                          );

                          if (name.isEmpty || lat == null || lng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill in all required fields',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          _createGeofence(
                            CreateGeofenceRequest(
                              name: name,
                              geofenceType: selectedType,
                              centerLatitude: lat,
                              centerLongitude: lng,
                              radiusMeters: radiusMeters.toInt(),
                              notifyOnEntry: notifyOnEntry,
                              notifyOnExit: notifyOnExit,
                            ),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Type helpers ──────────────────────────────────────────────────────────

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
        return const Color(0xFF22C55E);
      case 'ClientPickup':
        return AppColors.warning;
      case 'CustomZone':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTypeSubtitle(String type, int radiusMeters) {
    final radius = '${radiusMeters}m radius';
    switch (type) {
      case 'Airport':
        return 'Airport zone · $radius';
      case 'ServiceArea':
        return 'Service area · $radius';
      case 'ClientPickup':
        return 'Client pickup point · $radius';
      case 'CustomZone':
        return 'Custom zone · $radius';
      default:
        return radius;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildHeader(isDark),
        // Tab bar
        Container(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Zones'),
              Tab(text: 'Recent Alerts'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildGeofenceList(isDark), _buildAlertsList(isDark)],
          ),
        ),
      ],
    );
  }

  // ── Graphite header ───────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingMedium,
              AppDimensions.paddingMedium,
              AppDimensions.paddingSmall,
              AppDimensions.paddingMedium,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.share_location_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Geofences',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'Add geofence',
                  onPressed: _showCreateDialog,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Refresh',
                  onPressed: () {
                    _loadGeofences();
                    _loadAlerts();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Geofence list ─────────────────────────────────────────────────────────

  Widget _buildGeofenceList(bool isDark) {
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
            FilledButton(
              style: AppStyles.accentButtonStyle,
              onPressed: _loadGeofences,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_geofences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share_location,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No geofence zones yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create zones to monitor driver entry and exit events',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: AppStyles.accentButtonStyle,
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create zone'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGeofences,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        itemCount: _geofences.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final geofence = _geofences[index];
          return _buildZoneRow(geofence, isDark);
        },
      ),
    );
  }

  // ── Zone row — dot + name + action subtitle + toggle ──────────────────────

  Widget _buildZoneRow(Geofence geofence, bool isDark) {
    final typeColor = _getTypeColor(geofence.geofenceType);
    final isToggling = _togglingIds.contains(geofence.id);

    return Dismissible(
      key: ValueKey(geofence.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete zone'),
                content: Text('Delete "${geofence.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _deleteGeofence(geofence.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
        ),
        child: Row(
          children: [
            // Coloured dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: geofence.isActive ? typeColor : AppColors.textLight,
                shape: BoxShape.circle,
              ),
            ),

            // Type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: geofence.isActive
                    ? typeColor.withValues(alpha: 0.1)
                    : (isDark
                          ? AppColors.surfaceVariantDark
                          : AppColors.surfaceVariant),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Icon(
                _getTypeIcon(geofence.geofenceType),
                color: geofence.isActive ? typeColor : AppColors.textLight,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    geofence.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: geofence.isActive
                          ? (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary)
                          : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getTypeSubtitle(
                      geofence.geofenceType,
                      geofence.radiusMeters,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  // Notification indicators
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (geofence.notifyOnEntry)
                        _notifyChip(
                          'Entry',
                          Icons.arrow_downward,
                          AppColors.success,
                        ),
                      if (geofence.notifyOnEntry && geofence.notifyOnExit)
                        const SizedBox(width: 4),
                      if (geofence.notifyOnExit)
                        _notifyChip(
                          'Exit',
                          Icons.arrow_upward,
                          AppColors.error,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Toggle
            isToggling
                ? const SizedBox(
                    width: 36,
                    height: 20,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Switch(
                    value: geofence.isActive,
                    activeThumbColor: AppColors.accent,
                    onChanged: (_) => _toggleGeofence(geofence),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _notifyChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts list ───────────────────────────────────────────────────────────

  Widget _buildAlertsList(bool isDark) {
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
            FilledButton(
              style: AppStyles.accentButtonStyle,
              onPressed: _loadAlerts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredAlerts = _alertFilter == 'All'
        ? _alerts
        : _alerts
              .where((a) => a.alertType == _alertFilter.toLowerCase())
              .toList();

    return Column(
      children: [
        // Filter chips bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariant,
          child: Row(
            children: [
              Text(
                'Filter:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              ...['All', 'Entry', 'Exit'].map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _alertFilter == f,
                    selectedColor: AppColors.accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _alertFilter == f
                          ? AppColors.accent
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary),
                    ),
                    side: BorderSide(
                      color: _alertFilter == f
                          ? AppColors.accent
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderPrimary),
                    ),
                    onSelected: (_) => setState(() => _alertFilter = f),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredAlerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No alerts found',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMedium,
                      vertical: AppDimensions.paddingMedium,
                    ),
                    itemCount: filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = filteredAlerts[index];
                      return _buildAlertRow(
                        alert,
                        index,
                        filteredAlerts.length,
                        isDark,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlertRow(
    GeofenceAlert alert,
    int index,
    int total,
    bool isDark,
  ) {
    final isEntry = alert.alertType == 'entry';
    final color = isEntry ? AppColors.success : AppColors.error;
    final icon = isEntry ? Icons.arrow_downward : Icons.arrow_upward;
    final text = isEntry
        ? 'Driver entered ${alert.geofenceName}'
        : 'Driver left ${alert.geofenceName}';

    final driverLabel = alert.driverId.length > 8
        ? '${alert.driverId.substring(0, 8)}…'
        : alert.driverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + connector
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              if (index < total - 1)
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2),
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderPrimary,
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Alert card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderPrimary,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Driver: $driverLabel',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _formatTimestamp(alert.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textLightDark
                          : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
