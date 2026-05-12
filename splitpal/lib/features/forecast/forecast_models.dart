import 'package:flutter/painting.dart' show Color;

// ── Alert ─────────────────────────────────────────────────────────────────────

class ForecastAlert {
  final String type;
  final String? date;
  final String message;
  final String severity;
  final double? amount;

  const ForecastAlert({
    required this.type,
    this.date,
    required this.message,
    required this.severity,
    this.amount,
  });

  factory ForecastAlert.fromJson(Map<String, dynamic> j) => ForecastAlert(
        type: j['type'] as String? ?? '',
        date: j['date'] as String?,
        message: j['message'] as String? ?? '',
        severity: j['severity'] as String? ?? 'LOW',
        amount: (j['amount'] as num?)?.toDouble(),
      );

  bool get isHigh => severity == 'HIGH';
  bool get isMedium => severity == 'MEDIUM';
}

// ── Summary ───────────────────────────────────────────────────────────────────

class ForecastSummary {
  final double currentBalance;
  final int horizonDays;
  final String? firstNegativeDate;
  final double minimumSafeBalance;
  final double minimumExpectedBalance;
  final double totalConfirmedOutflow;
  final double totalExpectedInflow;
  final List<ForecastAlert> alerts;
  final int healthScore;
  final String healthLabel;

  const ForecastSummary({
    required this.currentBalance,
    required this.horizonDays,
    this.firstNegativeDate,
    required this.minimumSafeBalance,
    required this.minimumExpectedBalance,
    required this.totalConfirmedOutflow,
    required this.totalExpectedInflow,
    required this.alerts,
    this.healthScore = 0,
    this.healthLabel = 'Fair',
  });

  factory ForecastSummary.fromJson(Map<String, dynamic> j) => ForecastSummary(
        currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
        horizonDays: (j['horizonDays'] as num?)?.toInt() ?? 7,
        firstNegativeDate: j['firstNegativeDate'] as String?,
        minimumSafeBalance: (j['minimumSafeBalance'] as num?)?.toDouble() ?? 0,
        minimumExpectedBalance:
            (j['minimumExpectedBalance'] as num?)?.toDouble() ?? 0,
        totalConfirmedOutflow:
            (j['totalConfirmedOutflow'] as num?)?.toDouble() ?? 0,
        totalExpectedInflow:
            (j['totalExpectedInflow'] as num?)?.toDouble() ?? 0,
        alerts: (j['alerts'] as List<dynamic>? ?? [])
            .map((a) => ForecastAlert.fromJson(a as Map<String, dynamic>))
            .toList(),
        healthScore: (j['healthScore'] as num?)?.toInt() ?? 0,
        healthLabel: j['healthLabel'] as String? ?? 'Fair',
      );

  bool get isSafe => firstNegativeDate == null;
  int get highAlertCount => alerts.where((a) => a.isHigh).length;

  int? get daysUntilNegative {
    if (firstNegativeDate == null) return null;
    final neg = DateTime.tryParse(firstNegativeDate!);
    if (neg == null) return null;
    return neg.difference(DateTime.now()).inDays;
  }

  Color get healthColor {
    if (healthScore >= 85) return const Color(0xFF27AE60);
    if (healthScore >= 70) return const Color(0xFF2ECC71);
    if (healthScore >= 50) return const Color(0xFFF39C12);
    if (healthScore >= 30) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }
}

// ── Event ─────────────────────────────────────────────────────────────────────

class ForecastEventModel {
  final String id;
  final String sourceType;  // SUBSCRIPTION | TRANSFER_OUT | TRANSFER_IN
  final String sourceId;
  final String direction;   // INFLOW | OUTFLOW
  final String certainty;   // CONFIRMED | COMMITTED | EXPECTED
  final double amount;
  final String currency;
  final DateTime effectiveDate;
  final String title;
  final String? counterparty;
  final String? groupName;
  final String actionType;
  final String status;
  final int retryCount;
  final String? receiptTagName;

  const ForecastEventModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.direction,
    required this.certainty,
    required this.amount,
    required this.currency,
    required this.effectiveDate,
    required this.title,
    this.counterparty,
    this.groupName,
    required this.actionType,
    required this.status,
    this.retryCount = 0,
    this.receiptTagName,
  });

  factory ForecastEventModel.fromJson(Map<String, dynamic> j) =>
      ForecastEventModel(
        id: j['id'] as String? ?? '',
        sourceType: j['sourceType'] as String? ?? '',
        sourceId: j['sourceId'] as String? ?? '',
        direction: j['direction'] as String? ?? 'OUTFLOW',
        certainty: j['certainty'] as String? ?? 'CONFIRMED',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] as String? ?? 'VND',
        effectiveDate: j['effectiveDate'] != null
            ? DateTime.tryParse(j['effectiveDate'] as String) ?? DateTime.now()
            : DateTime.now(),
        title: j['title'] as String? ?? '',
        counterparty: j['counterparty'] as String?,
        groupName: j['groupName'] as String?,
        actionType: j['actionType'] as String? ?? 'OPEN_SUBSCRIPTION',
        status: j['status'] as String? ?? '',
        retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
        receiptTagName: j['receiptTagName'] as String?,
      );

  bool get isOutflow => direction == 'OUTFLOW';
  bool get isSubscription => sourceType == 'SUBSCRIPTION';
  bool get isReceipt => sourceType == 'RECEIPT_SPENDING';
  bool get isTransfer =>
      sourceType == 'TRANSFER_OUT' || sourceType == 'TRANSFER_IN';

  Color get certaintyColor {
    switch (certainty) {
      case 'CONFIRMED':
        return const Color(0xFFE53E3E);
      case 'COMMITTED':
        return const Color(0xFFDD6B20);
      case 'EXPECTED':
        return const Color(0xFF3182CE);
      default:
        return const Color(0xFF718096);
    }
  }
}

