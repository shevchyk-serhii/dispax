import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';

class RidePoolScreen extends StatefulWidget {
  const RidePoolScreen({super.key});

  @override
  State<RidePoolScreen> createState() => _RidePoolScreenState();
}

class _RidePoolScreenState extends State<RidePoolScreen> {
  List<Map<String, dynamic>> _pools = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPools();
  }

  Future<void> _loadPools() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/pools');
      setState(() {
        _pools = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showCreatePoolDialog() async {
    final nameCtrl = TextEditingController();
    final directionCtrl = TextEditingController();
    int maxPassengers = 4;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.group_add, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Create Ride Pool'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pool Name (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Airport Morning Shuttle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: directionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Route Direction (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., City Center → Airport',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Max Passengers:', style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        onPressed: maxPassengers > 2
                            ? () => setDialogState(() => maxPassengers--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$maxPassengers',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: maxPassengers < 8
                            ? () => setDialogState(() => maxPassengers++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final apiClient = this.context.read<AuthBloc>().apiClient;
                  await apiClient.post('/pools', {
                    if (nameCtrl.text.isNotEmpty) 'name': nameCtrl.text,
                    'maxPassengers': maxPassengers,
                    if (directionCtrl.text.isNotEmpty)
                      'routeDirection': directionCtrl.text,
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadPools();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride pool created')),
        );
      }
    }
  }

  Future<void> _showPoolDetails(Map<String, dynamic> pool) async {
    final poolId = pool['id']?['value'] ?? pool['id'] ?? '';

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/pools/$poolId');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final members =
          (data['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.group, color: _poolStatusColor(pool['status'] ?? '')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pool['name'] ?? 'Pool ${_shortId(poolId.toString())}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Status', pool['status'] ?? 'OPEN'),
                _detailRow(
                    'Passengers',
                    '${pool['currentPassengers'] ?? 0}/${pool['maxPassengers'] ?? 4}'),
                if (pool['routeDirection'] != null)
                  _detailRow('Route', pool['routeDirection']),
                if (pool['driverId'] != null)
                  _detailRow('Driver',
                      _shortId((pool['driverId']?['value'] ?? pool['driverId']).toString())),
                const Divider(),
                const Text('Members:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  Text('No rides in this pool yet',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))
                else
                  ...members.map((m) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: _memberStatusColor(
                                  m['status'] ?? 'Pending')
                              .withAlpha(30),
                          child: Text('${(m['pickupOrder'] ?? 0) + 1}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text(
                          'Ride: ${_shortId((m['rideId']?['value'] ?? m['rideId'] ?? '').toString())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(m['status'] ?? 'Pending',
                            style: TextStyle(
                                fontSize: 11,
                                color: _memberStatusColor(
                                    m['status'] ?? 'Pending'))),
                      )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pool details: $e')),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!),
                          ElevatedButton(
                              onPressed: _loadPools,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _pools.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_off,
                                  size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                              const SizedBox(height: 12),
                              Text('No ride pools',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Text('Create a pool to combine rides',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.outlineVariant)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPools,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _pools.length,
                            itemBuilder: (context, index) =>
                                _buildPoolCard(_pools[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.groups, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ride Pools',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Colors.white, size: 24),
              onPressed: _showCreatePoolDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadPools,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolCard(Map<String, dynamic> pool) {
    final name = pool['name'] as String?;
    final status = pool['status'] as String? ?? 'Open';
    final current = pool['currentPassengers'] as int? ?? 0;
    final max = pool['maxPassengers'] as int? ?? 4;
    final direction = pool['routeDirection'] as String?;
    final poolId = pool['id']?['value'] ?? pool['id'] ?? '';
    final driverId = pool['driverId']?['value'] ?? pool['driverId'];
    final createdAt = pool['createdAt'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _poolStatusColor(status).withAlpha(60)),
      ),
      child: InkWell(
        onTap: () => _showPoolDetails(pool),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups, color: _poolStatusColor(status), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name ?? 'Pool ${_shortId(poolId.toString())}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _poolStatusColor(status).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _poolStatusColor(status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Passenger progress bar
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('$current/$max',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: max > 0 ? current / max : 0,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          current >= max ? AppColors.error : AppColors.success,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (direction != null)
                Row(
                  children: [
                    Icon(Icons.route, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(direction,
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              if (driverId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.drive_eta,
                          size: 14, color: AppColors.driverColor),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: ${_shortId(driverId.toString())}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.driverColor),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _poolStatusColor(String status) {
    switch (status) {
      case 'Open':
        return AppColors.success;
      case 'Full':
        return AppColors.warning;
      case 'InProgress':
        return AppColors.info;
      case 'Completed':
        return AppColors.textSecondary;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _memberStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return AppColors.success;
      case 'PickedUp':
        return AppColors.info;
      case 'DroppedOff':
        return AppColors.textSecondary;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
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
