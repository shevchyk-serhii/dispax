import 'package:equatable/equatable.dart';

abstract class SavedPlacesEvent extends Equatable {
  const SavedPlacesEvent();

  @override
  List<Object?> get props => [];
}

/// Load (or reload) the saved places for [clientId].
class SavedPlacesLoadRequested extends SavedPlacesEvent {
  final String clientId;

  const SavedPlacesLoadRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

/// Save a new saved place (e.g. Home/Office/Airport) for [clientId], then
/// reload the list so the UI reflects it.
class SavedPlacesSaveRequested extends SavedPlacesEvent {
  final String clientId;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;

  const SavedPlacesSaveRequested({
    required this.clientId,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [clientId, label, address, latitude, longitude];
}
