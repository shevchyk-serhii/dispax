import 'package:equatable/equatable.dart';
import '../../modules/core/models/user_requests.dart';

abstract class ClientEvent extends Equatable {
  const ClientEvent();

  @override
  List<Object?> get props => [];
}

class ClientLoadRequested extends ClientEvent {
  const ClientLoadRequested();
}

class ClientCreateRequested extends ClientEvent {
  final CreateUserRequest request;

  const ClientCreateRequested({required this.request});

  @override
  List<Object> get props => [request];
}

class ClientUpdateRequested extends ClientEvent {
  final String clientId;
  final UpdateUserRequest request;

  const ClientUpdateRequested({required this.clientId, required this.request});

  @override
  List<Object> get props => [clientId, request];
}

class ClientDeactivateRequested extends ClientEvent {
  final String clientId;

  const ClientDeactivateRequested({required this.clientId});

  @override
  List<Object> get props => [clientId];
}

class ClientSearchRequested extends ClientEvent {
  final String query;

  const ClientSearchRequested({required this.query});

  @override
  List<Object> get props => [query];
}
