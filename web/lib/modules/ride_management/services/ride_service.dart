import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../models/create_ride_request.dart';
import '../models/driver_earnings.dart';
import '../models/partner_company.dart';
import '../models/external_driver.dart';
import '../../core/models/person.dart';
import '../../core/services/api_client.dart';

class RideService {
  final ApiClient privateApiClient;
  final bool _ownsClient;

  RideService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  Future<List<Ride>> getAllRides() async {
    try {
      final response = await privateApiClient.get('/rides');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch rides: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching rides: $e');
    }
  }

  Future<List<Ride>> getRidesForUser(Person user) async {
    try {
      final String endpoint;
      switch (user.role) {
        case PersonRole.driver:
          endpoint = '/rides/driver/${user.id}';
        case PersonRole.client:
          endpoint = '/rides/client/${user.id}';
        default:
          endpoint = '/rides';
      }

      final response = await privateApiClient.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch user rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching user rides: $e');
    }
  }

  /// Driver earnings for a period ('day' | 'week' | 'month'), anchored to [date].
  Future<DriverEarnings> getDriverEarnings(
    String driverId,
    String period,
    DateTime date,
  ) async {
    try {
      final d =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final response = await privateApiClient.get(
        '/drivers/$driverId/earnings?period=$period&date=$d',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return DriverEarnings.fromJson(json);
      } else {
        throw ApiException(
          'Failed to fetch driver earnings: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is UnauthorizedException) rethrow;
      throw ApiException('Error fetching driver earnings: $e');
    }
  }

  /// All rides assigned to [driverId], scoped to the caller's company by the
  /// backend. Used by the dispatcher calendar to show a colleague's schedule
  /// without disturbing the shared RideBloc (which is loaded for the logged-in
  /// user and feeds the other dashboard tabs).
  Future<List<Ride>> getDriverRides(String driverId) async {
    try {
      final response = await privateApiClient.get('/rides/driver/$driverId');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((json) => Ride.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch driver rides: ${response.statusCode}',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error fetching driver rides: $e');
    }
  }

  Future<Ride?> getRideById(String id) async {
    try {
      final response = await privateApiClient.get('/rides/$id');

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException('Failed to fetch ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching ride: $e');
    }
  }

  Future<Ride> createRide(CreateRideRequest request) async {
    try {
      final response = await privateApiClient.post('/rides', request.toJson());

      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else {
        throw ApiException.fromResponse(response, 'Failed to create ride');
      }
    } on ApiException {
      // Already carries the server's message (e.g. a 400 validation error);
      // don't re-wrap it into an opaque "Error creating ride: ApiException: ..."
      rethrow;
    } catch (e) {
      throw ApiException('Error creating ride: $e');
    }
  }

  /// Create (or reuse) a public guest tracking link for a ride. Returns an absolute URL to share.
  ///
  /// Prefers the absolute `url` the backend builds from PUBLIC_BASE_URL. When the backend has no base URL configured
  /// (url == path, i.e. relative), prefix the current web origin so the link is still shareable as-is.
  Future<String> createShareLink(String rideId) async {
    final response = await privateApiClient.post(
      '/rides/$rideId/share-link',
      const {},
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final path = json['path'] as String? ?? '/track/${json['token']}';
      final url = json['url'] as String? ?? path;
      // If the backend already returned an absolute URL, use it verbatim.
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      // Otherwise build one from the page origin (web only; off-web Uri.base.origin throws → fall back to path).
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') {
        return '${base.origin}$url';
      }
      return url;
    }
    throw ApiException.fromResponse(response, 'Failed to create tracking link');
  }

  Future<Ride?> updateRide(String id, Ride ride) async {
    try {
      final response = await privateApiClient.put('/rides/$id', ride.toJson());

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException('Failed to update ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error updating ride: $e');
    }
  }

  Future<bool> updateRideStatus(String id, RideStatus status) async {
    try {
      final response = await privateApiClient.put('/rides/$id/status', {
        'status': status.value,
      });

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else {
        throw ApiException(
          'Failed to update ride status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error updating ride status: $e');
    }
  }

  Future<List<Ride>> getClientRides(String clientId) async {
    try {
      final response = await privateApiClient.get('/rides/client/$clientId');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch client rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching client rides: $e');
    }
  }

  Future<List<Ride>> getPendingRides() async {
    try {
      final response = await privateApiClient.get('/rides/pending');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Ride.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch pending rides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ApiException('Error fetching pending rides: $e');
    }
  }

  Future<Ride> assignDriver(
    String rideId,
    String driverId, {
    bool overrideScheduleConflict = false,
  }) async {
    final response = await privateApiClient.put(
      '/rides/$rideId/assign-driver',
      {
        'driverId': driverId,
        'overrideScheduleConflict': overrideScheduleConflict,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    // Surface the backend's `{"error": ...}` message (and status code) instead
    // of a bare "400", so the UI can show the real reason and react to conflicts.
    throw ApiException.fromResponse(response, 'Failed to assign driver');
  }

  Future<Ride> confirmRide(String rideId) async {
    final response = await privateApiClient.put(
      '/rides/$rideId/confirm',
      <String, dynamic>{},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    throw ApiException.fromResponse(response, 'Failed to confirm ride');
  }

  Future<Ride> rejectRide(String rideId, String reason) async {
    final response = await privateApiClient.put('/rides/$rideId/reject', {
      'reason': reason,
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    throw ApiException.fromResponse(response, 'Failed to reject ride');
  }

  Future<Ride> reassignDriver(
    String rideId,
    String newDriverId, {
    bool overrideScheduleConflict = false,
  }) async {
    final response = await privateApiClient
        .put('/rides/$rideId/reassign-driver', {
          'driverId': newDriverId,
          'overrideScheduleConflict': overrideScheduleConflict,
        });

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return Ride.fromJson(json);
    }
    throw ApiException.fromResponse(response, 'Failed to reassign driver');
  }

  Future<void> updateDriverLocation(
    String driverId,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await privateApiClient.put(
        '/drivers/$driverId/location',
        {'latitude': latitude, 'longitude': longitude},
      );
      debugPrint(
        '📍 Location update: ${response.statusCode} ($latitude, $longitude)',
      );
    } catch (e) {
      debugPrint('📍 Location update failed: $e');
    }
  }

  Future<Map<String, dynamic>?> getDriverProximity(String rideId) async {
    try {
      final response = await privateApiClient.get(
        '/rides/$rideId/driver-location',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateClientLocation(
    String rideId,
    double latitude,
    double longitude,
  ) async {
    try {
      await privateApiClient.post('/rides/$rideId/client-location', {
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      // Best-effort location update
    }
  }

  Future<void> cancelRide(String id, String reason, {double? fee}) async {
    try {
      final body = <String, dynamic>{'reason': reason};
      if (fee != null) body['fee'] = fee;
      final response = await privateApiClient.put('/rides/$id/cancel', body);
      if (response.statusCode != 200) {
        throw ApiException('Failed to cancel ride: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error cancelling ride: $e');
    }
  }

  /// Sets the final price of a ride via PUT /rides/{rideId}/price.
  Future<Ride> setRidePrice(String rideId, double price) async {
    try {
      final response = await privateApiClient.put('/rides/$rideId/price', {
        'price': price,
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      }
      throw ApiException.fromResponse(response, 'Failed to set ride price');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error setting ride price: $e');
    }
  }

  /// Fetches rides for multiple drivers for a single calendar day.
  ///
  /// Calls GET /rides/by-drivers?driverIds=a,b,c&from=YYYY-MM-DD&to=YYYY-MM-DD.
  Future<List<Ride>> getRidesByDrivers(
    List<String> driverIds,
    DateTime date,
  ) async {
    if (driverIds.isEmpty) return [];
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final ids = driverIds.join(',');
      final response = await privateApiClient.get(
        '/rides/by-drivers?driverIds=$ids&from=$dateStr&to=$dateStr',
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => Ride.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ApiException.fromResponse(
        response,
        'Failed to fetch rides by drivers',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error fetching rides by drivers: $e');
    }
  }

  Future<void> markAirportCheckpoint(String rideId, String checkpoint) async {
    try {
      final response = await privateApiClient.post(
        '/rides/$rideId/airport-checkpoint',
        {'checkpoint': checkpoint},
      );
      if (response.statusCode != 204) {
        throw ApiException('Failed to mark checkpoint: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error marking airport checkpoint: $e');
    }
  }

  Future<Map<String, dynamic>?> getAirportCheckpoint(String rideId) async {
    try {
      final response = await privateApiClient.get(
        '/rides/$rideId/airport-checkpoint',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Hands off a ride to an external driver and partner company.
  Future<Ride> handOffRide(
    String rideId, {
    required String externalDriverId,
    required String partnerCompanyId,
  }) async {
    try {
      final response = await privateApiClient.put('/rides/$rideId/hand-off', {
        'externalDriverId': externalDriverId,
        'partnerCompanyId': partnerCompanyId,
      });
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return Ride.fromJson(json);
      }
      throw ApiException.fromResponse(response, 'Failed to hand off ride');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error handing off ride: $e');
    }
  }

  /// Fetches the list of partner companies for the current tenant.
  Future<List<PartnerCompany>> listPartnerCompanies() async {
    try {
      final response = await privateApiClient.get('/partner-companies');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => PartnerCompany.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ApiException.fromResponse(
        response,
        'Failed to fetch partner companies',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error fetching partner companies: $e');
    }
  }

  /// Creates a new partner company for the current tenant.
  Future<PartnerCompany> createPartnerCompany({
    required String name,
    String? phone,
  }) async {
    try {
      final response = await privateApiClient.post('/partner-companies', {
        'name': name,
        if (phone != null) 'phone': phone,
      });
      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return PartnerCompany.fromJson(json);
      }
      throw ApiException.fromResponse(
        response,
        'Failed to create partner company',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error creating partner company: $e');
    }
  }

  /// Fetches the list of external drivers for the current tenant.
  Future<List<ExternalDriver>> listExternalDrivers() async {
    try {
      final response = await privateApiClient.get('/external-drivers');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => ExternalDriver.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      throw ApiException.fromResponse(
        response,
        'Failed to fetch external drivers',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error fetching external drivers: $e');
    }
  }

  /// Creates a new external driver for the current tenant.
  Future<ExternalDriver> createExternalDriver({
    required String name,
    String? phone,
    String? partnerCompanyId,
  }) async {
    try {
      final response = await privateApiClient.post('/external-drivers', {
        'name': name,
        if (phone != null) 'phone': phone,
        if (partnerCompanyId != null) 'partnerCompanyId': partnerCompanyId,
      });
      if (response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return ExternalDriver.fromJson(json);
      }
      throw ApiException.fromResponse(
        response,
        'Failed to create external driver',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error creating external driver: $e');
    }
  }

  void dispose() {
    if (_ownsClient) privateApiClient.dispose();
  }
}
