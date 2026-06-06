/// Один столбец графика заработка: начало бакета (час/день) и сумма дохода.
class EarningsBucket {
  final DateTime bucketStart;
  final double amount;

  const EarningsBucket({required this.bucketStart, required this.amount});

  factory EarningsBucket.fromJson(Map<String, dynamic> json) {
    return EarningsBucket(
      bucketStart: DateTime.parse(json['bucketStart'] as String).toLocal(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Отчёт о заработке водителя за период. Зеркалит backend DriverEarningsDto.
class DriverEarnings {
  final String period; // 'day' | 'week' | 'month'
  final double grossRevenue;
  final double totalExpenses;
  final double netRevenue;
  final int completedRides;
  final int cancelledRides;
  final double avgFare;
  final String currency;
  final List<EarningsBucket> buckets;

  const DriverEarnings({
    required this.period,
    required this.grossRevenue,
    required this.totalExpenses,
    required this.netRevenue,
    required this.completedRides,
    required this.cancelledRides,
    required this.avgFare,
    required this.currency,
    required this.buckets,
  });

  factory DriverEarnings.fromJson(Map<String, dynamic> json) {
    final rawBuckets = (json['buckets'] as List<dynamic>?) ?? const [];
    return DriverEarnings(
      period: json['period'] as String? ?? 'week',
      grossRevenue: (json['grossRevenue'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      netRevenue: (json['netRevenue'] as num?)?.toDouble() ?? 0.0,
      completedRides: (json['completedRides'] as num?)?.toInt() ?? 0,
      cancelledRides: (json['cancelledRides'] as num?)?.toInt() ?? 0,
      avgFare: (json['avgFare'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EUR',
      buckets: rawBuckets
          .map((b) => EarningsBucket.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}
