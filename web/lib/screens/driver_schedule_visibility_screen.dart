import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../modules/core/models/person.dart';
import '../modules/core/services/api_client.dart';
import '../modules/schedule_management/services/schedule_service.dart';
import '../constants/app_colors.dart';

/// Dispatcher/Admin screen: manage which drivers may view other drivers' full
/// schedules. Each driver gets a toggle switch; changes are saved immediately
/// via PUT /api/schedules/visibility/{driverId}.
class DriverScheduleVisibilityScreen extends StatefulWidget {
  const DriverScheduleVisibilityScreen({super.key});

  @override
  State<DriverScheduleVisibilityScreen> createState() =>
      _DriverScheduleVisibilityScreenState();
}

class _DriverScheduleVisibilityScreenState
    extends State<DriverScheduleVisibilityScreen> {
  late final ScheduleService _scheduleService;
  late final ApiClient _apiClient;

  List<Person> _drivers = [];

  /// driverId → canViewOtherSchedules flag (populated from API; absent = false)
  Map<String, bool> _visibilityMap = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use the authenticated ApiClient from AuthBloc — never instantiate a new
    // ApiClient() directly (it would be missing the auth token → 401).
    _apiClient = context.read<AuthBloc>().apiClient;
    _scheduleService = ScheduleService(apiClient: _apiClient);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final driversResponse = await _apiClient.get('/users/drivers');
      final List<Person> drivers;
      if (driversResponse.statusCode == 200) {
        final List<dynamic> raw =
            jsonDecode(driversResponse.body) as List<dynamic>;
        drivers =
            raw
                .map((j) => Person.fromJson(j as Map<String, dynamic>))
                .toList();
      } else {
        drivers = [];
      }

      final visibilityList = await _scheduleService.getCompanyVisibility();
      final Map<String, bool> visMap = {};
      for (final v in visibilityList) {
        final id = v['driverId']?.toString() ?? '';
        if (id.isNotEmpty) {
          visMap[id] = (v['canViewOtherSchedules'] as bool?) ?? false;
        }
      }

      if (mounted) {
        setState(() {
          _drivers = drivers;
          _visibilityMap = visMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _setVisibility(String driverId, bool canView) async {
    final previous = _visibilityMap[driverId] ?? false;
    // Optimistic update
    setState(() => _visibilityMap[driverId] = canView);
    try {
      await _scheduleService.setDriverVisibility(driverId, canView: canView);
    } catch (e) {
      // Roll back on failure
      setState(() => _visibilityMap[driverId] = previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update visibility: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Visibility'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_drivers.isEmpty) {
      return const Center(child: Text('No drivers in your company.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.accent.withAlpha(20),
          child: Text(
            'Allow drivers to view full schedules of their colleagues. '
            'Enabled drivers see a driver selector in their calendar screen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _drivers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final driver = _drivers[index];
              final canView = _visibilityMap[driver.id] ?? false;
              return SwitchListTile(
                title: Text(driver.name),
                subtitle: Text(driver.email),
                secondary: CircleAvatar(
                  backgroundColor:
                      canView
                          ? AppColors.accent.withAlpha(30)
                          : Colors.grey.withAlpha(30),
                  child: Icon(
                    Icons.person,
                    color: canView ? AppColors.accent : Colors.grey,
                  ),
                ),
                value: canView,
                activeColor: AppColors.accent,
                onChanged: (value) => _setVisibility(driver.id, value),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scheduleService.dispose();
    super.dispose();
  }
}
