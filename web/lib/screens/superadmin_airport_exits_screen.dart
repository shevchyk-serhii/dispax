import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../l10n/app_localizations.dart';
import '../modules/core/services/api_client.dart';
import '../modules/flight_management/widgets/map_picker_widget.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

class AirportZoneInfo {
  final String id;
  final String airportCode;
  final String terminalCode;
  final String checkpointType;
  final String displayName;
  final double lat;
  final double lon;
  final int radiusMeters;
  final int sortOrder;

  const AirportZoneInfo({
    required this.id,
    required this.airportCode,
    required this.terminalCode,
    required this.checkpointType,
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.radiusMeters,
    required this.sortOrder,
  });

  factory AirportZoneInfo.fromJson(Map<String, dynamic> json) =>
      AirportZoneInfo(
        id: json['id']?.toString() ?? '',
        airportCode: json['airportCode']?.toString() ?? '',
        terminalCode: json['terminalCode']?.toString() ?? '',
        checkpointType: json['checkpointType']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
        radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class AirportInfo {
  final String code;
  final String name;
  final String country;
  final double landingLat;
  final double landingLon;
  final int landingRadius;
  final bool isActive;
  final List<AirportZoneInfo> zones;
  final String? createdAt;

  const AirportInfo({
    required this.code,
    required this.name,
    required this.country,
    required this.landingLat,
    required this.landingLon,
    required this.landingRadius,
    required this.isActive,
    required this.zones,
    this.createdAt,
  });

  factory AirportInfo.fromJson(Map<String, dynamic> json) {
    final zonesList = (json['zones'] as List<dynamic>? ?? [])
        .map((z) => AirportZoneInfo.fromJson(z as Map<String, dynamic>))
        .toList();
    return AirportInfo(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? 'DE',
      landingLat: (json['landingLat'] as num?)?.toDouble() ?? 0.0,
      landingLon: (json['landingLon'] as num?)?.toDouble() ?? 0.0,
      landingRadius: (json['landingRadius'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      zones: zonesList,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// BLoC — events
// ---------------------------------------------------------------------------

abstract class SuperAdminAirportEvent {}

class LoadAirports extends SuperAdminAirportEvent {}

class CreateAirport extends SuperAdminAirportEvent {
  final String code;
  final String name;
  final String country;
  final double landingLat;
  final double landingLon;
  final int landingRadius;
  CreateAirport({
    required this.code,
    required this.name,
    required this.country,
    required this.landingLat,
    required this.landingLon,
    required this.landingRadius,
  });
}

class UpdateAirport extends SuperAdminAirportEvent {
  final String code;
  final String name;
  final String country;
  final double landingLat;
  final double landingLon;
  final int landingRadius;
  final bool isActive;
  UpdateAirport({
    required this.code,
    required this.name,
    required this.country,
    required this.landingLat,
    required this.landingLon,
    required this.landingRadius,
    required this.isActive,
  });
}

class DeleteAirport extends SuperAdminAirportEvent {
  final String code;
  DeleteAirport(this.code);
}

class CreateZone extends SuperAdminAirportEvent {
  final String airportCode;
  final String terminalCode;
  final String checkpointType;
  final String displayName;
  final double lat;
  final double lon;
  final int radiusMeters;
  final int sortOrder;
  CreateZone({
    required this.airportCode,
    required this.terminalCode,
    required this.checkpointType,
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.radiusMeters,
    required this.sortOrder,
  });
}

class UpdateZone extends SuperAdminAirportEvent {
  final String zoneId;
  final String airportCode;
  final String terminalCode;
  final String checkpointType;
  final String displayName;
  final double lat;
  final double lon;
  final int radiusMeters;
  final int sortOrder;
  UpdateZone({
    required this.zoneId,
    required this.airportCode,
    required this.terminalCode,
    required this.checkpointType,
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.radiusMeters,
    required this.sortOrder,
  });
}

class DeleteZone extends SuperAdminAirportEvent {
  final String zoneId;
  final String airportCode;
  DeleteZone(this.zoneId, this.airportCode);
}

// ---------------------------------------------------------------------------
// BLoC — states
// ---------------------------------------------------------------------------

abstract class SuperAdminAirportState {}

class AirportsInitial extends SuperAdminAirportState {}

class AirportsLoading extends SuperAdminAirportState {}

class AirportsLoaded extends SuperAdminAirportState {
  final List<AirportInfo> airports;
  AirportsLoaded(this.airports);
}

class AirportsError extends SuperAdminAirportState {
  final String message;
  AirportsError(this.message);
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------

class SuperAdminAirportBloc
    extends Bloc<SuperAdminAirportEvent, SuperAdminAirportState> {
  final ApiClient _api;

  SuperAdminAirportBloc(this._api) : super(AirportsInitial()) {
    on<LoadAirports>(_onLoad);
    on<CreateAirport>(_onCreateAirport);
    on<UpdateAirport>(_onUpdateAirport);
    on<DeleteAirport>(_onDeleteAirport);
    on<CreateZone>(_onCreateZone);
    on<UpdateZone>(_onUpdateZone);
    on<DeleteZone>(_onDeleteZone);
  }

  Future<void> _onLoad(
    LoadAirports event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    emit(AirportsLoading());
    try {
      final response = await _api.get('/superadmin/airports');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> body = decoded is List ? decoded : [];
        emit(
          AirportsLoaded(
            body
                .map((e) => AirportInfo.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
      } else {
        emit(AirportsError('Failed to load airports (${response.statusCode})'));
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onCreateAirport(
    CreateAirport event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api.post('/superadmin/airports', {
        'code': event.code,
        'name': event.name,
        'country': event.country,
        'landingLat': event.landingLat,
        'landingLon': event.landingLon,
        'landingRadius': event.landingRadius,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(
          AirportsError('Failed to create airport (${response.statusCode})'),
        );
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onUpdateAirport(
    UpdateAirport event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api.patch('/superadmin/airports/${event.code}', {
        'name': event.name,
        'country': event.country,
        'landingLat': event.landingLat,
        'landingLon': event.landingLon,
        'landingRadius': event.landingRadius,
        'isActive': event.isActive,
      });
      if (response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(
          AirportsError('Failed to update airport (${response.statusCode})'),
        );
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onDeleteAirport(
    DeleteAirport event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api.delete('/superadmin/airports/${event.code}');
      if (response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(
          AirportsError(
            'Failed to deactivate airport (${response.statusCode})',
          ),
        );
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onCreateZone(
    CreateZone event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api
          .post('/superadmin/airports/${event.airportCode}/zones', {
            'airportCode': event.airportCode,
            'terminalCode': event.terminalCode,
            'checkpointType': event.checkpointType,
            'displayName': event.displayName,
            'lat': event.lat,
            'lon': event.lon,
            'radiusMeters': event.radiusMeters,
            'sortOrder': event.sortOrder,
          });
      if (response.statusCode == 201 || response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(AirportsError('Failed to create zone (${response.statusCode})'));
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onUpdateZone(
    UpdateZone event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api.patch(
        '/superadmin/airports/${event.airportCode}/zones/${event.zoneId}',
        {
          'terminalCode': event.terminalCode,
          'checkpointType': event.checkpointType,
          'displayName': event.displayName,
          'lat': event.lat,
          'lon': event.lon,
          'radiusMeters': event.radiusMeters,
          'sortOrder': event.sortOrder,
        },
      );
      if (response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(AirportsError('Failed to update zone (${response.statusCode})'));
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }

  Future<void> _onDeleteZone(
    DeleteZone event,
    Emitter<SuperAdminAirportState> emit,
  ) async {
    try {
      final response = await _api.delete(
        '/superadmin/airports/${event.airportCode}/zones/${event.zoneId}',
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        add(LoadAirports());
      } else {
        emit(AirportsError('Failed to delete zone (${response.statusCode})'));
      }
    } catch (e) {
      emit(AirportsError(e.toString()));
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// SuperAdmin screen: CRUD for global airport configurations and checkpoint zones.
/// Accessible only to SuperAdmin users.
class SuperAdminAirportExitsScreen extends StatelessWidget {
  const SuperAdminAirportExitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SuperAdminAirportBloc(context.read<AuthBloc>().apiClient)
            ..add(LoadAirports()),
      child: const _AirportExitsView(),
    );
  }
}

class _AirportExitsView extends StatelessWidget {
  const _AirportExitsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GraphiteHeader(
          onRefresh: () =>
              context.read<SuperAdminAirportBloc>().add(LoadAirports()),
          onAdd: () => showDialog<void>(
            context: context,
            builder: (_) =>
                _AirportFormDialog(bloc: context.read<SuperAdminAirportBloc>()),
          ),
        ),
        Expanded(
          child: BlocBuilder<SuperAdminAirportBloc, SuperAdminAirportState>(
            builder: (context, state) {
              if (state is AirportsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is AirportsError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error: ${state.message}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context
                            .read<SuperAdminAirportBloc>()
                            .add(LoadAirports()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (state is AirportsLoaded) {
                return _AirportExitsList(airports: state.airports);
              }
              return const Center(child: CircularProgressIndicator());
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
  final VoidCallback onAdd;
  const _GraphiteHeader({required this.onRefresh, required this.onAdd});

  @override
  Widget build(BuildContext context) {
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
                Icons.flight_land_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'MUC exits & wait buffers',
                  style: TextStyle(
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
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  '+ Airport',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airport exits list — card per airport with expandable zones
// ---------------------------------------------------------------------------

class _AirportExitsList extends StatelessWidget {
  final List<AirportInfo> airports;
  const _AirportExitsList({required this.airports});

  @override
  Widget build(BuildContext context) {
    if (airports.isEmpty) {
      return const Center(child: Text('No airports configured'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: airports.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _AirportCard(
          airport: airports[i],
          bloc: context.read<SuperAdminAirportBloc>(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airport card
// ---------------------------------------------------------------------------

class _AirportCard extends StatefulWidget {
  final AirportInfo airport;
  final SuperAdminAirportBloc bloc;
  const _AirportCard({required this.airport, required this.bloc});

  @override
  State<_AirportCard> createState() => _AirportCardState();
}

class _AirportCardState extends State<_AirportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final airport = widget.airport;
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
          // Airport header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _AirportCodeBadge(code: airport.code),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        airport.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${airport.country} · r=${airport.landingRadius}m · '
                        '${airport.isActive ? "Active" : "Inactive"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  tooltip: 'Edit airport',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _AirportFormDialog(bloc: widget.bloc, airport: airport),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17),
                  tooltip: 'Deactivate',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  tooltip: _expanded ? 'Hide zones' : 'Show zones',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          // Zones list
          if (_expanded) ...[
            Divider(height: 1, color: borderColor),
            _ZonesList(airport: airport, bloc: widget.bloc),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.deleteAirport),
        content: Text(
          'Deactivate ${widget.airport.code} – ${widget.airport.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.bloc.add(DeleteAirport(widget.airport.code));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airport code badge
// ---------------------------------------------------------------------------

class _AirportCodeBadge extends StatelessWidget {
  final String code;
  const _AirportCodeBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    // MUC gets a special gray badge; T1/T2 get accent tints; others use graphite
    final isMUC = code == 'MUC';
    final bg = isMUC
        ? const Color(0xFF52525B) // zinc-600 gray
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terminal badge for individual zones
// ---------------------------------------------------------------------------

class _TerminalBadge extends StatelessWidget {
  final String terminal;
  const _TerminalBadge({required this.terminal});

  @override
  Widget build(BuildContext context) {
    final isT1 = terminal == 'T1';
    final isT2 = terminal == 'T2';
    final isMUC = terminal == 'MUC' || terminal.isEmpty;

    final (bg, fg) = switch (true) {
      _ when isT1 => (
        AppColors.accent.withValues(alpha: 0.12),
        AppColors.accentDark,
      ),
      _ when isT2 => (
        AppColors.accent.withValues(alpha: 0.18),
        AppColors.accent,
      ),
      _ when isMUC => (const Color(0xFFF4F4F5), const Color(0xFF52525B)),
      _ => (AppColors.surfaceVariant, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        terminal.isEmpty ? 'MUC' : terminal,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zones list within an airport card
// ---------------------------------------------------------------------------

class _ZonesList extends StatelessWidget {
  final AirportInfo airport;
  final SuperAdminAirportBloc bloc;
  const _ZonesList({required this.airport, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add zone button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Checkpoint Zones (${airport.zones.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 15),
                label: Text(AppLocalizations.of(context)!.addZone),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _ZoneFormDialog(bloc: bloc, airportCode: airport.code),
                ),
              ),
            ],
          ),
        ),
        if (airport.zones.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'No zones configured',
              style: TextStyle(fontSize: 12, color: secondaryColor),
            ),
          )
        else
          ...airport.zones.map(
            (z) => Column(
              children: [
                Divider(height: 1, color: borderColor),
                _ZoneRow(zone: z, bloc: bloc, airportCode: airport.code),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Zone row — terminal badge + title + buffer chip
// ---------------------------------------------------------------------------

class _ZoneRow extends StatelessWidget {
  final AirportZoneInfo zone;
  final SuperAdminAirportBloc bloc;
  final String airportCode;
  const _ZoneRow({
    required this.zone,
    required this.bloc,
    required this.airportCode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Derive a wait buffer from radius (rough approximation: 200m ≈ +3 min)
    final bufferMinutes = (zone.radiusMeters / 67).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _TerminalBadge(terminal: zone.terminalCode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  zone.checkpointType.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 11, color: secondaryColor),
                ),
              ],
            ),
          ),
          // Buffer chip "+N min"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              border: Border.all(color: AppColors.rideCompletedBorder),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$bufferMinutes min',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.successStrong,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 15),
            tooltip: 'Edit zone',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ZoneFormDialog(
                bloc: bloc,
                airportCode: airportCode,
                zone: zone,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 15),
            tooltip: 'Delete zone',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.deleteZone),
        content: Text(
          'Delete "${zone.displayName}" from ${zone.terminalCode}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              bloc.add(DeleteZone(zone.id, zone.airportCode));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Airport form dialog (create / edit)
// ---------------------------------------------------------------------------

class _AirportFormDialog extends StatefulWidget {
  final SuperAdminAirportBloc bloc;
  final AirportInfo? airport;
  const _AirportFormDialog({required this.bloc, this.airport});

  @override
  State<_AirportFormDialog> createState() => _AirportFormDialogState();
}

class _AirportFormDialogState extends State<_AirportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  late final TextEditingController _radiusCtrl;

  bool get _isEdit => widget.airport != null;

  @override
  void initState() {
    super.initState();
    final a = widget.airport;
    _codeCtrl = TextEditingController(text: a?.code ?? '');
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _countryCtrl = TextEditingController(text: a?.country ?? 'DE');
    _latCtrl = TextEditingController(
      text: a?.landingLat.toStringAsFixed(6) ?? '48.353700',
    );
    _lonCtrl = TextEditingController(
      text: a?.landingLon.toStringAsFixed(6) ?? '11.786000',
    );
    _radiusCtrl = TextEditingController(
      text: a?.landingRadius.toString() ?? '2000',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _countryCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_latCtrl.text) ?? 0.0;
    final lon = double.tryParse(_lonCtrl.text) ?? 0.0;
    final radius = int.tryParse(_radiusCtrl.text) ?? 2000;
    if (_isEdit) {
      widget.bloc.add(
        UpdateAirport(
          code: widget.airport!.code,
          name: _nameCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          landingLat: lat,
          landingLon: lon,
          landingRadius: radius,
          isActive: widget.airport!.isActive,
        ),
      );
    } else {
      widget.bloc.add(
        CreateAirport(
          code: _codeCtrl.text.trim().toUpperCase(),
          name: _nameCtrl.text.trim(),
          country: _countryCtrl.text.trim(),
          landingLat: lat,
          landingLon: lon,
          landingRadius: radius,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_isEdit ? l10n.editAirport : l10n.addAirport),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEdit)
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: InputDecoration(labelText: l10n.airportCode),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.airportName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(labelText: 'Country Code'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.landingGeofence,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latCtrl,
                        decoration: InputDecoration(labelText: l10n.latitude),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null) return 'Invalid number';
                          if (d < -90 || d > 90) return '-90 to 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lonCtrl,
                        decoration: InputDecoration(labelText: l10n.longitude),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null) return 'Invalid number';
                          if (d < -180 || d > 180) return '-180 to 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _radiusCtrl,
                  decoration: InputDecoration(labelText: l10n.radiusMeters),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Must be positive integer';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '${l10n.pickOnMap} (tap to move marker)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                MapPickerWidget(
                  initialLat: double.tryParse(_latCtrl.text),
                  initialLon: double.tryParse(_lonCtrl.text),
                  latController: _latCtrl,
                  lonController: _lonCtrl,
                  onLocationPicked: (lat, lon) {
                    // Text controllers already updated by MapPickerWidget.
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Zone form dialog (create / edit)
// ---------------------------------------------------------------------------

const _kCheckpointTypes = ['landed', 'arrivals_hall', 'terminal_exit'];

class _ZoneFormDialog extends StatefulWidget {
  final SuperAdminAirportBloc bloc;
  final String airportCode;
  final AirportZoneInfo? zone;
  const _ZoneFormDialog({
    required this.bloc,
    required this.airportCode,
    this.zone,
  });

  @override
  State<_ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<_ZoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _terminalCtrl;
  late String _checkpointType;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  late final TextEditingController _radiusCtrl;
  late final TextEditingController _orderCtrl;

  bool get _isEdit => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _terminalCtrl = TextEditingController(text: z?.terminalCode ?? 'T1');
    _checkpointType = z?.checkpointType ?? 'arrivals_hall';
    _nameCtrl = TextEditingController(text: z?.displayName ?? '');
    _latCtrl = TextEditingController(
      text: z?.lat.toStringAsFixed(6) ?? '48.353700',
    );
    _lonCtrl = TextEditingController(
      text: z?.lon.toStringAsFixed(6) ?? '11.786000',
    );
    _radiusCtrl = TextEditingController(
      text: z?.radiusMeters.toString() ?? '200',
    );
    _orderCtrl = TextEditingController(text: z?.sortOrder.toString() ?? '0');
  }

  @override
  void dispose() {
    _terminalCtrl.dispose();
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_latCtrl.text) ?? 0.0;
    final lon = double.tryParse(_lonCtrl.text) ?? 0.0;
    final radius = int.tryParse(_radiusCtrl.text) ?? 200;
    final order = int.tryParse(_orderCtrl.text) ?? 0;
    if (_isEdit) {
      widget.bloc.add(
        UpdateZone(
          zoneId: widget.zone!.id,
          airportCode: widget.airportCode,
          terminalCode: _terminalCtrl.text.trim(),
          checkpointType: _checkpointType,
          displayName: _nameCtrl.text.trim(),
          lat: lat,
          lon: lon,
          radiusMeters: radius,
          sortOrder: order,
        ),
      );
    } else {
      widget.bloc.add(
        CreateZone(
          airportCode: widget.airportCode,
          terminalCode: _terminalCtrl.text.trim(),
          checkpointType: _checkpointType,
          displayName: _nameCtrl.text.trim(),
          lat: lat,
          lon: lon,
          radiusMeters: radius,
          sortOrder: order,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_isEdit ? l10n.editZone : l10n.addZone),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _terminalCtrl,
                  decoration: InputDecoration(labelText: l10n.terminalCode),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _checkpointType,
                  decoration: InputDecoration(labelText: l10n.checkpointType),
                  items: _kCheckpointTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _checkpointType = v);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.displayName),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latCtrl,
                        decoration: InputDecoration(labelText: l10n.latitude),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null) return 'Invalid';
                          if (d < -90 || d > 90) return '-90 to 90';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lonCtrl,
                        decoration: InputDecoration(labelText: l10n.longitude),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null) return 'Invalid';
                          if (d < -180 || d > 180) return '-180 to 180';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _radiusCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.radiusMeters,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Must be positive';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _orderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sort Order',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (int.tryParse(v ?? '') == null) {
                            return 'Must be integer';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${l10n.pickOnMap} (tap to move marker)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                MapPickerWidget(
                  initialLat: double.tryParse(_latCtrl.text),
                  initialLon: double.tryParse(_lonCtrl.text),
                  latController: _latCtrl,
                  lonController: _lonCtrl,
                  onLocationPicked: (lat, lon) {
                    // Text controllers already updated by MapPickerWidget.
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
