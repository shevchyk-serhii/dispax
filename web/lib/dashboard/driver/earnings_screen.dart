import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/driver_earnings.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../widgets/widgets.dart';

/// Driver earnings screen: graphite header, period switcher, breakdown cards.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    return BlocProvider(
      create: (_) {
        final cubit = EarningsCubit(
          rideService: RideService(apiClient: authBloc.apiClient),
        );
        if (user != null) cubit.load(user.id.toString());
        return cubit;
      },
      child: Scaffold(
        body: BlocBuilder<EarningsCubit, EarningsState>(
          builder: (context, state) {
            return Column(
              children: [
                _EarningsHeader(state: state),
                Expanded(child: _EarningsBody(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _EarningsHeader extends StatelessWidget {
  const _EarningsHeader({required this.state});
  final EarningsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EarningsCubit>();
    final rangeLabel = _rangeLabel(state);
    final grossRevenue = state.data?.grossRevenue ?? 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period label (subtitle)
                Text(
                  rangeLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                // Big total amount
                Text(
                  '€${grossRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                // Trend placeholder (no trend data in bloc — degrade gracefully)
                Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 13, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Text(
                      'My Earnings',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Period chips
                _PeriodChips(state: state, cubit: cubit),
                const SizedBox(height: 8),
                // Period navigator
                _PeriodNavigator(state: state, cubit: cubit),
              ],
            ),
          ),
        ),
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
        return '${monday.day}–${sunday.day} ${months[monday.month - 1]}';
      case EarningsPeriod.month:
        return '${months[d.month - 1]} ${d.year}';
    }
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.state, required this.cubit});
  final EarningsState state;
  final EarningsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'Day', EarningsPeriod.day),
        const SizedBox(width: 8),
        _chip(context, 'Week', EarningsPeriod.week),
        const SizedBox(width: 8),
        _chip(context, 'Month', EarningsPeriod.month),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, EarningsPeriod period) {
    final selected = state.period == period;
    return GestureDetector(
      onTap: () => cubit.setPeriod(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.white.withAlpha(60),
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
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.state, required this.cubit});
  final EarningsState state;
  final EarningsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: cubit.prevPeriod,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Expanded(
          child: Center(
            child: Text(
              _navigationLabel(state),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: cubit.nextPeriod,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  String _navigationLabel(EarningsState state) {
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

// ─── Body ────────────────────────────────────────────────────────────────────

class _EarningsBody extends StatelessWidget {
  const _EarningsBody({required this.state});
  final EarningsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EarningsCubit>();

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
    if (data == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        _DailyBreakdownCard(data: data, state: state),
        const SizedBox(height: AppDimensions.paddingMedium),
        _EarningsBreakdownCard(data: data),
        const SizedBox(height: AppDimensions.paddingMedium),
        _WithdrawButton(data: data),
        const SizedBox(height: AppDimensions.paddingXLarge),
      ],
    );
  }
}

// ─── Daily breakdown card with bar chart ─────────────────────────────────────

class _DailyBreakdownCard extends StatelessWidget {
  const _DailyBreakdownCard({required this.data, required this.state});
  final DriverEarnings data;
  final EarningsState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buckets = data.buckets;
    final maxAmount = buckets.fold<double>(
      0,
      (m, b) => b.amount > m ? b.amount : m,
    );

    // For week view, generate 7 bars M–S; for others use buckets directly.
    final bars = _buildBars(state, buckets, maxAmount);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSm,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          if (bars.isEmpty || maxAmount == 0)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'No data for this period',
                  style: AppStyles.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildBars(
    EarningsState state,
    List<EarningsBucket> buckets,
    double maxAmount,
  ) {
    if (buckets.isEmpty) return [];

    if (state.period == EarningsPeriod.week) {
      // Produce 7 bars keyed M–S
      const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      final monday = state.anchorDate.subtract(
        Duration(days: state.anchorDate.weekday - 1),
      );
      return List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final bucket = buckets.firstWhere(
          (b) =>
              b.bucketStart.year == day.year &&
              b.bucketStart.month == day.month &&
              b.bucketStart.day == day.day,
          orElse: () => EarningsBucket(bucketStart: day, amount: 0),
        );
        final isToday = _isToday(day);
        return _Bar(
          label: dayLabels[i],
          amount: bucket.amount,
          maxAmount: maxAmount,
          isHighlighted: isToday,
        );
      });
    }

    // day / month: use raw buckets
    final today = DateTime.now();
    return buckets.map((b) {
      final label = state.period == EarningsPeriod.day
          ? '${b.bucketStart.hour}'
          : '${b.bucketStart.day}';
      final isHighlighted =
          state.period == EarningsPeriod.month &&
          b.bucketStart.day == today.day &&
          b.bucketStart.month == today.month;
      return _Bar(
        label: label,
        amount: b.amount,
        maxAmount: maxAmount,
        isHighlighted: isHighlighted,
      );
    }).toList();
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.amount,
    required this.maxAmount,
    required this.isHighlighted,
  });
  final String label;
  final double amount;
  final double maxAmount;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = maxAmount == 0
        ? 0.0
        : (amount / maxAmount).clamp(0.0, 1.0);
    final barColor = isHighlighted ? AppColors.accent : colorScheme.outline;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: (80 * fraction).clamp(2.0, 80.0),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Earnings breakdown ───────────────────────────────────────────────────────

class _EarningsBreakdownCard extends StatelessWidget {
  const _EarningsBreakdownCard({required this.data});
  final DriverEarnings data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final platformFee = data.totalExpenses;
    final tips = data.netRevenue - (data.grossRevenue - data.totalExpenses);
    // If tips data isn't separately tracked, show zero gracefully
    final tipsDisplay = tips > 0 ? tips : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSm,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _BreakdownRow(
            label: 'Gross fares',
            value: '€${data.grossRevenue.toStringAsFixed(2)}',
            valueColor: colorScheme.onSurface,
            showDivider: true,
          ),
          _BreakdownRow(
            label: 'Tips',
            value: '€${tipsDisplay.toStringAsFixed(2)}',
            valueColor: colorScheme.onSurface,
            showDivider: true,
          ),
          _BreakdownRow(
            label: 'Platform fee',
            value: '−€${platformFee.toStringAsFixed(2)}',
            valueColor: AppColors.error,
            showDivider: false,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net revenue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '€${data.netRevenue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.showDivider,
  });
  final String label;
  final String value;
  final Color valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

// ─── Withdraw button ──────────────────────────────────────────────────────────

class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({required this.data});
  final DriverEarnings data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: () {
          // Withdraw action placeholder — no backend endpoint yet
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          'Withdraw €${data.netRevenue.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
