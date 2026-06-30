import 'dart:convert';
import '../modules/core/services/error_messages.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/auth/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../modules/core/services/api_client.dart';
import '../l10n/app_localizations.dart';

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

  /// Typed cause, for `friendlyError`. Null when [message] is a fixed domain
  /// string.
  final Object? error;
  AnalyticsError(this.message, {this.error});
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
      emit(AnalyticsError('Failed to load analytics', error: e));
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
    return Column(
      children: [
        _GraphiteHeader(
          onRefresh: () {
            final now = DateTime.now();
            context.read<SuperAdminAnalyticsBloc>().add(
              LoadAnalytics(from: DateTime(now.year, now.month, 1), to: now),
            );
          },
        ),
        Expanded(
          child: BlocBuilder<SuperAdminAnalyticsBloc, SuperAdminAnalyticsState>(
            builder: (context, state) {
              if (state is AnalyticsLoading) {
                return Center(child: CircularProgressIndicator.adaptive());
              }
              if (state is AnalyticsError) {
                final l10n = AppLocalizations.of(context)!;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friendlyError(state.error ?? state.message, l10n),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                );
              }
              if (state is AnalyticsLoaded) {
                return _AnalyticsDashboard(data: state.data);
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
                Icons.analytics_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.platformAnalytics,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: onRefresh,
                tooltip: l10n.refresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics dashboard
// ---------------------------------------------------------------------------

class _AnalyticsDashboard extends StatelessWidget {
  final AnalyticsBundle data;
  const _AnalyticsDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalRides = data.rides.ridesByCompany.values.fold(
      0,
      (a, b) => a + b,
    );
    final completedRides = data.rides.byStatus['Completed'] ?? 0;
    // This is the completion rate (completed / total), not an on-time/
    // punctuality metric — the backend does not expose at-risk data here.
    final completionPct = totalRides > 0
        ? (completedRides / totalRides * 100).toStringAsFixed(1)
        : '—';

    // Avg slack: not provided by backend — show placeholder
    // GMV: totalRevenue from rides analytics
    final eurFmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat tiles (2×2 grid) ──────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 520;
              if (wide) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatTile.dark(
                        label: l10n.totalRidesStatLabel,
                        value: '$totalRides',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile.light(
                        label: l10n.completionRateStatLabel,
                        value: totalRides > 0 ? '$completionPct %' : '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile.light(
                        label: l10n.avgSlackStatLabel,
                        // TODO: avg slack not in PlatformRideStats; add when backend supports it
                        value: '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile.light(
                        label: l10n.gmvStatLabel,
                        value: eurFmt.format(data.rides.totalRevenue),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile.dark(
                          label: l10n.totalRidesStatLabel,
                          value: '$totalRides',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile.light(
                          label: l10n.completionRateStatLabel,
                          value: totalRides > 0 ? '$completionPct %' : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile.light(
                          label: l10n.avgSlackStatLabel,
                          value: '—',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile.light(
                          label: l10n.gmvStatLabel,
                          value: eurFmt.format(data.rides.totalRevenue),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Bar chart: Rides by company ────────────────────────────────
          if (data.rides.ridesByCompany.isNotEmpty) ...[
            Text(
              l10n.ridesByTenantTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _RidesBarChart(ridesByCompany: data.rides.ridesByCompany),
            const SizedBox(height: 24),
          ],

          // ── Status breakdown ───────────────────────────────────────────
          if (data.rides.byStatus.isNotEmpty) ...[
            Text(
              l10n.rideStatusBreakdownTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _StatusBreakdown(byStatus: data.rides.byStatus),
            const SizedBox(height: 24),
          ],

          // ── Active sessions ───────────────────────────────────────────
          Text(
            l10n.platformActiveSessionsLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _ActiveSessions(connections: data.connections),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat tile
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkTile;

  const _StatTile._({
    required this.label,
    required this.value,
    required this.isDarkTile,
  });

  factory _StatTile.dark({required String label, required String value}) =>
      _StatTile._(label: label, value: value, isDarkTile: true);

  factory _StatTile.light({required String label, required String value}) =>
      _StatTile._(label: label, value: value, isDarkTile: false);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDarkTile) {
      // Dark graphite tile — always graphite regardless of app theme
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium + 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Light tile — follows theme
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;
    final labelColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final valueColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium + 2),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rides bar chart
// ---------------------------------------------------------------------------

class _RidesBarChart extends StatelessWidget {
  final Map<String, int> ridesByCompany;
  const _RidesBarChart({required this.ridesByCompany});

  @override
  Widget build(BuildContext context) {
    if (ridesByCompany.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = ridesByCompany.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce(math.max);
    bool isLatest(int idx) => idx == entries.length - 1;

    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;
    final barBg = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.surfaceVariant;
    final labelColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium + 2),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${entries[i].value}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLatest(i) ? AppColors.accent : labelColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: maxVal > 0
                              ? (entries[i].value / maxVal * 100).clamp(
                                  4.0,
                                  100.0,
                                )
                              : 4,
                          decoration: BoxDecoration(
                            color: isLatest(i) ? AppColors.accent : barBg,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _shortLabel(entries[i].key),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: labelColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _shortLabel(String company) {
    if (company.length <= 8) return company;
    return '${company.substring(0, 6)}…';
  }
}

// ---------------------------------------------------------------------------
// Status breakdown list
// ---------------------------------------------------------------------------

class _StatusBreakdown extends StatelessWidget {
  final Map<String, int> byStatus;
  const _StatusBreakdown({required this.byStatus});

  static const _statusColors = <String, Color>{
    'Completed': AppColors.rideCompleted,
    'Requested': AppColors.rideRequested,
    'Assigned': AppColors.rideAssigned,
    'InProgress': AppColors.rideInProgress,
    'Cancelled': AppColors.rideCancelled,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium + 2),
      ),
      child: Column(
        children: byStatus.entries.map((e) {
          final color = _statusColors[e.key] ?? AppColors.textSecondary;
          return ListTile(
            dense: true,
            leading: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            title: Text(e.key, style: const TextStyle(fontSize: 13)),
            trailing: Text(
              '${e.value}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active sessions
// ---------------------------------------------------------------------------

class _ActiveSessions extends StatelessWidget {
  final PlatformConnectionStats connections;
  const _ActiveSessions({required this.connections});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium + 2),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.people_outline, size: 18),
            title: const Text(
              'Platform Active Sessions',
              style: TextStyle(fontSize: 13),
            ),
            trailing: Text(
              '${connections.activeSessions}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (connections.activeSessionsByCompany.isNotEmpty) ...[
            const Divider(height: 1),
            ...connections.activeSessionsByCompany.entries.map(
              (e) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                title: Text(
                  e.key,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${e.value}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
