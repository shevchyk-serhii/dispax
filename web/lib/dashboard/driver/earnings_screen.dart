import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/driver_earnings.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../widgets/widgets.dart';

/// Driver earnings screen: period switcher, metrics, and revenue chart.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;

    return BlocProvider(
      create: (_) {
        final cubit = EarningsCubit();
        if (user != null) cubit.load(user.id.toString());
        return cubit;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('My Earnings')),
        body: AppTheme.buildGradientContainer(
          colors: AppColors.driverGradient,
          child: const _EarningsBody(),
        ),
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EarningsCubit, EarningsState>(
      builder: (context, state) {
        final cubit = context.read<EarningsCubit>();

        return Column(
          children: [
            _buildPeriodSelector(context, state),
            _buildNavigator(context, state),
            Expanded(child: _buildContent(context, state, cubit)),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    EarningsState state,
    EarningsCubit cubit,
  ) {
    if (state.status == EarningsStatus.loading && state.data == null) {
      return const LoadingWidget();
    }
    if (state.status == EarningsStatus.error && state.data == null) {
      return ErrorDisplayWidget(
        title: 'Failed to load earnings',
        message: state.error ?? 'Unknown error',
        onRetry: () {
          final user = context.read<AuthBloc>().state.user;
          if (user != null) cubit.load(user.id.toString());
        },
      );
    }

    final data = state.data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      children: [
        _buildHeadline(context, data),
        const SizedBox(height: AppDimensions.paddingLarge),
        _buildMetricsGrid(context, data),
        const SizedBox(height: AppDimensions.paddingLarge),
        _buildChart(context, data),
        const SizedBox(height: AppDimensions.paddingXLarge),
      ],
    );
  }

  Widget _buildHeadline(BuildContext context, DriverEarnings data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gross revenue',
            style: AppStyles.labelMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            '€${data.grossRevenue.toStringAsFixed(2)}',
            style: AppStyles.headlineMedium.copyWith(
              color: AppColors.driverColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            'Net €${data.netRevenue.toStringAsFixed(2)} '
            '· after €${data.totalExpenses.toStringAsFixed(2)} expenses',
            style: AppStyles.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DriverEarnings data) {
    return Row(
      children: [
        _metricCard(
          context,
          icon: Icons.check_circle,
          value: data.completedRides.toString(),
          label: 'Completed',
          color: AppColors.success,
        ),
        const SizedBox(width: AppDimensions.paddingMedium),
        _metricCard(
          context,
          icon: Icons.euro,
          value: '€${data.avgFare.toStringAsFixed(0)}',
          label: 'Avg fare',
          color: AppColors.driverColor,
        ),
        const SizedBox(width: AppDimensions.paddingMedium),
        _metricCard(
          context,
          icon: Icons.cancel,
          value: data.cancelledRides.toString(),
          label: 'Cancelled',
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: AppTheme.glassDecoration,
        child: Column(
          children: [
            Icon(icon, color: color, size: AppDimensions.iconMedium),
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              value,
              style: AppStyles.titleMedium.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppStyles.labelSmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, DriverEarnings data) {
    final colorScheme = Theme.of(context).colorScheme;
    final buckets = data.buckets;
    final maxAmount = buckets.fold<double>(
      0,
      (m, b) => b.amount > m ? b.amount : m,
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.glassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by ${data.period == 'day' ? 'hour' : 'day'}',
            style: AppStyles.titleMedium.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppDimensions.paddingLarge),
          if (buckets.isEmpty || maxAmount == 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No revenue in this period',
                  style: AppStyles.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets
                    .map((b) => _bar(colorScheme, b, maxAmount, data.period))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(
    ColorScheme colorScheme,
    EarningsBucket bucket,
    double maxAmount,
    String period,
  ) {
    final fraction = maxAmount == 0 ? 0.0 : bucket.amount / maxAmount;
    final label = period == 'day'
        ? '${bucket.bucketStart.hour}'
        : '${bucket.bucketStart.day}';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (bucket.amount > 0)
              Text(
                bucket.amount.toStringAsFixed(0),
                style: AppStyles.labelSmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            const SizedBox(height: 2),
            Container(
              height: (120 * fraction).clamp(2, 120),
              decoration: BoxDecoration(
                color: AppColors.driverColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppStyles.labelSmall.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, EarningsState state) {
    final cubit = context.read<EarningsCubit>();
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingLarge,
        AppDimensions.paddingLarge,
        AppDimensions.paddingLarge,
        0,
      ),
      child: Row(
        children: [
          _periodChip(context, 'Day', EarningsPeriod.day, state, cubit),
          const SizedBox(width: 8),
          _periodChip(context, 'Week', EarningsPeriod.week, state, cubit),
          const SizedBox(width: 8),
          _periodChip(context, 'Month', EarningsPeriod.month, state, cubit),
        ],
      ),
    );
  }

  Widget _periodChip(
    BuildContext context,
    String label,
    EarningsPeriod period,
    EarningsState state,
    EarningsCubit cubit,
  ) {
    final selected = state.period == period;
    return GestureDetector(
      onTap: () => cubit.setPeriod(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.driverColor : Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.driverColor
                : Colors.white.withAlpha(80),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white.withAlpha(200),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigator(BuildContext context, EarningsState state) {
    final cubit = context.read<EarningsCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: cubit.prevPeriod,
          ),
          Expanded(
            child: Center(
              child: Text(
                _rangeLabel(state),
                style: AppStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: cubit.nextPeriod,
          ),
        ],
      ),
    );
  }

  String _rangeLabel(EarningsState state) {
    final d = state.anchorDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    switch (state.period) {
      case EarningsPeriod.day:
        return '${d.day} ${months[d.month - 1]} ${d.year}';
      case EarningsPeriod.week:
        final monday = d.subtract(Duration(days: d.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${monday.day} ${months[monday.month - 1]} – '
            '${sunday.day} ${months[sunday.month - 1]}';
      case EarningsPeriod.month:
        return '${months[d.month - 1]} ${d.year}';
    }
  }
}
