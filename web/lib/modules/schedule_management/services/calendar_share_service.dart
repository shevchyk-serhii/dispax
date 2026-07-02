import 'dart:convert';
import '../models/calendar_share.dart';
import '../../core/services/api_client.dart';

/// API wrapper for cross-company personal calendar sharing
/// (backend: /api/calendar-shares/*). Always construct with the authenticated
/// ApiClient from AuthBloc.
class CalendarShareService {
  final ApiClient _apiClient;
  final bool _ownsClient;

  CalendarShareService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  /// Mints an invite code for the caller's personal calendar.
  Future<CalendarShareInvite> createInvite({int? expiresInDays}) async {
    try {
      final response = await _apiClient.post('/calendar-shares/invites', {
        if (expiresInDays != null) 'expiresInDays': expiresInDays,
      });
      if (response.statusCode == 201) {
        return CalendarShareInvite.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to create invite: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error creating invite: $e');
    }
  }

  Future<List<CalendarShareInvite>> getMyInvites() async {
    try {
      final response = await _apiClient.get('/calendar-shares/invites');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => CalendarShareInvite.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to fetch invites: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching invites: $e');
    }
  }

  Future<void> revokeInvite(String inviteId) async {
    try {
      final response = await _apiClient.delete(
        '/calendar-shares/invites/$inviteId',
      );
      if (response.statusCode != 204) {
        throw ApiException('Failed to revoke invite: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error revoking invite: $e');
    }
  }

  /// Redeems an invite code as the calling user → a persistent grant.
  Future<CalendarShareGrant> redeem(String code) async {
    try {
      final response = await _apiClient.post('/calendar-shares/redeem', {
        'code': code,
      });
      if (response.statusCode == 201) {
        return CalendarShareGrant.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to redeem invite: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error redeeming invite: $e');
    }
  }

  /// Grants where the caller is the grantor (people who can see my calendar).
  Future<List<CalendarShareGrant>> getGranted() async {
    try {
      final response = await _apiClient.get('/calendar-shares/granted');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => CalendarShareGrant.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to fetch grants: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching grants: $e');
    }
  }

  Future<void> revokeGranted(String grantId) async {
    try {
      final response = await _apiClient.delete(
        '/calendar-shares/granted/$grantId',
      );
      if (response.statusCode != 204) {
        throw ApiException('Failed to revoke grant: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error revoking grant: $e');
    }
  }

  /// Grants where the caller is the grantee (calendars shared with me).
  Future<List<CalendarShareGrant>> getSharedWithMe() async {
    try {
      final response = await _apiClient.get('/calendar-shares/shared-with-me');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((j) => CalendarShareGrant.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch shared calendars: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching shared calendars: $e');
    }
  }

  Future<void> unlinkSharedWithMe(String grantId) async {
    try {
      final response = await _apiClient.delete(
        '/calendar-shares/shared-with-me/$grantId',
      );
      if (response.statusCode != 204) {
        throw ApiException('Failed to unlink share: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error unlinking share: $e');
    }
  }

  /// Reads the shared calendar for an inclusive [from]..[to] date range.
  Future<SharedCalendar> getSharedCalendar(
    String grantId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final fromStr = _dateOnly(from);
      final toStr = _dateOnly(to);
      final response = await _apiClient.get(
        '/calendar-shares/$grantId/calendar?from=$fromStr&to=$toStr',
      );
      if (response.statusCode == 200) {
        return SharedCalendar.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch shared calendar: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching shared calendar: $e');
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void dispose() {
    if (_ownsClient) _apiClient.dispose();
  }
}
