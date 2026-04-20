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

  const ForecastSummary({
    required this.currentBalance,
    required this.horizonDays,
    this.firstNegativeDate,
    required this.minimumSafeBalance,
    required this.minimumExpectedBalance,
    required this.totalConfirmedOutflow,
    required this.totalExpectedInflow,
    required this.alerts,
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
      );

  bool get isSafe => firstNegativeDate == null;
  int get highAlertCount => alerts.where((a) => a.isHigh).length;

  int? get daysUntilNegative {
    if (firstNegativeDate == null) return null;
    final neg = DateTime.tryParse(firstNegativeDate!);
    if (neg == null) return null;
    return neg.difference(DateTime.now()).inDays;
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
      );

  bool get isOutflow => direction == 'OUTFLOW';
  bool get isSubscription => sourceType == 'SUBSCRIPTION';
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
