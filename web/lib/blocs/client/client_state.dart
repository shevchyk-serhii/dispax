import 'package:equatable/equatable.dart';
import '../../modules/core/services/api_client.dart' show ApiException;
import '../../modules/core/models/person.dart';

enum ClientStateStatus { initial, loading, loaded, error }

class ClientState extends Equatable {
  final ClientStateStatus status;
  final List<Person> clients;
  final String? errorMessage;

  /// Typed cause behind an error state, for `friendlyError`. Additive.
  final Object? error;
  final String searchQuery;

  const ClientState({
    this.status = ClientStateStatus.initial,
    this.clients = const [],
    this.errorMessage,
    this.error,
    this.searchQuery = '',
  });

  factory ClientState.initial() => const ClientState();

  factory ClientState.loading() =>
      const ClientState(status: ClientStateStatus.loading);

  factory ClientState.loaded(List<Person> clients) =>
      ClientState(status: ClientStateStatus.loaded, clients: clients);

  factory ClientState.error(String message, {Object? cause}) => ClientState(
    status: ClientStateStatus.error,
    errorMessage: message,
    error: cause,
  );

  ClientState copyWith({
    ClientStateStatus? status,
    List<Person>? clients,
    String? errorMessage,
    Object? error,
    String? searchQuery,
  }) {
    return ClientState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      errorMessage: errorMessage,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Person> get filteredClients {
    if (searchQuery.isEmpty) return clients;
    final query = searchQuery.toLowerCase();
    return clients.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query) ||
          (c.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  bool get isLoading => status == ClientStateStatus.loading;
  bool get isLoaded => status == ClientStateStatus.loaded;
  bool get hasError => status == ClientStateStatus.error;

  @override
  List<Object?> get props => [
    status,
    clients,
    errorMessage,
    error is ApiException ? (error as ApiException).kind : error?.runtimeType,
    searchQuery,
  ];
}
