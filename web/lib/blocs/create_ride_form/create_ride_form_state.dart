import 'package:equatable/equatable.dart';

enum CreateRideFormStatus { initial, submitting, success, failure }

class CreateRideFormState extends Equatable {
  final String clientName;
  final String? selectedClientId;
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

  const CreateRideFormState({
    required this.clientName,
    this.selectedClientId,
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
  });

  factory CreateRideFormState.initial() {
    return CreateRideFormState(
      clientName: '',
      selectedClientId: null,
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
    );
  }

  CreateRideFormState copyWith({
    String? clientName,
    String? selectedClientId,
    bool clearClientId = false,
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
  }) {
    return CreateRideFormState(
      clientName: clientName ?? this.clientName,
      selectedClientId: clearClientId ? null : (selectedClientId ?? this.selectedClientId),
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
    );
  }

  bool get isValid {
    return selectedClientId != null &&
           fromAddress.trim().isNotEmpty &&
           toAddress.trim().isNotEmpty &&
           (!isAirportTransfer || flightNumber.trim().isNotEmpty);
  }

  @override
  List<Object?> get props => [
    clientName,
    selectedClientId,
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
  ];
}
