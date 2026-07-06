import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

/// Outcome of a client-photo pick + upload attempt, so the UI can react
/// precisely (refresh the avatar, show an error, or do nothing on cancel).
enum ClientPhotoUploadOutcome {
  /// The user cancelled the gallery picker — no change, no error.
  cancelled,

  /// The photo was uploaded successfully.
  success,

  /// The upload failed (network / server error). See [ClientPhotoUploadResult.error].
  failure,
}

class ClientPhotoUploadResult {
  final ClientPhotoUploadOutcome outcome;
  final Object? error;

  const ClientPhotoUploadResult(this.outcome, {this.error});

  bool get isSuccess => outcome == ClientPhotoUploadOutcome.success;
}

/// Pick a photo from the gallery and upload it as [personId]'s avatar via the
/// authenticated `POST /users/{id}/avatar` endpoint.
///
/// Reused by every entry point that lets a driver/dispatcher/secretary attach a
/// photo to a client (ride details card, ride list card). It intentionally takes
/// an [ApiClient] rather than reading it from a BLoC/context, so it works from
/// pushed routes (e.g. RideDetailsScreen) that sit outside the AuthBloc provider.
///
/// Backend authorization decides whether the caller may set this person's photo
/// (owner, dispatcher/admin, or driver/secretary on a client). This function does
/// not re-check roles; gate the entry-point UI accordingly.
Future<ClientPhotoUploadResult> pickAndUploadClientPhoto(
  ApiClient apiClient,
  String personId, {
  ImagePicker? picker,
}) async {
  final xFile = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (xFile == null) {
    return const ClientPhotoUploadResult(ClientPhotoUploadOutcome.cancelled);
  }

  try {
    final bytes = await xFile.readAsBytes();
    final mime = xFile.mimeType ?? 'image/jpeg';
    final response = await apiClient.postMultipart(
      '/users/$personId/avatar',
      'file',
      bytes,
      mime,
    );
    if (response.statusCode == 200) {
      return const ClientPhotoUploadResult(ClientPhotoUploadOutcome.success);
    }
    return ClientPhotoUploadResult(
      ClientPhotoUploadOutcome.failure,
      error: ApiException('upload photo', statusCode: response.statusCode),
    );
  } catch (e) {
    return ClientPhotoUploadResult(ClientPhotoUploadOutcome.failure, error: e);
  }
}
