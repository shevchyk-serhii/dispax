import 'dart:convert';
import '../models/schedule_day.dart';
import '../../core/services/api_client.dart';

class ScheduleService {
  final ApiClient _apiClient;
  final bool _ownsClient;

  ScheduleService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _ownsClient = apiClient == null;

  Future<ScheduleDay> createScheduleDay({
    required String driverId,
    required String date,
    required String startTime,
    required String endTime,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post('/schedules', {
        'driverId': driverId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        if (notes != null) 'notes': notes,
      });

      if (response.statusCode == 201) {
        return ScheduleDay.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to create schedule day: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error creating schedule day: $e');
    }
  }

  Future<List<ScheduleDay>> createBatch({
    required String driverId,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final response = await _apiClient.post('/schedules/batch', {
        'driverId': driverId,
        'days': days,
      });

      if (response.statusCode == 201) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ScheduleDay.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to create batch schedule: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error creating batch schedule: $e');
    }
  }

  Future<List<ScheduleDay>> getDriverSchedule(String driverId) async {
    try {
      final response = await _apiClient.get('/schedules/driver/$driverId');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ScheduleDay.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch driver schedule: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching driver schedule: $e');
    }
  }

  Future<List<ScheduleDay>> getScheduleForDate(String date) async {
    try {
      final response = await _apiClient.get('/schedules/day/$date');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ScheduleDay.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch schedule for date: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching schedule for date: $e');
    }
  }

  Future<List<ScheduleDay>> getScheduleForDateRange(
    String from,
    String to,
  ) async {
    try {
      final response = await _apiClient.get('/schedules?from=$from&to=$to');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => ScheduleDay.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch schedule for date range: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching schedule for date range: $e');
    }
  }

  Future<ScheduleDay> updateScheduleDay(
    String id, {
    String? startTime,
    String? endTime,
    String? status,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (startTime != null) data['startTime'] = startTime;
      if (endTime != null) data['endTime'] = endTime;
      if (status != null) data['status'] = status;
      if (notes != null) data['notes'] = notes;

      final response = await _apiClient.put('/schedules/$id', data);

      if (response.statusCode == 200) {
        return ScheduleDay.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to update schedule day: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error updating schedule day: $e');
    }
  }

  Future<ScheduleDay> cancelScheduleDay(String id) async {
    try {
      final response = await _apiClient.delete('/schedules/$id');

      if (response.statusCode == 200) {
        return ScheduleDay.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException(
          'Failed to cancel schedule day: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error cancelling schedule day: $e');
    }
  }

  // -- Driver schedule visibility (Dispatcher/Admin) -------------------------

  /// Returns the list of per-driver visibility settings for the caller's company.
  Future<List<Map<String, dynamic>>> getCompanyVisibility() async {
    try {
      final response = await _apiClient.get('/schedules/visibility');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<Map<String, dynamic>>();
      } else {
        throw ApiException(
          'Failed to fetch visibility settings: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching visibility settings: $e');
    }
  }

  /// Sets the `canViewOtherSchedules` flag for a specific driver.
  Future<Map<String, dynamic>> setDriverVisibility(
    String driverId, {
    required bool canView,
  }) async {
    try {
      final response = await _apiClient.put(
        '/schedules/visibility/$driverId',
        {'canViewOtherSchedules': canView},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to update visibility: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error updating visibility: $e');
    }
  }

  void dispose() {
    if (_ownsClient) _apiClient.dispose();
  }
}
