import 'package:equatable/equatable.dart';
import '../../modules/core/services/api_client.dart' show ApiException;
import '../../modules/ride_management/models/client_address.dart';

enum SavedPlacesStatus { initial, loading, loaded, error }

class SavedPlacesState extends Equatable {
  final SavedPlacesStatus status;
  final List<ClientAddress> places;
  final String? errorMessage;

  /// Typed cause behind an error state, for `friendlyError`. Additive.
  final Object? error;

  const SavedPlacesState({
    this.status = SavedPlacesStatus.initial,
    this.places = const [],
    this.errorMessage,
    this.error,
  });

  factory SavedPlacesState.initial() => const SavedPlacesState();

  factory SavedPlacesState.loading() =>
      const SavedPlacesState(status: SavedPlacesStatus.loading);

  factory SavedPlacesState.loaded(List<ClientAddress> places) =>
      SavedPlacesState(status: SavedPlacesStatus.loaded, places: places);

  factory SavedPlacesState.error(String message, {Object? cause}) =>
      SavedPlacesState(
        status: SavedPlacesStatus.error,
        errorMessage: message,
        error: cause,
      );

  bool get isLoading => status == SavedPlacesStatus.loading;
  bool get isLoaded => status == SavedPlacesStatus.loaded;
  bool get hasError => status == SavedPlacesStatus.error;

  /// Returns the first address whose label matches [label] (case-insensitive),
  /// or null if none is found.
  ClientAddress? findByLabel(String label) {
    final lower = label.toLowerCase();
    try {
      return places.firstWhere((p) => p.label.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    status,
    places,
    errorMessage,
    error is ApiException ? (error as ApiException).kind : error?.runtimeType,
  ];
}
