import 'package:flutter/material.dart';
import '../../core/json_parse.dart';
import '../../core/models/location.dart';
import '../../core/models/person.dart';

enum RideStatus {
  requested('Requested'),
  assigned('Assigned'),
  confirmed('Confirmed'),
  inProgress('InProgress'),
  completed('Completed'),
  cancelled('Cancelled'),
  handedOff('HandedOff');

  const RideStatus(this.value);
  final String value;

  String get displayName {
    switch (this) {
      case RideStatus.requested:
        return 'Requested';
      case RideStatus.assigned:
        return 'Assigned';
      case RideStatus.confirmed:
        return 'Confirmed';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
      case RideStatus.handedOff:
        return 'Handed Off';
    }
  }

  /// Returns the matching [RideStatus], or `null` if the value is unrecognised.
  /// Prefer this over [fromString] in contexts where an unknown status should
  /// be handled explicitly (e.g. WebSocket events) rather than silently
  /// defaulting to [requested].
  static RideStatus? fromStringOrNull(String value) {
    return RideStatus.values
        .where((status) => status.value.toLowerCase() == value.toLowerCase())
        .firstOrNull;
  }

  /// Returns the matching [RideStatus].
  /// Falls back to [requested] only as a last resort; callers that cannot
  /// tolerate a wrong default should use [fromStringOrNull] instead.
  static RideStatus fromString(String value) {
    final result = fromStringOrNull(value);
    if (result == null) {
      debugPrint('RideStatus.fromString: unrecognised status "$value"');
    }
    return result ?? RideStatus.requested;
  }
}

class Ride {
  final String id;
  final String clientId;
  final String creatorId;
  final String? driverId;
  final String companyId;
  final String? scheduleDayId;
  final DateTime pickupDateTime;
  final Location from;
  final Location to;
  final RideStatus status;
  final String clientName;

  /// Whether the client has a profile photo, so cards can render their avatar.
  /// Sourced from the backend RideDto (derived from the client's Person).
  final bool clientHasAvatar;

  /// Whether the assigned driver has a profile photo (mirrors [clientHasAvatar]).
  /// False when no driver is assigned or the endpoint didn't resolve one.
  final bool driverHasAvatar;

  /// True when the ride was booked without a real client — a provisional
  /// placeholder was created by the backend (from-chat flow). The card renders
  /// the route instead of the placeholder name until the client is linked.
  final bool clientProvisional;
  final String? flightNumber;
  final DateTime? flightTime;
  // Scheduled (on-time) flight instant, tracked separately from flightTime (latest known/estimated)
  // so the card can show the delay = flightTime − flightScheduledTime.
  final DateTime? flightScheduledTime;
  // For airport ARRIVAL rides: the origin take-off instant, so the card can animate the en-route
  // progress as (now − flightDepartureTime) / (flightTime − flightDepartureTime). Null until the
  // flight monitor has fetched detail data.
  final DateTime? flightDepartureTime;
  final bool isAirportTransfer;
  final bool isArrival;
  final String? gate;
  final String? terminal;
  final String? flightStatus;
  // For airport ARRIVAL rides: backend-computed recommended terminal-entry time ("Einfahrt um").
  final DateTime? optimalEntryTime;
  final String? driverName;

  /// The assigned driver's average rating across all their rides (0–5), as
  /// returned in RideDto. Distinct from [rating], which is the client's rating
  /// of THIS ride. Null when the driver has no ratings yet or none is assigned.
  final double? driverRating;

  /// Number of ratings the [driverRating] average is based on.
  final int? driverRatingCount;
  final Location? driverLocation;
  final Location? clientLocation;
  final bool driverApproaching;
  final int? driverDistanceMeters;
  final int? etaMinutes;
  final double? price;
  final String? notes;
  final String? specialRequirements;
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime? paidAt;
  final bool confirmationSent;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final String? cancellationReason;
  final double? cancellationFee;
  final String? cancelledBy;
  final int? rating;
  final String? ratingComment;
  final bool isVipRide;
  final bool preferredDriverUsed;
  final String? poolId;
  final String?
  airportCheckpoint; // "landed" | "arrivals_hall" | "terminal_exit" | null

  /// Set when the ride was handed off to an external driver.
  final String? externalDriverId;

