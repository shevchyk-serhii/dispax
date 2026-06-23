import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/models/person.dart';
import '../modules/core/services/api_client.dart';
import '../modules/schedule_management/models/schedule_day.dart';
import '../modules/schedule_management/services/schedule_service.dart';
import '../constants/app_colors.dart';

/// Dispatcher/Admin screen: pick any driver in the company and view that
/// driver's full schedule. Reads are served by GET /api/schedules/driver/{id},
/// which already allows Dispatcher/Admin/Secretary to view colleagues'
/// schedules within their own company (tenant-isolated by CompanyId from JWT).
class DispatcherDriverSchedulesScreen extends StatefulWidget {
  const DispatcherDriverSchedulesScreen({super.key});

  @override
  State<DispatcherDriverSchedulesScreen> createState() =>
      _DispatcherDriverSchedulesScreenState();
}

class _DispatcherDriverSchedulesScreenState
    extends State<DispatcherDriverSchedulesScreen> {
  late final ScheduleService _scheduleService;
  late final ApiClient _apiClient;

  List<Person> _drivers = [];
  Person? _selectedDriver;
  List<ScheduleDay> _schedule = [];

  bool _loadingDrivers = true;
  bool _loadingSchedule = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use the authenticated ApiClient from AuthBloc — never instantiate a new
    // ApiClient() directly (it would be missing the auth token → 401).
    _apiClient = context.read<AuthBloc>().apiClient;
    _scheduleService = ScheduleService(apiClient: _apiClient);
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loadingDrivers = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get('/users/drivers');
      final List<Person> drivers;
      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
        drivers = raw
            .map((j) => Person.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        drivers = [];
      }
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _loadingDrivers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingDrivers = false;
        });
      }
    }
  }

  Future<void> _loadSchedule(Person driver) async {
    setState(() {
      _selectedDriver = driver;
      _loadingSchedule = true;
      _error = null;
      _schedule = [];
    });
    try {
      final days = await _scheduleService.getDriverSchedule(driver.id);
      if (mounted) {
        setState(() {
          _schedule = days;
          _loadingSchedule = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingSchedule = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.driverSchedules),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: () {
              if (_selectedDriver != null) {
                _loadSchedule(_selectedDriver!);
              } else {
                _loadDrivers();
              }
            },
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loadingDrivers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _drivers.isEmpty) {
      return _buildError(l10n, _loadDrivers);
    }
    if (_drivers.isEmpty) {
      return Center(child: Text(l10n.noDriversScheduled));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<Person>(
            initialValue: _selectedDriver,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.selectDriver,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
            ),
            items: _drivers
                .map(
                  (d) => DropdownMenuItem<Person>(
                    value: d,
                    child: Text(d.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (driver) {
              if (driver != null) _loadSchedule(driver);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildScheduleArea(l10n)),
      ],
    );
  }

  Widget _buildScheduleArea(AppLocalizations l10n) {
    if (_selectedDriver == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.selectDriverToViewSchedule,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (_loadingSchedule) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(l10n, () => _loadSchedule(_selectedDriver!));
    }
    if (_schedule.isEmpty) {
      return Center(child: Text(l10n.noScheduleForDriver));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _schedule.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final day = _schedule[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _statusColor(day.status).withAlpha(30),
            child: Icon(
              Icons.calendar_today,
              size: 20,
              color: _statusColor(day.status),
            ),
          ),
          title: Text(_formatDate(day.date)),
          subtitle: Text(
            '${day.startTime} – ${day.endTime}'
            '${day.notes != null && day.notes!.isNotEmpty ? '\n${day.notes}' : ''}',
          ),
          isThreeLine: day.notes != null && day.notes!.isNotEmpty,
          trailing: Chip(
            label: Text(
              day.status.displayName,
              style: TextStyle(
                color: _statusColor(day.status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: _statusColor(day.status).withAlpha(20),
            side: BorderSide(color: _statusColor(day.status).withAlpha(60)),
          ),
        );
      },
    );
  }

  Widget _buildError(AppLocalizations l10n, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  Color _statusColor(ScheduleDayStatus status) {
    return switch (status) {
      ScheduleDayStatus.scheduled => AppColors.accent,
      ScheduleDayStatus.active => Colors.green,
      ScheduleDayStatus.completed => Colors.grey,
      ScheduleDayStatus.cancelled => AppColors.error,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _scheduleService.dispose();
    super.dispose();
  }
}