// ── Daily ─────────────────────────────────────────────────────────────────────

class DailyForecastModel {
  final String date; // yyyy-MM-dd
  final double openingBalance;
  final double closingBalanceSafe;
  final double closingBalanceExpected;
  final List<ForecastEventModel> outflows;
  final List<ForecastEventModel> inflows;

  const DailyForecastModel({
    required this.date,
    required this.openingBalance,
    required this.closingBalanceSafe,
    required this.closingBalanceExpected,
    required this.outflows,
    required this.inflows,
  });

  factory DailyForecastModel.fromJson(Map<String, dynamic> j) =>
      DailyForecastModel(
        date: j['date'] as String? ?? '',
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
        closingBalanceSafe:
            (j['closingBalanceSafe'] as num?)?.toDouble() ?? 0,
        closingBalanceExpected:
            (j['closingBalanceExpected'] as num?)?.toDouble() ?? 0,
        outflows: (j['outflows'] as List<dynamic>? ?? [])
            .map((e) =>
                ForecastEventModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        inflows: (j['inflows'] as List<dynamic>? ?? [])
            .map((e) =>
                ForecastEventModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  List<ForecastEventModel> get allEvents => [...outflows, ...inflows];

  double get netChange {
    final out = outflows.fold<double>(0, (s, e) => s + e.amount);
    final inn = inflows.fold<double>(0, (s, e) => s + e.amount);
    return inn - out;
  }

  bool get hasEvents => outflows.isNotEmpty || inflows.isNotEmpty;
  bool get isNegative => closingBalanceSafe < 0;
}

// ── Category Breakdown ────────────────────────────────────────────────────────

class CategoryBreakdown {
  final String category;
  final String label;
  final double amount;
  final int percent;
  final int count;

  const CategoryBreakdown({
    required this.category,
    required this.label,
    required this.amount,
    required this.percent,
    required this.count,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> j) =>
      CategoryBreakdown(
        category: j['category'] as String? ?? '',
        label: j['label'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

// ── Spending Insight ──────────────────────────────────────────────────────────

class SpendingInsight {
  final int periodDays;
  final double currentPeriodOutflow;
  final double previousPeriodOutflow;
  final double changePercent;
  final String trend; // UP | DOWN | STABLE
  final List<CategoryBreakdown> categoryBreakdown;
  final double dailyAvgSpending;
  final String? peakSpendingDay;
  final double subscriptionMonthlyTotal;
  final int subscriptionPercent;

  const SpendingInsight({
    required this.periodDays,
    required this.currentPeriodOutflow,
    required this.previousPeriodOutflow,
    required this.changePercent,
    required this.trend,
    required this.categoryBreakdown,
    required this.dailyAvgSpending,
    this.peakSpendingDay,
    required this.subscriptionMonthlyTotal,
    required this.subscriptionPercent,
  });

  factory SpendingInsight.fromJson(Map<String, dynamic> j) => SpendingInsight(
        periodDays: (j['periodDays'] as num?)?.toInt() ?? 7,
        currentPeriodOutflow:
            (j['currentPeriodOutflow'] as num?)?.toDouble() ?? 0,
        previousPeriodOutflow:
            (j['previousPeriodOutflow'] as num?)?.toDouble() ?? 0,
        changePercent: (j['changePercent'] as num?)?.toDouble() ?? 0,
        trend: j['trend'] as String? ?? 'STABLE',
        categoryBreakdown: (j['categoryBreakdown'] as List<dynamic>? ?? [])
            .map((e) =>
                CategoryBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyAvgSpending:
            (j['dailyAvgSpending'] as num?)?.toDouble() ?? 0,
        peakSpendingDay: j['peakSpendingDay'] as String?,
        subscriptionMonthlyTotal:
            (j['subscriptionMonthlyTotal'] as num?)?.toDouble() ?? 0,
        subscriptionPercent:
            (j['subscriptionPercent'] as num?)?.toInt() ?? 0,
      );

  bool get isUp => trend == 'UP';
  bool get isDown => trend == 'DOWN';
}

// ── Smart Tip ─────────────────────────────────────────────────────────────────

class SmartTip {
  final String id;
  final String icon;
  final String title;
  final String description;
  final String type; // SAVING | WARNING | INFO | ACTION
  final int priority;

  const SmartTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
  });

  factory SmartTip.fromJson(Map<String, dynamic> j) => SmartTip(
        id: j['id'] as String? ?? '',
        icon: j['icon'] as String? ?? '💡',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        type: j['type'] as String? ?? 'INFO',
        priority: (j['priority'] as num?)?.toInt() ?? 5,
      );

  bool get isAction => type == 'ACTION';
  bool get isWarning => type == 'WARNING';
  bool get isSaving => type == 'SAVING';

  Color get typeColor {
    switch (type) {
      case 'ACTION':
        return const Color(0xFFE53E3E);
      case 'WARNING':
        return const Color(0xFFDD6B20);
      case 'SAVING':
        return const Color(0xFF38A169);
      default:
        return const Color(0xFF3182CE);
    }
  }
}