  /// Set when the ride was handed off to a partner company.
  final String? partnerCompanyId;

  /// Free-form operator labels attached to the ride (e.g. "Urgent", "Cash").
  /// Normalized server-side; empty when none.
  final List<String> tags;

  const Ride({
    required this.id,
    required this.clientId,
    required this.creatorId,
    this.driverId,
    required this.companyId,
    this.scheduleDayId,
    required this.pickupDateTime,
    required this.from,
    required this.to,
    this.status = RideStatus.requested,
    required this.clientName,
    this.clientHasAvatar = false,
    this.driverHasAvatar = false,
    this.clientProvisional = false,
    this.flightNumber,
    this.flightTime,
    this.flightScheduledTime,
    this.flightDepartureTime,
    this.isAirportTransfer = false,
    this.isArrival = false,
    this.gate,
    this.terminal,
    this.flightStatus,
    this.optimalEntryTime,
    this.driverName,
    this.driverRating,
    this.driverRatingCount,
    this.driverLocation,
    this.clientLocation,
    this.driverApproaching = false,
    this.driverDistanceMeters,
    this.etaMinutes,
    this.price,
    this.notes,
    this.specialRequirements,
    this.paymentStatus,
    this.paymentMethod,
    this.paidAt,
    this.confirmationSent = false,
    this.confirmedAt,
    this.rejectionReason,
    this.cancellationReason,
    this.cancellationFee,
    this.cancelledBy,
    this.rating,
    this.ratingComment,
    this.isVipRide = false,
    this.preferredDriverUsed = false,
    this.poolId,
    this.airportCheckpoint,
    this.externalDriverId,
    this.partnerCompanyId,
    this.tags = const [],
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      driverId: json['driverId']?.toString(),
      companyId: json['companyId']?.toString() ?? '',
      scheduleDayId: json['scheduleDayId'],
      pickupDateTime: JsonParse.requiredDateTime(
        json,
        'pickupDateTime',
      ).toLocal(),
      from: Location.fromJson(json['from']),
      to: Location.fromJson(json['to']),
      status: RideStatus.fromString(json['status'] ?? 'Requested'),
      clientName: json['clientName'] ?? 'Unknown Client',
      clientHasAvatar: json['clientHasAvatar'] as bool? ?? false,
      driverHasAvatar: json['driverHasAvatar'] as bool? ?? false,
      clientProvisional: json['clientProvisional'] as bool? ?? false,
      flightNumber: json['flightNumber'],
      // Convert to local like pickupDateTime, so airport flight times are not
      // shown in UTC while every other time on the ride is local.
      flightTime: JsonParse.optionalDateTime(json, 'flightTime')?.toLocal(),
      flightScheduledTime: JsonParse.optionalDateTime(
        json,
        'flightScheduledTime',
      )?.toLocal(),
      flightDepartureTime: JsonParse.optionalDateTime(
        json,
        'flightDepartureTime',
      )?.toLocal(),
      isAirportTransfer: json['isAirportTransfer'] ?? false,
      isArrival: json['isArrival'] ?? false,
      optimalEntryTime: JsonParse.optionalDateTime(
        json,
        'optimalEntryTime',
      )?.toLocal(),
      gate: json['gate'],
      terminal: json['terminal'],
      flightStatus: json['flightStatus'],
      driverName: json['driverName'],
      driverRating: (json['driverRating'] as num?)?.toDouble(),
      driverRatingCount: json['driverRatingCount'] as int?,
      driverLocation: json['driverLocation'] != null
          ? Location.fromJson(json['driverLocation'])
          : null,
      clientLocation: json['clientLocation'] != null
          ? Location.fromJson(json['clientLocation'])
          : null,
      driverApproaching: json['driverApproaching'] ?? false,
      driverDistanceMeters: json['driverDistanceMeters'],
      etaMinutes: json['etaMinutes'],
      price: json['price']?.toDouble(),
      notes: json['notes'],
      specialRequirements: json['specialRequirements'],
      paymentStatus: json['paymentStatus'],
      paymentMethod: json['paymentMethod'],
      // Convert to local like pickupDateTime/flightTime: leaving these in UTC
      // makes day/month comparisons (e.g. billing totals grouped by month)
      // drift by the timezone offset near day boundaries.
      paidAt: JsonParse.optionalDateTime(json, 'paidAt')?.toLocal(),
      confirmationSent: json['confirmationSent'] ?? false,
      confirmedAt: JsonParse.optionalDateTime(json, 'confirmedAt')?.toLocal(),
      rejectionReason: json['rejectionReason'] as String?,
      cancellationReason: json['cancellationReason'],
      cancellationFee: json['cancellationFee']?.toDouble(),
      cancelledBy: json['cancelledBy'],
      rating: json['rating'],
      ratingComment: json['ratingComment'],
      isVipRide: json['isVipRide'] ?? false,
      preferredDriverUsed: json['preferredDriverUsed'] ?? false,
      poolId: json['poolId'],
      airportCheckpoint: json['airportCheckpoint'],
      externalDriverId: json['externalDriverId']?.toString(),
      partnerCompanyId: json['partnerCompanyId']?.toString(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'creatorId': creatorId,
      'driverId': driverId,
      'companyId': companyId,
      'scheduleDayId': scheduleDayId,
      'pickupDateTime': pickupDateTime.toUtc().toIso8601String(),
      'from': from.toJson(),
      'to': to.toJson(),
      'status': status.value,
      'clientName': clientName,
      'clientHasAvatar': clientHasAvatar,
      'driverHasAvatar': driverHasAvatar,
      'clientProvisional': clientProvisional,
      'flightNumber': flightNumber,
      'flightTime': flightTime?.toUtc().toIso8601String(),
      'flightScheduledTime': flightScheduledTime?.toUtc().toIso8601String(),
      'flightDepartureTime': flightDepartureTime?.toUtc().toIso8601String(),
      'isAirportTransfer': isAirportTransfer,
      'isArrival': isArrival,
      'optimalEntryTime': optimalEntryTime?.toUtc().toIso8601String(),
      'gate': gate,
      'terminal': terminal,
      'flightStatus': flightStatus,
      'driverName': driverName,
      'driverRating': driverRating,
      'driverRatingCount': driverRatingCount,
      'driverLocation': driverLocation?.toJson(),
      'clientLocation': clientLocation?.toJson(),
      'driverApproaching': driverApproaching,
      'driverDistanceMeters': driverDistanceMeters,
      'etaMinutes': etaMinutes,
      'price': price,
      'notes': notes,
      'specialRequirements': specialRequirements,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt?.toUtc().toIso8601String(),
      'confirmationSent': confirmationSent,
      'confirmedAt': confirmedAt?.toUtc().toIso8601String(),
      'rejectionReason': rejectionReason,
      'cancellationReason': cancellationReason,
      'cancellationFee': cancellationFee,
      'cancelledBy': cancelledBy,
      'rating': rating,
      'ratingComment': ratingComment,
      'isVipRide': isVipRide,
      'preferredDriverUsed': preferredDriverUsed,
      'poolId': poolId,
      'airportCheckpoint': airportCheckpoint,
      'externalDriverId': externalDriverId,
      'partnerCompanyId': partnerCompanyId,
      'tags': tags,
    };
  }

  Ride copyWith({
    String? id,
    String? clientId,
    String? creatorId,
    // Sentinel-based so a driver reassignment can explicitly CLEAR the stale
    // driver id/name/location (pass null) while omitting the argument still
    // keeps the current value — `?? this.x` cannot tell those apart.
    Object? driverId = _sentinel,
    String? companyId,
    String? scheduleDayId,
    DateTime? pickupDateTime,
    Location? from,
    Location? to,
    RideStatus? status,
    String? clientName,
    bool? clientHasAvatar,
    bool? driverHasAvatar,
    bool? clientProvisional,
    String? flightNumber,
    Object? flightTime = _sentinel,
    Object? flightScheduledTime = _sentinel,
    Object? flightDepartureTime = _sentinel,
    bool? isAirportTransfer,
    bool? isArrival,
    String? gate,
    String? terminal,
    String? flightStatus,
    Object? optimalEntryTime = _sentinel,
    Object? driverName = _sentinel,
    double? driverRating,
    int? driverRatingCount,
    Object? driverLocation = _sentinel,
    Location? clientLocation,
    bool? driverApproaching,
    int? driverDistanceMeters,
    int? etaMinutes,
    double? price,
    String? notes,
    String? specialRequirements,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? paidAt,
    bool? confirmationSent,
    Object? confirmedAt = _sentinel,
    Object? rejectionReason = _sentinel,
    String? cancellationReason,
    double? cancellationFee,
    String? cancelledBy,
    int? rating,
    String? ratingComment,
    bool? isVipRide,
    bool? preferredDriverUsed,
    String? poolId,
    Object? airportCheckpoint = _sentinel,
    Object? externalDriverId = _sentinel,
    Object? partnerCompanyId = _sentinel,
    List<String>? tags,
  }) {
    return Ride(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      creatorId: creatorId ?? this.creatorId,
      driverId: driverId == _sentinel ? this.driverId : driverId as String?,
      companyId: companyId ?? this.companyId,
      scheduleDayId: scheduleDayId ?? this.scheduleDayId,
      pickupDateTime: pickupDateTime ?? this.pickupDateTime,
      from: from ?? this.from,
      to: to ?? this.to,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientHasAvatar: clientHasAvatar ?? this.clientHasAvatar,
      driverHasAvatar: driverHasAvatar ?? this.driverHasAvatar,
      clientProvisional: clientProvisional ?? this.clientProvisional,
      flightNumber: flightNumber ?? this.flightNumber,
      flightTime: flightTime == _sentinel
          ? this.flightTime
          : flightTime as DateTime?,
      flightScheduledTime: flightScheduledTime == _sentinel
          ? this.flightScheduledTime
          : flightScheduledTime as DateTime?,
      flightDepartureTime: flightDepartureTime == _sentinel
          ? this.flightDepartureTime
          : flightDepartureTime as DateTime?,
      isAirportTransfer: isAirportTransfer ?? this.isAirportTransfer,
      isArrival: isArrival ?? this.isArrival,
      optimalEntryTime: optimalEntryTime == _sentinel
          ? this.optimalEntryTime
          : optimalEntryTime as DateTime?,
      gate: gate ?? this.gate,
      terminal: terminal ?? this.terminal,
      flightStatus: flightStatus ?? this.flightStatus,
      driverName: driverName == _sentinel
          ? this.driverName
          : driverName as String?,
      driverRating: driverRating ?? this.driverRating,
      driverRatingCount: driverRatingCount ?? this.driverRatingCount,
      driverLocation: driverLocation == _sentinel
          ? this.driverLocation
          : driverLocation as Location?,
      clientLocation: clientLocation ?? this.clientLocation,
      driverApproaching: driverApproaching ?? this.driverApproaching,
      driverDistanceMeters: driverDistanceMeters ?? this.driverDistanceMeters,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      confirmationSent: confirmationSent ?? this.confirmationSent,
      confirmedAt: confirmedAt == _sentinel
          ? this.confirmedAt
          : confirmedAt as DateTime?,
      rejectionReason: rejectionReason == _sentinel
          ? this.rejectionReason
          : rejectionReason as String?,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      isVipRide: isVipRide ?? this.isVipRide,
      preferredDriverUsed: preferredDriverUsed ?? this.preferredDriverUsed,
      poolId: poolId ?? this.poolId,
      airportCheckpoint: airportCheckpoint == _sentinel
          ? this.airportCheckpoint
          : airportCheckpoint as String?,
      externalDriverId: externalDriverId == _sentinel
          ? this.externalDriverId
          : externalDriverId as String?,
      partnerCompanyId: partnerCompanyId == _sentinel
          ? this.partnerCompanyId
          : partnerCompanyId as String?,
      tags: tags ?? this.tags,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ride &&
        other.id == id &&
        other.clientId == clientId &&
        other.status == status &&
        other.pickupDateTime == pickupDateTime &&
        other.from == from &&
        other.to == to &&
        // Included so a live WebSocket checkpoint update yields a != Ride and the
        // BLoC actually re-emits (otherwise the row never refreshes on the card).
        other.airportCheckpoint == airportCheckpoint;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        clientId.hashCode ^
        status.hashCode ^
        pickupDateTime.hashCode ^
        from.hashCode ^
        to.hashCode ^
        airportCheckpoint.hashCode;
  }

  @override
  String toString() {
    return 'Ride(id: $id, from: $from, to: $to, status: ${status.value}, pickupDateTime: $pickupDateTime, flightNumber: $flightNumber, gate: $gate, isArrival: $isArrival, flightStatus: $flightStatus)';
  }

  /// True when the driver has started location tracking and is actively heading
  /// to the client. Used to gate "Driver on the way" labels vs. the neutral
  /// "Driver assigned" label for a future/pre-departure assigned ride.
  bool get driverEnRoute => driverLocation != null;
  bool get isConfirmed => status == RideStatus.confirmed;

  /// True for an airport pickup where the passenger is arriving (landing) — the
  /// case that has a recommended terminal-entry time ("Einfahrt um").
  bool get isArrivalAirportTransfer => isAirportTransfer && isArrival;

  /// Flight delay in minutes (latest known minus scheduled), or null when either
  /// time is missing. Only positive when the flight is actually late.
  int? get flightDelayMinutes {
    final actual = flightTime;
    final scheduled = flightScheduledTime;
    if (actual == null || scheduled == null) return null;
    return actual.difference(scheduled).inMinutes;
  }

  /// True once the flight has actually landed (the board status is "landed").
  /// While the aircraft is still airborne (scheduled / boarding / departed /
  /// en_route) the arrival time is an estimate, not a fact — the card uses this
  /// to label it "Landung um …" (forecast) vs "Gelandet um …" (actual).
  bool get flightHasLanded => flightStatus?.toLowerCase().trim() == 'landed';

  /// Position of [now] within the take-off → landing window [start, end] as a
  /// fraction in [0, 1], or null when the window is missing/degenerate. The single
  /// source of truth for the en-route airplane's position — both this getter and
  /// the progress-bar widget call it, so the tested math is the math that renders.
  static double? flightProgress(DateTime now, DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final total = end.difference(start).inSeconds;
    if (total <= 0) return null; // guard against a bad/zero window
    final elapsed = now.difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// How far along the flight is between take-off and (estimated) landing, as a
  /// fraction in [0, 1] — drives the airplane icon crawling along the "Im Flug"
  /// segment of the progress bar. The window is [flightDepartureTime, flightTime]:
  /// using the live [flightTime] as the end means a delay correctly slows the
  /// plane down. Null (→ no airplane, plain connector) unless this is an arrival
  /// with both a known departure and arrival time. [now] is injectable for tests.
  double? flightProgressFraction(DateTime now) {
    if (!isArrival) return null;
    return flightProgress(now, flightDepartureTime, flightTime);
  }

  /// Returns this ride with ONLY the flight-tracking fields copied from [fresh]
  /// (gate, terminal, flightStatus, flightTime, flightDepartureTime), keeping every
  /// other field — driverName, optimalEntryTime, avatar, eta — intact.
  ///
  /// Used after a manual flight refresh: the refresh DTO is not fully enriched, so
  /// pushing it wholesale into the shared RideBloc would blank those fields on the
  /// list cards (the confirm-vanish overwrite trap). flightTime/flightDepartureTime
  /// fall back to the current value when [fresh] has none, so a not-found refresh
  /// never erases a time we already had.
  Ride withFlightFrom(Ride fresh) => copyWith(
    gate: fresh.gate,
    terminal: fresh.terminal,
    flightStatus: fresh.flightStatus,
    flightTime: fresh.flightTime ?? flightTime,
    flightDepartureTime: fresh.flightDepartureTime ?? flightDepartureTime,
  );

  /// True when the flight is delayed — either the computed delay is positive, or
  /// the airport board explicitly reports a "delayed" status.
  bool get isFlightDelayed {
    final delay = flightDelayMinutes;
    if (delay != null && delay > 0) return true;
    return flightStatus?.toLowerCase() == 'delayed';
  }

  /// True when the ride is in a state worth showing on the live map: a driver
  /// has been assigned (or confirmed / handed off to a partner) and the ride is
  /// either upcoming or in progress. `requested` has no driver yet, and
  /// `completed`/`cancelled` rides are done — none of those are trackable.
  bool get isTrackable =>
      status == RideStatus.assigned ||
      status == RideStatus.confirmed ||
      status == RideStatus.inProgress ||
      status == RideStatus.handedOff;

  String get statusDisplayName {
    return status.displayName;
  }

  String get flightIcon {
    if (!isAirportTransfer) return '';
    return isArrival ? '✈️↓' : '✈️↑';
  }

  IconData? get flightIconData {
    if (!isAirportTransfer) return null;
    return isArrival ? Icons.flight_land : Icons.flight_takeoff;
  }

  String get flightTypeText {
    if (!isAirportTransfer) return '';
    return isArrival ? 'Arrival' : 'Departure';
  }

  /// Status emoji. Neutral (info) for unknown/unmapped so it does not read as an error.
  String get flightStatusIcon {
    final status = flightStatus;
    if (status == null) return '';
    switch (status.toLowerCase()) {
      case 'on time':
      case 'scheduled':
        return '✅';
      case 'boarding':
      case 'departed':
      case 'en_route':
        return '🛫';
      case 'landed':
        return '🛬';
      case 'delayed':
        return '⏰';
      case 'cancelled':
        return '❌';
      case 'diverted':
        return '↪️';
      default:
        return 'ℹ️';
    }
  }

  /// True when MUC put the flight on a remote (apron) bus stand — the gate is the
  /// sentinel "REMOTE" rather than a real code (e.g. "G35"). Such a gate must be shown
  /// as a localized "bus gate" label, not the raw word, and means a longer walk-out.
  bool get isRemoteGate => gate?.trim().toUpperCase() == 'REMOTE';

  /// Flight line WITHOUT the status (flight number + gate/terminal). The status is rendered
  /// separately and localized at the call site (a getter has no BuildContext / AppLocalizations),
  /// via [RideFlightStatusL10n.localizedFlightStatus].
  ///
  /// NOTE: a remote ("REMOTE") gate is rendered here with the raw word as a fallback only;
  /// prefer [RideFlightStatusL10n.fullFlightInfoLocalized] which localizes it to "Bus gate".
  String get fullFlightInfo {
    if (!isAirportTransfer || flightNumber == null) return '';

    List<String> parts = [];
    parts.add('$flightIcon $flightNumber');

    final gatePart = isRemoteGate
        ? 'Bus gate'
        : (gate != null ? 'Gate $gate' : null);

    if (gatePart != null && terminal != null) {
      parts.add('$gatePart (Terminal $terminal)');
    } else if (gatePart != null) {
      parts.add(gatePart);
    } else if (terminal != null) {
      parts.add('Terminal $terminal');
    }

    return parts.join(' • ');
  }

  /// True when the pickup time has already passed, with the same 5-minute
  /// clock-skew tolerance the backend's RidePolicy applies. The backend rejects
  /// reassigning such a ride (past_ride), so reassign affordances are hidden.
  bool get isPastPickup => pickupDateTime.isBefore(
    DateTime.now().subtract(const Duration(minutes: 5)),
  );

  String get pickupLocation => from.address;
  String get dropoffLocation => to.address;
  DateTime get pickupTime => pickupDateTime;
  double? get estimatedPrice => price;
  double? get estimatedDistance => null;
  int? get estimatedDuration => null;

  FlightInfo? get flightInfo {
    if (!isAirportTransfer) return null;
    // Without a flight time there is nothing meaningful to show — never
    // fabricate DateTime.now(), which would render a wrong time and hide a
    // missing-data contract violation (see JsonParse's no-default policy).
    final time = flightTime;
    if (time == null) return null;
    return FlightInfo(
      flightNumber: flightNumber ?? '',
      flightTime: time,
      gate: gate,
      terminal: terminal,
      status: flightStatus ?? 'Unknown',
      isArrival: isArrival,
    );
  }

  Person? get driver {
    final id = driverId;
    final name = driverName;
    if (id == null || name == null) return null;
    return Person(
      id: id,
      name: name,
      email: '',
      role: PersonRole.driver,
      hasAvatar: driverHasAvatar,
    );
  }

  Person get client {
    return Person(
      id: clientId,
      name: clientName,
      email: '',
      role: PersonRole.client,
      hasAvatar: clientHasAvatar,
    );
  }
}

class FlightInfo {
  final String flightNumber;
  final DateTime flightTime;
  final String? gate;
  final String? terminal;
  final String status;
  final bool isArrival;
  final String? notes;

  const FlightInfo({
    required this.flightNumber,
    required this.flightTime,
    this.gate,
    this.terminal,
    required this.status,
    required this.isArrival,
    this.notes,
  });
}
