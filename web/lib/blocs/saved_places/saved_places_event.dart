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
