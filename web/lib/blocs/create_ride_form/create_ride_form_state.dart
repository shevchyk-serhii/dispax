import 'package:equatable/equatable.dart';
import '../../modules/ride_management/models/payment_method.dart';
import '../../modules/ride_management/models/vehicle_class.dart';
import '../../modules/ride_management/models/ride_estimate.dart';

enum CreateRideFormStatus { initial, submitting, success, failure }

class CreateRideFormState extends Equatable {
  final String clientName;
  final String? selectedClientId;
  final String? selectedDriverId;
  final String fromAddress;
  final String toAddress;
  final String flightNumber;

  /// Explicit pickup time set by the operator. When null for airport departure rides
  /// the backend computes it automatically from [flightDepartureTime]. For all other
  /// ride types this field must be non-null before submission.
  final DateTime? manualPickupDateTime;

  /// Flight departure date-time for airport departure rides.
  /// Required when [isAirportTransfer] = true and [isArrival] = false.
  final DateTime? flightDepartureTime;

  final bool isAirportTransfer;
  final bool isArrival;
  final String? selectedGate;
  final String? selectedTerminal;
  final CreateRideFormStatus status;
  final String? errorMessage;
  final bool showNotes;
  final String notes;
  final List<String> specialRequirements;

  /// Free-form operator tags attached to the ride at creation.
  final List<String> tags;
  final bool isNewClient;
  final bool isProvisionalClient;
  final String newClientPhone;

  // Baseline values for fields that are auto-preselected (driver/client = self).
  // These are NOT counted as user modifications by [isModified].
  final String? baselineClientId;
  final String baselineClientName;
  final String? baselineDriverId;

  /// Operator-supplied ride price (€). Optional — when null the ride is created
  /// without a price and it can be set later. Independent of the auto-computed
  /// estimate ([estimateBusiness]/[estimateVan]): the operator types it manually.
  final double? price;

  /// Operator-selected payment method. Defaults to [PaymentMethod.invoice]
  /// (Rechnung) and is always submitted with the ride.
  final PaymentMethod selectedPaymentMethod;

  // ─── Client booking extensions ───
  /// Selected vehicle class for the client booking flow.
  final VehicleClass selectedVehicleClass;

  /// Whether the ride is scheduled (true) or ASAP / Now (false).
  final bool isScheduled;

  /// Estimate returned for the business vehicle class.
  final RideEstimate? estimateBusiness;

  /// Estimate returned for the van vehicle class.
  final RideEstimate? estimateVan;

  /// True when an estimate was requested (addresses filled) but the backend
  /// could not return one — e.g. the address could not be geocoded. Drives a
  /// hint in the UI instead of a silent "—".
  final bool estimateUnavailable;

  const CreateRideFormState({
    required this.clientName,
    this.selectedClientId,
    this.selectedDriverId,
    required this.fromAddress,
    required this.toAddress,
    required this.flightNumber,
    this.manualPickupDateTime,
    this.flightDepartureTime,
    required this.isAirportTransfer,
    required this.isArrival,
    this.selectedGate,
    this.selectedTerminal,
    this.status = CreateRideFormStatus.initial,
    this.errorMessage,
    this.showNotes = false,
    this.notes = '',
    this.specialRequirements = const [],
    this.tags = const [],
    this.isNewClient = false,
    this.isProvisionalClient = false,
    this.newClientPhone = '',
    this.baselineClientId,
    this.baselineClientName = '',
    this.baselineDriverId,
    this.price,
    this.selectedPaymentMethod = PaymentMethod.invoice,
    this.selectedVehicleClass = VehicleClass.business,
    this.isScheduled = true,
    this.estimateBusiness,
    this.estimateVan,
    this.estimateUnavailable = false,
  });

