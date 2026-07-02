import 'dart:convert';
import '../modules/core/services/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../modules/core/models/person.dart';
import '../modules/core/services/api_client.dart';
import '../modules/schedule_management/services/schedule_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';

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
  Object? _error;

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
        drivers = raw
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
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _setVisibility(String driverId, bool canView) async {
    final l10n = AppLocalizations.of(context)!;
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
            content: Text(
              l10n.failedToUpdateVisibilityError(friendlyError(e, l10n)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    final l10n = AppLocalizations.of(context)!;
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
                child: Text(
                  l10n.whoCanSeeWhomTitle,
                  style: const TextStyle(
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
                tooltip: l10n.refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }
    final error = _error == null ? null : friendlyError(_error, l10n);
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(error, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (_drivers.isEmpty) {
      return Center(
        child: Text(
          l10n.noDriversInCompany,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        _VisibilityListCard(
          drivers: _drivers,
          visibilityMap: _visibilityMap,
          onToggle: _setVisibility,
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

// ─── Visibility List Card ─────────────────────────────────────────────────────

class _VisibilityListCard extends StatelessWidget {
  final List<Person> drivers;
  final Map<String, bool> visibilityMap;
  final void Function(String, bool) onToggle;

  const _VisibilityListCard({
    required this.drivers,
    required this.visibilityMap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        children: drivers.asMap().entries.map((entry) {
          final i = entry.key;
          final driver = entry.value;
          final canView = visibilityMap[driver.id] ?? false;
          return _VisibilityRow(
            driver: driver,
            canView: canView,
            isLast: i == drivers.length - 1,
            onToggle: (value) => onToggle(driver.id, value),
          );
        }).toList(),
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final Person driver;
  final bool canView;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  const _VisibilityRow({
    required this.driver,
    required this.canView,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = driver.name.isNotEmpty
        ? driver.name
              .trim()
              .split(' ')
              .take(2)
              .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
              .join()
        : '?';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar 34px
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: canView
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : (isDark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariant),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: canView
                          ? AppColors.accent
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + scope
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
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
                      canView
                          ? l10n.visibleToAllDispatchers
                          : l10n.scheduleHiddenFromOthers,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textLightDark
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Accent toggle
              Switch.adaptive(
                value: canView,
                activeTrackColor: AppColors.accent,
                onChanged: onToggle,
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
