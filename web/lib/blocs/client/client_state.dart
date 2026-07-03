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

  /// True when the error state came from a MUTATION (create/update/deactivate)
  /// rather than a list load. The panel uses this to keep mutation failures as
  /// a SnackBar even when the list is empty — a failed FIRST create must not
  /// render the full-screen "Error loading data" view, whose Retry reloads the
  /// list instead of retrying the creation.
  final bool isMutationError;
  final String searchQuery;

  const ClientState({
    this.status = ClientStateStatus.initial,
    this.clients = const [],
    this.errorMessage,
    this.error,
    this.isMutationError = false,
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
    // [errorMessage]/[error] use a sentinel so callers can distinguish "leave
    // as is" (omit the argument) from "explicitly clear it" (pass null). An
    // omitted argument used to silently null the field, losing the error text
    // on any unrelated copyWith. Same pattern as RideState.copyWith.
    Object? errorMessage = _unset,
    Object? error = _unset,
    bool? isMutationError,
    String? searchQuery,
  }) {
    return ClientState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      error: identical(error, _unset) ? this.error : error,
      isMutationError: isMutationError ?? this.isMutationError,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  static const Object _unset = Object();

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
    isMutationError,
    searchQuery,
  ];
}
