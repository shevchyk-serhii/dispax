import 'package:equatable/equatable.dart';

enum CreateRideFormStatus { initial, submitting, success, failure }

class CreateRideFormState extends Equatable {
  final String clientName;
  final String? selectedClientId;
  final String? selectedDriverId;
  final String fromAddress;
  final String toAddress;
  final String flightNumber;
  final DateTime pickupDateTime;
  final bool isAirportTransfer;
  final bool isArrival;
  final String? selectedGate;
  final String? selectedTerminal;
  final CreateRideFormStatus status;
  final String? errorMessage;
  final bool showNotes;
  final String notes;
  final List<String> specialRequirements;
  final bool isNewClient;
  final String newClientPhone;

  // Baseline values for fields that are auto-preselected (driver/client = self).
  // These are NOT counted as user modifications by [isModified].
  final String? baselineClientId;
  final String baselineClientName;
  final String? baselineDriverId;

  const CreateRideFormState({
    required this.clientName,
    this.selectedClientId,
    this.selectedDriverId,
    required this.fromAddress,
    required this.toAddress,
    required this.flightNumber,
    required this.pickupDateTime,
    required this.isAirportTransfer,
    required this.isArrival,
    this.selectedGate,
    this.selectedTerminal,
    this.status = CreateRideFormStatus.initial,
    this.errorMessage,
    this.showNotes = false,
    this.notes = '',
    this.specialRequirements = const [],
    this.isNewClient = false,
    this.newClientPhone = '',
    this.baselineClientId,
    this.baselineClientName = '',
    this.baselineDriverId,
  });

  factory CreateRideFormState.initial() {
    return CreateRideFormState(
      clientName: '',
      selectedClientId: null,
      selectedDriverId: null,
      fromAddress: '',
      toAddress: '',
      flightNumber: '',
      pickupDateTime: DateTime.now().add(const Duration(hours: 1)),
      isAirportTransfer: false,
      isArrival: false,
      selectedGate: null,
      selectedTerminal: null,
      status: CreateRideFormStatus.initial,
      notes: '',
      specialRequirements: const [],
      isNewClient: false,
      newClientPhone: '',
    );
  }

  CreateRideFormState copyWith({
    String? clientName,
    String? selectedClientId,
    bool clearClientId = false,
    String? selectedDriverId,
    bool clearDriverId = false,
    String? fromAddress,
    String? toAddress,
    String? flightNumber,
    DateTime? pickupDateTime,
    bool? isAirportTransfer,
    bool? isArrival,
    String? selectedGate,
    String? selectedTerminal,
    CreateRideFormStatus? status,
    String? errorMessage,
    bool? showNotes,
    String? notes,
    List<String>? specialRequirements,
    bool? isNewClient,
    String? newClientPhone,
    String? baselineClientId,
    bool clearBaselineClientId = false,
    String? baselineClientName,
    String? baselineDriverId,
    bool clearBaselineDriverId = false,
  }) {
    return CreateRideFormState(
      clientName: clientName ?? this.clientName,
      selectedClientId: clearClientId
          ? null
          : (selectedClientId ?? this.selectedClientId),
      selectedDriverId: clearDriverId
          ? null
          : (selectedDriverId ?? this.selectedDriverId),
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      flightNumber: flightNumber ?? this.flightNumber,
      pickupDateTime: pickupDateTime ?? this.pickupDateTime,
      isAirportTransfer: isAirportTransfer ?? this.isAirportTransfer,
      isArrival: isArrival ?? this.isArrival,
      selectedGate: selectedGate ?? this.selectedGate,
      selectedTerminal: selectedTerminal ?? this.selectedTerminal,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      showNotes: showNotes ?? this.showNotes,
      notes: notes ?? this.notes,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      isNewClient: isNewClient ?? this.isNewClient,
      newClientPhone: newClientPhone ?? this.newClientPhone,
      baselineClientId: clearBaselineClientId
          ? null
          : (baselineClientId ?? this.baselineClientId),
      baselineClientName: baselineClientName ?? this.baselineClientName,
      baselineDriverId: clearBaselineDriverId
          ? null
          : (baselineDriverId ?? this.baselineDriverId),
    );
  }

  bool get isValid {
    final clientOk = isNewClient
        ? clientName.trim().isNotEmpty
        : selectedClientId != null;
    return clientOk &&
        fromAddress.trim().isNotEmpty &&
        toAddress.trim().isNotEmpty &&
        (!isAirportTransfer || flightNumber.trim().isNotEmpty);
  }

  /// The form is "modified" only when it differs from the baseline snapshot.
  /// Auto-preselected values (driver/client = the current user) are part of the
  /// baseline and therefore do NOT trigger the unsaved-changes guard.
  bool get isModified =>
      clientName.trim() != baselineClientName.trim() ||
      selectedClientId != baselineClientId ||
      selectedDriverId != baselineDriverId ||
      fromAddress.trim().isNotEmpty ||
      toAddress.trim().isNotEmpty ||
      flightNumber.trim().isNotEmpty ||
      notes.trim().isNotEmpty ||
      specialRequirements.isNotEmpty;

  @override
  List<Object?> get props => [
    clientName,
    selectedClientId,
    selectedDriverId,
    fromAddress,
    toAddress,
    flightNumber,
    pickupDateTime,
    isAirportTransfer,
    isArrival,
    selectedGate,
    selectedTerminal,
    status,
    errorMessage,
    showNotes,
    notes,
    specialRequirements,
    isNewClient,
    newClientPhone,
    baselineClientId,
    baselineClientName,
    baselineDriverId,
  ];
}
