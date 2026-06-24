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

/// Update an existing saved place's [label] and/or [aliases] for [clientId],
/// then reload the list. The backend PATCH only changes the label/aliases —
/// it cannot change the street address (see [SavedPlacesDeleteRequested] +
/// [SavedPlacesSaveRequested] for an address change).
class SavedPlacesUpdateRequested extends SavedPlacesEvent {
  final String clientId;
  final String addressId;
  final String? label;
  final List<String>? aliases;

  const SavedPlacesUpdateRequested({
    required this.clientId,
    required this.addressId,
    this.label,
    this.aliases,
  });

  @override
  List<Object?> get props => [clientId, addressId, label, aliases];
}

/// Delete the saved place [addressId] belonging to [clientId], then reload the
/// list so the UI drops it.
class SavedPlacesDeleteRequested extends SavedPlacesEvent {
  final String clientId;
  final String addressId;

  const SavedPlacesDeleteRequested({
    required this.clientId,
    required this.addressId,
  });

  @override
  List<Object?> get props => [clientId, addressId];
}
