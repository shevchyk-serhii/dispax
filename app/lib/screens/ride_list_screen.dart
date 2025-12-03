import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../utils/navigation_helper.dart';
import '../widgets/widgets.dart';
import 'ride_detail_screen.dart';
import 'ride_form_screen.dart';

class RideListScreen extends StatelessWidget {
  const RideListScreen({super.key});

  void loadRidesIfAuthenticated(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  void refreshRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideRefreshRequested(user: authState.user!));
    }
  }

  void deleteRide(BuildContext context, int id) {
    context.read<RideBloc>().add(RideDeleteRequested(rideId: id));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RideBloc, RideState>(
          listener: (context, state) {
            if (state.hasError) {
              NavigationHelper.showSnackBar(
                context,
                state.errorMessage!,
                isError: true,
              );
            }
          },
        ),
        BlocListener<RideBloc, RideState>(
          listenWhen: (previous, current) =>
              previous.isDeleting && current.isLoaded,
          listener: (context, state) {
            NavigationHelper.showSnackBar(context, 'Ride deleted successfully');
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rides'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => refreshRides(context),
            ),
          ],
        ),
        body: BlocBuilder<RideBloc, RideState>(
          builder: (context, rideState) => buildBody(context, rideState),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await NavigationHelper.push(
              context,
              const RideFormScreen(),
            );
            if (result == true && context.mounted) {
              refreshRides(context);
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context, RideState rideState) {
    // Load rides on first build if not loaded yet
    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadRidesIfAuthenticated(context),
      );
    }

    if (rideState.isLoading) {
      return const LoadingWidget();
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        message: rideState.errorMessage!,
        onRetry: () => refreshRides(context),
      );
    }

    if (rideState.isEmpty) {
      return const EmptyStateWidget(
        message: 'No rides available',
        icon: Icons.directions_car_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: ListView.builder(
        itemCount: rideState.rides.length,
        itemBuilder: (context, index) {
          final ride = rideState.rides[index];
          final isDeleting =
              rideState.isDeleting && rideState.deletingRideId == ride.id;

          return RideCard(
            ride: ride,
            onTap: isDeleting
                ? null
                : () => NavigationHelper.push(
                    context,
                    RideDetailScreen(ride: ride),
                  ),
            onEdit: isDeleting
                ? null
                : () =>
                      NavigationHelper.push(
                        context,
                        RideFormScreen(ride: ride),
                      ).then((result) {
                        if (result == true && context.mounted) {
                          refreshRides(context);
                        }
                      }),
            onDelete: isDeleting
                ? null
                : () => DeleteConfirmationDialog.show(
                    context,
                    ride,
                    () => deleteRide(context, ride.id),
                  ),
          );
        },
      ),
    );
  }
}
