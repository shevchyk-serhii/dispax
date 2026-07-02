import 'package:flutter/material.dart';
import '../modules/core/services/error_messages.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/blocs.dart';
import '../modules/core/models/person.dart';
import '../../modules/ride_management/models/ride.dart';
import '../constants/app_colors.dart';
import '../modules/ride_management/models/payment_method.dart';
import '../modules/ride_management/widgets/widgets.dart';
import '../modules/ride_management/widgets/ride_lifecycle_stepper.dart';
import '../modules/ride_management/services/ride_service.dart';
import '../modules/core/navigation_utils.dart';
import '../widgets/common/cancel_ride_dialog.dart';
import '../widgets/common/rate_ride_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import '../l10n/app_localizations.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;
  final bool isClientView;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    this.isClientView = false,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late Ride _currentRide;
  late RideService _rideService;
  bool _isLoading = false;
  bool _isRefreshingFlight = false;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEta());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideService = RideService(apiClient: context.read<AuthBloc>().apiClient);
  }

  Future<void> _loadEta() async {
    if (!mounted || widget.isClientView) return;
    final data = await _rideService.getDriverProximity(_currentRide.id);
    if (!mounted) return;
    final eta = data?['etaMinutes'] as int?;
    if (eta != null) {
      setState(() {
        _currentRide = _currentRide.copyWith(etaMinutes: eta);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isClientView
              ? l10n.myRideTitle(
                  DateFormat('dd.MM HH:mm').format(_currentRide.pickupDateTime),
                )
              : l10n.rideTitle(_currentRide.clientName),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator.adaptive())
          : Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RideLifecycleStepperWidget(
                        ride: _currentRide,
                        isClientView: widget.isClientView,
                      ),
                      const SizedBox(height: 8),

                      // Confirmation indicator
                      if (_currentRide.confirmationSent)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.rideCompletedBgDark
                                : AppColors.successBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.successBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: isDark
                                    ? AppColors.rideCompletedTextDark
                                    : AppColors.successStrong,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.confirmationSentLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.rideCompletedTextDark
                                      : AppColors.successStrong,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Payment status indicator
                      if (_currentRide.paymentStatus != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _currentRide.paymentStatus == 'Paid'
                                ? (isDark
                                      ? AppColors.rideCompletedBgDark
                                      : AppColors.successBg)
                                : (isDark
                                      ? AppColors.rideRequestedBgDark
                                      : AppColors.warningBg),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _currentRide.paymentStatus == 'Paid'
                                  ? AppColors.successBorder
                                  : AppColors.warningBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _currentRide.paymentStatus == 'Paid'
                                    ? Icons.payment
                                    : Icons.pending,
                                size: 18,
                                color: _currentRide.paymentStatus == 'Paid'
                                    ? (isDark
                                          ? AppColors.rideCompletedTextDark
                                          : AppColors.successStrong)
                                    : (isDark
                                          ? AppColors.rideRequestedTextDark
                                          : AppColors.warningStrong),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                () {
                                  final method = PaymentMethod.labelForWire(
                                    _currentRide.paymentMethod,
                                    l10n,
                                  );
                                  return '${_currentRide.paymentStatus}${method != null ? ' ($method)' : ''}';
                                }(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _currentRide.paymentStatus == 'Paid'
                                      ? (isDark
                                            ? AppColors.rideCompletedTextDark
                                            : AppColors.successStrong)
                                      : (isDark
                                            ? AppColors.rideRequestedTextDark
                                            : AppColors.warningStrong),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Cancellation info
                      if (_currentRide.status == RideStatus.cancelled &&
                          _currentRide.cancellationReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.rideCancelledBgDark
                                : AppColors.errorBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.errorBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.cancellationDetailsTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.rideCancelledTextDark
                                      : AppColors.errorStrong,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.cancellationReasonDetail(
                                  _currentRide.cancellationReason ?? '',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.rideCancelledTextDark
                                      : AppColors.errorStrong,
                                ),
                              ),
                              if (_currentRide.cancelledBy != null)
                                Text(
                                  l10n.cancelledByLabel(
                                    _currentRide.cancelledBy ?? '',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.rideCancelledTextDark
                                        : AppColors.errorStrong,
                                  ),
                                ),
                              if ((_currentRide.cancellationFee ?? 0) > 0)
                                Text(
                                  l10n.cancellationFeeDisplay(
                                    (_currentRide.cancellationFee ?? 0)
                                        .toStringAsFixed(2),
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.rideCancelledTextDark
                                        : AppColors.errorStrong,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Rating info
                      if (_currentRide.rating != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.rideRequestedBgDark
                                : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warningBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.ratingTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.rideRequestedTextDark
                                      : AppColors.warningStrong,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < (_currentRide.rating ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if ((_currentRide.ratingComment ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _currentRide.ratingComment ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.rideRequestedTextDark
                                        : AppColors.warningStrong,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Rate ride button for clients on completed unrated rides
                      if (widget.isClientView &&
                          _currentRide.status == RideStatus.completed &&
                          _currentRide.rating == null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _rateRide(context),
                            icon: const Icon(Icons.star),
                            label: Text(l10n.rateThisRide),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],

                      // Notes and special requirements
                      if ((_currentRide.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.rideAssignedBgDark
                                : AppColors.infoBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.infoBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.notesTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.rideAssignedTextDark
                                      : AppColors.infoStrong,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentRide.notes ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.rideAssignedTextDark
                                      : AppColors.infoStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if ((_currentRide.specialRequirements ?? '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            _currentRide.specialRequirements ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      if (_currentRide.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _currentRide.tags
                              .map(
                                (tag) => Chip(
                                  avatar: const Icon(
                                    Icons.label_outline,
                                    size: 14,
                                  ),
                                  label: Text(
                                    tag,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 16),

                      RideRouteCard(ride: _currentRide),
                      const SizedBox(height: 16),

                      if (_currentRide.isAirportTransfer) ...[
                        RideFlightCard(
                          ride: _currentRide,
                          isRefreshing: _isRefreshingFlight,
                          // Clients can't refresh (the endpoint is staff-only), so don't
                          // offer them a button that would only 403.
                          onRefresh: widget.isClientView
                              ? null
                              : _refreshFlightStatus,
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_currentRide.driver case final driver?
                          when widget.isClientView)
                        RidePersonCard(
                          person: driver,
                          apiClient: context.read<AuthBloc>().apiClient,
                          isDriver: true,
                          onCall: () => _makePhoneCall(driver.phone),
                          onMessage: () => _sendMessage(driver.phone),
                        )
                      else if (!widget.isClientView)
                        RidePersonCard(
                          person: _currentRide.client,
                          apiClient: context.read<AuthBloc>().apiClient,
                          isDriver: false,
                          onCall: () =>
                              _makePhoneCall(_currentRide.client.phone),
                          onMessage: () =>
                              _sendMessage(_currentRide.client.phone),
                        ),
                      const SizedBox(height: 16),

                      if (_currentRide.status == RideStatus.assigned ||
                          _currentRide.status == RideStatus.inProgress)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ChatScreen(ride: _currentRide),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat),
                              label: Text(l10n.openChatButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),

                      RideActionsCard(
                        ride: _currentRide,
                        isClientView: widget.isClientView,
                        onEditRide: _canEditRide()
                            ? () => _editRide(context)
                            : null,
                        onDuplicateRide: () => _duplicateRide(context),
                        onCancelRide: _canCancelRide()
                            ? () => _cancelRide(context)
                            : null,
                        onStartRide: _canStartRide()
                            ? () => _startRide(context)
                            : null,
                        onCompleteRide: _canCompleteRide()
                            ? () => _completeRide(context)
                            : null,
                        onAssignDriver: _canAssignDriver()
                            ? () => _assignDriver(context)
                            : null,
                        onViewOnMap: () => _viewOnMap(context),
                        onShareRide: () => _shareRide(context),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  bool _canEditRide() {
    final editableStatus =
        _currentRide.status == RideStatus.requested ||
        _currentRide.status == RideStatus.assigned;
    if (!editableStatus) return false;
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;
    if (user == null) return false;
    return user.role == PersonRole.dispatcher ||
        _currentRide.creatorId == user.id;
  }

  bool _canCancelRide() {
    return _currentRide.status != RideStatus.completed;
  }

  bool _canStartRide() {
    return !widget.isClientView && _currentRide.status == RideStatus.assigned;
  }

  bool _canCompleteRide() {
    return !widget.isClientView && _currentRide.status == RideStatus.inProgress;
  }

  bool _canAssignDriver() {
    return !widget.isClientView && _currentRide.status == RideStatus.requested;
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber?.isEmpty != false) return;

    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendMessage(String? phoneNumber) async {
    if (phoneNumber?.isEmpty != false) return;

    final uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _editRide(BuildContext context) async {
    final result = await NavigationUtils.navigateToEditRide(
      context,
      _currentRide,
    );
    if (result != null) {
      setState(() {
        _currentRide = result;
      });
    }
  }

  Future<void> _duplicateRide(BuildContext context) =>
      NavigationUtils.duplicateRide(context, _currentRide);

  Future<void> _cancelRide(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final authState = context.read<AuthBloc>().state;
    // Default to the most-restricted role (client) when unknown, so a missing
    // role never unlocks staff-only cancellation reasons.
    final role = authState.user?.role ?? PersonRole.client;
    // Capture the RideBloc before crossing the first async gap so that the
    // reference remains valid regardless of whether the widget stays mounted.
    final rideBloc = context.read<RideBloc>();

    final result = await showAdaptiveDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => CancelRideDialog(role: role),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        await _rideService.cancelRide(
          _currentRide.id,
          result['reason'] as String,
          fee: result['fee'] as double?,
        );
        final cancelledRide = _currentRide.copyWith(
          status: RideStatus.cancelled,
          cancellationReason: result['reason'] as String?,
          cancellationFee: result['fee'] as double?,
          cancelledBy: authState.user?.name,
        );
        setState(() {
          _currentRide = cancelledRide;
        });
        // Update the shared RideBloc so lists (e.g. ClientRideHistoryScreen)
        // immediately reflect the cancelled status without waiting for a WS event.
        rideBloc.add(RideUpdated(ride: cancelledRide));
        _showSuccessMessage(l10n.rideCancelledSuccess);
      } catch (e) {
        _showErrorMessage(l10n.failedToCancelRide(friendlyError(e, l10n)));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rateRide(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final apiClient = context.read<AuthBloc>().apiClient;

    final result = await showAdaptiveDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => RateRideDialog(rideId: _currentRide.id),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        await apiClient.post('/rides/${_currentRide.id}/rate', {
          'rating': result['rating'],
          'comment': result['comment'],
        });
        setState(() {
          _currentRide = _currentRide.copyWith(
            rating: result['rating'] as int?,
            ratingComment: result['comment'] as String?,
          );
        });
        _showSuccessMessage(l10n.thankYouForRating);
      } catch (e) {
        _showErrorMessage(l10n.failedToSubmitRating(friendlyError(e, l10n)));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startRide(BuildContext context) async {
    await _updateRideStatus(RideStatus.inProgress);
  }

  Future<void> _completeRide(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmationDialog(
      context,
      l10n.completeRideDialogTitle,
      l10n.completeRideDialogContent,
    );

    if (confirmed) {
      await _updateRideStatus(RideStatus.completed);
    }
  }

  Future<void> _assignDriver(BuildContext context) async {
    final driver = await NavigationUtils.navigateToDriverSelection(context);
    if (driver != null) {
      await _updateRideWithDriver(driver);
    }
  }

  Future<void> _viewOnMap(BuildContext context) async {
    NavigationUtils.navigateToMap(context, _currentRide);
  }

  Future<void> _shareRide(BuildContext context) async {
    await NavigationUtils.shareRide(context, _currentRide);
  }

  Future<void> _updateRideStatus(RideStatus newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final success = await _rideService.updateRideStatus(
        _currentRide.id,
        newStatus,
      );
      if (success) {
        setState(() {
          _currentRide = _currentRide.copyWith(status: newStatus);
        });
      }

      _showSuccessMessage(l10n.rideStatusUpdatedSuccess);
    } catch (e) {
      _showErrorMessage(l10n.failedToUpdateRideStatus(friendlyError(e, l10n)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRideWithDriver(Person driver) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final updatedRide = await _rideService.assignDriver(
        _currentRide.id,
        driver.id,
      );
      setState(() {
        _currentRide = updatedRide;
      });

      _showSuccessMessage(l10n.driverAssignedSuccess);
    } catch (e) {
      _showErrorMessage(l10n.failedToAssignDriver(friendlyError(e, l10n)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    return await showAdaptiveDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _refreshFlightStatus() async {
    final l10n = AppLocalizations.of(context)!;
    // Capture the RideBloc before the async gap so the reference stays valid.
    final rideBloc = context.read<RideBloc>();
    setState(() => _isRefreshingFlight = true);
    try {
      final result = await _rideService.refreshFlightStatus(_currentRide.id);
      if (!mounted) return;
      // Patch ONLY the flight fields onto the existing ride — the refresh DTO is not
      // fully enriched, so replacing the whole ride would de-enrich the shared
      // RideBloc copy and blank driverName/optimalEntryTime/avatar/eta on the list
      // cards (the confirm-vanish overwrite trap). See Ride.withFlightFrom.
      final patched = _currentRide.withFlightFrom(result.ride);
      setState(() => _currentRide = patched);
      // Push the patched ride so other screens (list cards) reflect it too.
      rideBloc.add(RideUpdated(ride: patched));
      _showSuccessMessage(switch (result.outcome) {
        'updated' => l10n.flightStatusRefreshed,
        'notFound' => l10n.flightNotFoundYet,
        _ => l10n.flightStatusUnchanged,
      });
    } catch (_) {
      if (mounted) _showErrorMessage(l10n.failedToRefreshFlightStatus);
    } finally {
      if (mounted) setState(() => _isRefreshingFlight = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
