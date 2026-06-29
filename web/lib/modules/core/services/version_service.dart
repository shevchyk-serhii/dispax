import 'dart:convert';
import 'api_client.dart';

/// Build/version info reported by the backend's public `GET /api/version`.
class BackendVersion {
  final String version;
  final String commit;
  final String branch;
  final String buildTime;

  const BackendVersion({
    required this.version,
    required this.commit,
    required this.branch,
    required this.buildTime,
  });

  factory BackendVersion.fromJson(Map<String, dynamic> json) => BackendVersion(
    version: json['version'] as String? ?? '',
    commit: json['commit'] as String? ?? '',
    branch: json['branch'] as String? ?? '',
    buildTime: json['buildTime'] as String? ?? '',
  );

  /// Compact label for the UI, e.g. "0.1.0 +a1b2c3d".
  String get display => commit.isEmpty ? version : '$version +$commit';
}

/// Fetches the backend build/version from the public, unauthenticated
/// `GET /api/version` endpoint. Used by the Settings "About" section to show the
/// running backend build next to the app's own version.
class VersionService {
  final ApiClient privateApiClient;

  VersionService({ApiClient? apiClient})
    : privateApiClient = apiClient ?? ApiClient();

  Future<BackendVersion> fetchBackendVersion() async {
    final response = await privateApiClient.get('/version');
    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return BackendVersion.fromJson(json);
    }
    throw ApiException(
      'Failed to fetch backend version: ${response.statusCode}',
    );
  }
}
