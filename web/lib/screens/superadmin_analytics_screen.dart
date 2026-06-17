import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../modules/core/services/api_client.dart';

// ---------------------------------------------------------------------------
// Domain models / DTOs
// ---------------------------------------------------------------------------

class PlatformRideStats {
  final Map<String, int> byStatus;
  final double totalRevenue;
  final Map<String, int> ridesByCompany;
  final Map<String, double> revenueByCompany;

  const PlatformRideStats({
    required this.byStatus,
    required this.totalRevenue,
    required this.ridesByCompany,
    required this.revenueByCompany,
  });

  factory PlatformRideStats.fromJson(Map<String, dynamic> json) =>
      PlatformRideStats(
        byStatus: (json['byStatus'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        ridesByCompany: (json['ridesByCompany'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        revenueByCompany:
            (json['revenueByCompany'] as Map<String, dynamic>? ?? {}).map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ),
      );
}

class PlatformBillingStats {
  final Map<String, double> revenueByCompany;
  final Map<String, int> overdueByCompany;

  const PlatformBillingStats({
    required this.revenueByCompany,
    required this.overdueByCompany,
  });

  factory PlatformBillingStats.fromJson(
    Map<String, dynamic> json,
  ) => PlatformBillingStats(
    revenueByCompany: (json['revenueByCompany'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble())),
    overdueByCompany: (json['overdueByCompany'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toInt())),
  );
}

class PlatformConnectionStats {
  final int activeSessions;
  final Map<String, int> activeSessionsByCompany;

  const PlatformConnectionStats({
    required this.activeSessions,
    required this.activeSessionsByCompany,
  });

  factory PlatformConnectionStats.fromJson(Map<String, dynamic> json) =>
      PlatformConnectionStats(
        activeSessions: (json['activeSessions'] as num?)?.toInt() ?? 0,
        activeSessionsByCompany:
            (json['activeSessionsByCompany'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class AnalyticsBundle {
  final PlatformRideStats rides;
  final PlatformBillingStats billing;
  final PlatformConnectionStats connections;

  const AnalyticsBundle({
    required this.rides,
    required this.billing,
    required this.connections,
  });
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

abstract class SuperAdminAnalyticsEvent {}

class LoadAnalytics extends SuperAdminAnalyticsEvent {
  final DateTime from;
  final DateTime to;
  LoadAnalytics({required this.from, required this.to});
}

abstract class SuperAdminAnalyticsState {}

class AnalyticsInitial extends SuperAdminAnalyticsState {}

class AnalyticsLoading extends SuperAdminAnalyticsState {}

class AnalyticsLoaded extends SuperAdminAnalyticsState {
  final AnalyticsBundle data;
  AnalyticsLoaded(this.data);
}

class AnalyticsError extends SuperAdminAnalyticsState {
  final String message;
  AnalyticsError(this.message);
}

class SuperAdminAnalyticsBloc
    extends Bloc<SuperAdminAnalyticsEvent, SuperAdminAnalyticsState> {
  final ApiClient _api;

  SuperAdminAnalyticsBloc(this._api) : super(AnalyticsInitial()) {
    on<LoadAnalytics>(_onLoad);
  }

  Future<void> _onLoad(
    LoadAnalytics event,
    Emitter<SuperAdminAnalyticsState> emit,
  ) async {
    emit(AnalyticsLoading());
    try {
      final fromStr = event.from.toUtc().toIso8601String();
      final toStr = event.to.toUtc().toIso8601String();

      final ridesFuture = _api.get(
        '/superadmin/analytics/rides?from=$fromStr&to=$toStr',
      );
      final billingFuture = _api.get(
        '/superadmin/analytics/billing?from=$fromStr&to=$toStr',
      );
      final connectionsFuture = _api.get('/superadmin/analytics/connections');

      final responses = await Future.wait([
        ridesFuture,
        billingFuture,
        connectionsFuture,
      ]);
      final ridesResp = responses[0];
      final billingResp = responses[1];
      final connectionsResp = responses[2];

      if (ridesResp.statusCode != 200 ||
          billingResp.statusCode != 200 ||
          connectionsResp.statusCode != 200) {
        emit(AnalyticsError('Failed to load analytics'));
        return;
      }

      final bundle = AnalyticsBundle(
        rides: PlatformRideStats.fromJson(
          jsonDecode(ridesResp.body) as Map<String, dynamic>,
        ),
        billing: PlatformBillingStats.fromJson(
          jsonDecode(billingResp.body) as Map<String, dynamic>,
        ),
        connections: PlatformConnectionStats.fromJson(
          jsonDecode(connectionsResp.body) as Map<String, dynamic>,
        ),
      );
      emit(AnalyticsLoaded(bundle));
    } catch (e) {
      emit(AnalyticsError(e.toString()));
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Platform admin analytics screen.
/// Shows ride stats, billing overview, and active connections across all tenants.
class SuperAdminAnalyticsScreen extends StatelessWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);

    return BlocProvider(
      create: (context) =>
          SuperAdminAnalyticsBloc(context.read<AuthBloc>().apiClient)
            ..add(LoadAnalytics(from: from, to: now)),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuperAdminAnalyticsBloc, SuperAdminAnalyticsState>(
      builder: (context, state) {
        if (state is AnalyticsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AnalyticsError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    context.read<SuperAdminAnalyticsBloc>().add(
                      LoadAnalytics(
                        from: DateTime(now.year, now.month, 1),
                        to: now,
                      ),
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is AnalyticsLoaded) {
          return _AnalyticsDashboard(data: state.data);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  final AnalyticsBundle data;
  const _AnalyticsDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Analytics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _SummaryCards(data: data),
          const SizedBox(height: 24),
          Text(
            'Ride Status Breakdown',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.rides.byStatus.isEmpty)
            const Text('No ride data for selected period')
          else
            ...data.rides.byStatus.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                trailing: Text(
                  '${e.value}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Active Connections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Active Sessions (Platform)'),
            trailing: Text(
              '${data.connections.activeSessions}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AnalyticsBundle data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: 'Platform Revenue',
          value: '€${data.rides.totalRevenue.toStringAsFixed(2)}',
          icon: Icons.euro,
        ),
        _StatCard(
          label: 'Active Connections',
          value: '${data.connections.activeSessions}',
          icon: Icons.people,
        ),
        _StatCard(
          label: 'Companies with Overdue',
          value: '${data.billing.overdueByCompany.length}',
          icon: Icons.warning_amber,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