  factory CreateRideFormState.initial() {
    return CreateRideFormState(
      clientName: '',
      selectedClientId: null,
      selectedDriverId: null,
      fromAddress: '',
      toAddress: '',
      flightNumber: '',
      manualPickupDateTime: DateTime.now().add(const Duration(hours: 1)),
      flightDepartureTime: null,
      isAirportTransfer: false,
      isArrival: false,
      selectedGate: null,
      selectedTerminal: null,
      status: CreateRideFormStatus.initial,
      notes: '',
      specialRequirements: const [],
      tags: const [],
      isNewClient: false,
      isProvisionalClient: false,
      newClientPhone: '',
      selectedPaymentMethod: PaymentMethod.invoice,
      selectedVehicleClass: VehicleClass.business,
      isScheduled: true,
      estimateBusiness: null,
      estimateVan: null,
      estimateUnavailable: false,
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
    DateTime? manualPickupDateTime,
    bool clearManualPickupDateTime = false,
    DateTime? flightDepartureTime,
    bool clearFlightDepartureTime = false,
    bool? isAirportTransfer,
    bool? isArrival,
    String? selectedGate,
    String? selectedTerminal,
    CreateRideFormStatus? status,
    String? errorMessage,
    bool? showNotes,
    String? notes,
    List<String>? specialRequirements,
    List<String>? tags,
    bool? isNewClient,
    bool? isProvisionalClient,
    String? newClientPhone,
    String? baselineClientId,
    bool clearBaselineClientId = false,
    String? baselineClientName,
    String? baselineDriverId,
    bool clearBaselineDriverId = false,
    double? price,
    bool clearPrice = false,
    PaymentMethod? selectedPaymentMethod,
    VehicleClass? selectedVehicleClass,
    bool? isScheduled,
    RideEstimate? estimateBusiness,
    bool clearEstimateBusiness = false,
    RideEstimate? estimateVan,
    bool clearEstimateVan = false,
    bool? estimateUnavailable,
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
      manualPickupDateTime: clearManualPickupDateTime
          ? null
          : (manualPickupDateTime ?? this.manualPickupDateTime),
      flightDepartureTime: clearFlightDepartureTime
          ? null
          : (flightDepartureTime ?? this.flightDepartureTime),
      isAirportTransfer: isAirportTransfer ?? this.isAirportTransfer,
      isArrival: isArrival ?? this.isArrival,
      selectedGate: selectedGate ?? this.selectedGate,
      selectedTerminal: selectedTerminal ?? this.selectedTerminal,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      showNotes: showNotes ?? this.showNotes,
      notes: notes ?? this.notes,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      tags: tags ?? this.tags,
      isNewClient: isNewClient ?? this.isNewClient,
      isProvisionalClient: isProvisionalClient ?? this.isProvisionalClient,
      newClientPhone: newClientPhone ?? this.newClientPhone,
      baselineClientId: clearBaselineClientId
          ? null
          : (baselineClientId ?? this.baselineClientId),
      baselineClientName: baselineClientName ?? this.baselineClientName,
      baselineDriverId: clearBaselineDriverId
          ? null
          : (baselineDriverId ?? this.baselineDriverId),
      price: clearPrice ? null : (price ?? this.price),
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedVehicleClass: selectedVehicleClass ?? this.selectedVehicleClass,
      isScheduled: isScheduled ?? this.isScheduled,
      estimateBusiness: clearEstimateBusiness
          ? null
          : (estimateBusiness ?? this.estimateBusiness),
      estimateVan: clearEstimateVan ? null : (estimateVan ?? this.estimateVan),
      estimateUnavailable: estimateUnavailable ?? this.estimateUnavailable,
    );
  }

  /// The estimate for the currently selected vehicle class.
  RideEstimate? get activeEstimate =>
      selectedVehicleClass == VehicleClass.van ? estimateVan : estimateBusiness;

  /// True when the departure auto-compute path is active (no manual pickup needed).
  bool get isDepartureAutoCompute => isAirportTransfer && !isArrival;

  bool get isValid {
    final clientOk = isProvisionalClient
        ? true
        : isNewClient
        ? clientName.trim().isNotEmpty
        : selectedClientId != null;
    // For departure rides: flightDepartureTime is required; manualPickupDateTime is optional.
    // For all other rides: manualPickupDateTime is required.
    final pickupOk = isDepartureAutoCompute
        ? flightDepartureTime != null
        : manualPickupDateTime != null;
    return clientOk &&
        fromAddress.trim().isNotEmpty &&
        toAddress.trim().isNotEmpty &&
        (!isAirportTransfer || flightNumber.trim().isNotEmpty) &&
        fromAddress.trim().toLowerCase() != toAddress.trim().toLowerCase() &&
        pickupOk;
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
      specialRequirements.isNotEmpty ||
      tags.isNotEmpty ||
      price != null;

  @override
  List<Object?> get props => [
    clientName,
    selectedClientId,
    selectedDriverId,
    fromAddress,
    toAddress,
    flightNumber,
    manualPickupDateTime,
    flightDepartureTime,
    isAirportTransfer,
    isArrival,
    selectedGate,
    selectedTerminal,
    status,
    errorMessage,
    showNotes,
    notes,
    specialRequirements,
    tags,
    isNewClient,
    isProvisionalClient,
    newClientPhone,
    baselineClientId,
    baselineClientName,
    baselineDriverId,
    price,
    selectedPaymentMethod,
    selectedVehicleClass,
    isScheduled,
    estimateBusiness,
    estimateVan,
    estimateUnavailable,
  ];
}
