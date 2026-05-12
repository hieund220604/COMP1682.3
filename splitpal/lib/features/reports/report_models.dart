// Financial Report models for the Report Hub feature.

// ── Monthly Report ───────────────────────────────────────────────────────────

class MonthlyReport {
  final String month;
  final ReportOverview overview;
  final OutflowBySource outflowBySource;
  final InflowBySource inflowBySource;
  final List<BudgetPerformance> budgetPerformance;
  final List<GroupActivity> groupActivity;
  final SubscriptionSummary subscriptionSummary;
  final ReportComparison comparison;
  final List<DailySpending> dailySpending;

  const MonthlyReport({
    required this.month,
    required this.overview,
    required this.outflowBySource,
    required this.inflowBySource,
    required this.budgetPerformance,
    required this.groupActivity,
    required this.subscriptionSummary,
    required this.comparison,
    required this.dailySpending,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> j) => MonthlyReport(
        month: j['month'] as String? ?? '',
        overview: ReportOverview.fromJson(
            j['overview'] as Map<String, dynamic>? ?? {}),
        outflowBySource: OutflowBySource.fromJson(
            j['outflowBySource'] as Map<String, dynamic>? ?? {}),
        inflowBySource: InflowBySource.fromJson(
            j['inflowBySource'] as Map<String, dynamic>? ?? {}),
        budgetPerformance: (j['budgetPerformance'] as List<dynamic>? ?? [])
            .map((e) => BudgetPerformance.fromJson(e as Map<String, dynamic>))
            .toList(),
        groupActivity: (j['groupActivity'] as List<dynamic>? ?? [])
            .map((e) => GroupActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        subscriptionSummary: SubscriptionSummary.fromJson(
            j['subscriptionSummary'] as Map<String, dynamic>? ?? {}),
        comparison: ReportComparison.fromJson(
            j['comparison'] as Map<String, dynamic>? ?? {}),
        dailySpending: (j['dailySpending'] as List<dynamic>? ?? [])
            .map((e) => DailySpending.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ReportOverview {
  final double totalInflow;
  final double totalOutflow;
  final double netCashflow;
  final double openingBalance;
  final double closingBalance;
  final int transactionCount;

  const ReportOverview({
    required this.totalInflow,
    required this.totalOutflow,
    required this.netCashflow,
    required this.openingBalance,
    required this.closingBalance,
    required this.transactionCount,
  });

  factory ReportOverview.fromJson(Map<String, dynamic> j) => ReportOverview(
        totalInflow: (j['totalInflow'] as num?)?.toDouble() ?? 0,
        totalOutflow: (j['totalOutflow'] as num?)?.toDouble() ?? 0,
        netCashflow: (j['netCashflow'] as num?)?.toDouble() ?? 0,
        openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
        closingBalance: (j['closingBalance'] as num?)?.toDouble() ?? 0,
        transactionCount: (j['transactionCount'] as num?)?.toInt() ?? 0,
      );

  bool get isPositive => netCashflow >= 0;
}

class OutflowBySource {
  final double personalReceipts;
  final double groupExpenses;
  final double subscriptions;
  final double withdrawals;
  final double other;

  const OutflowBySource({
    required this.personalReceipts,
    required this.groupExpenses,
    required this.subscriptions,
    required this.withdrawals,
    required this.other,
  });

  factory OutflowBySource.fromJson(Map<String, dynamic> j) => OutflowBySource(
        personalReceipts: (j['personalReceipts'] as num?)?.toDouble() ?? 0,
        groupExpenses: (j['groupExpenses'] as num?)?.toDouble() ?? 0,
        subscriptions: (j['subscriptions'] as num?)?.toDouble() ?? 0,
        withdrawals: (j['withdrawals'] as num?)?.toDouble() ?? 0,
        other: (j['other'] as num?)?.toDouble() ?? 0,
      );

  double get total =>
      personalReceipts + groupExpenses + subscriptions + withdrawals + other;

  /// Returns non-zero sources as a list for charting.
  List<OutflowEntry> get entries {
    final list = <OutflowEntry>[
      if (personalReceipts > 0)
        OutflowEntry('Receipts', personalReceipts, 0xFF6366F1),
      if (groupExpenses > 0)
        OutflowEntry('Groups', groupExpenses, 0xFF3B82F6),
      if (subscriptions > 0)
        OutflowEntry('Subscriptions', subscriptions, 0xFFF59E0B),
      if (withdrawals > 0)
        OutflowEntry('Withdrawals', withdrawals, 0xFFEF4444),
      if (other > 0) OutflowEntry('Other', other, 0xFF94A3B8),
    ];
    return list;
  }
}

class OutflowEntry {
  final String label;
  final double amount;
  final int colorValue;

  const OutflowEntry(this.label, this.amount, this.colorValue);
}

class InflowBySource {
  final double topUps;
  final double groupPaymentsReceived;
  final double refunds;
  final double other;

  const InflowBySource({
    required this.topUps,
    required this.groupPaymentsReceived,
    required this.refunds,
    required this.other,
  });

  factory InflowBySource.fromJson(Map<String, dynamic> j) => InflowBySource(
        topUps: (j['topUps'] as num?)?.toDouble() ?? 0,
        groupPaymentsReceived:
            (j['groupPaymentsReceived'] as num?)?.toDouble() ?? 0,
        refunds: (j['refunds'] as num?)?.toDouble() ?? 0,
        other: (j['other'] as num?)?.toDouble() ?? 0,
      );

  double get total => topUps + groupPaymentsReceived + refunds + other;

  List<OutflowEntry> get entries {
    final list = <OutflowEntry>[
      if (topUps > 0) OutflowEntry('Top-ups', topUps, 0xFF10B981),
      if (groupPaymentsReceived > 0)
        OutflowEntry('Groups', groupPaymentsReceived, 0xFF3B82F6),
      if (refunds > 0) OutflowEntry('Refunds', refunds, 0xFFF59E0B),
      if (other > 0) OutflowEntry('Other', other, 0xFF94A3B8),
    ];
    return list;
  }
}

class BudgetPerformance {
  final String tagId;
  final String tagName;
  final String tagIcon;
  final String tagColor;
  final double? budgetLimit;
  final double spent;
  final int receiptCount;
  final int percentUsed;
  final String status;

  const BudgetPerformance({
    required this.tagId,
    required this.tagName,
    required this.tagIcon,
    required this.tagColor,
    required this.budgetLimit,
    required this.spent,
    required this.receiptCount,
    required this.percentUsed,
    required this.status,
  });

  factory BudgetPerformance.fromJson(Map<String, dynamic> j) =>
      BudgetPerformance(
        tagId: j['tagId'] as String? ?? '',
        tagName: j['tagName'] as String? ?? '',
        tagIcon: j['tagIcon'] as String? ?? '📦',
        tagColor: j['tagColor'] as String? ?? '#888888',
        budgetLimit: (j['budgetLimit'] as num?)?.toDouble(),
        spent: (j['spent'] as num?)?.toDouble() ?? 0,
        receiptCount: (j['receiptCount'] as num?)?.toInt() ?? 0,
        percentUsed: (j['percentUsed'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'UNDER',
      );

  bool get isExceeded => status == 'EXCEEDED';
  bool get isWarning => status == 'WARNING';
  bool get hasBudget => budgetLimit != null && budgetLimit! > 0;
}

class GroupActivity {
  final String groupId;
  final String groupName;
  final double totalPaid;
  final double totalReceived;
  final double netPosition;
  final int invoiceCount;

  const GroupActivity({
    required this.groupId,
    required this.groupName,
    required this.totalPaid,
    required this.totalReceived,
    required this.netPosition,
    required this.invoiceCount,
  });

  factory GroupActivity.fromJson(Map<String, dynamic> j) => GroupActivity(
        groupId: j['groupId'] as String? ?? '',
        groupName: j['groupName'] as String? ?? 'Unknown',
        totalPaid: (j['totalPaid'] as num?)?.toDouble() ?? 0,
        totalReceived: (j['totalReceived'] as num?)?.toDouble() ?? 0,
        netPosition: (j['netPosition'] as num?)?.toDouble() ?? 0,
        invoiceCount: (j['invoiceCount'] as num?)?.toInt() ?? 0,
      );

  bool get isPositive => netPosition >= 0;
}

class SubscriptionSummary {
  final double totalCost;
  final int activeCount;
  final List<SubscriptionItem> subscriptions;

  const SubscriptionSummary({
    required this.totalCost,
    required this.activeCount,
    required this.subscriptions,
  });

  factory SubscriptionSummary.fromJson(Map<String, dynamic> j) =>
      SubscriptionSummary(
        totalCost: (j['totalCost'] as num?)?.toDouble() ?? 0,
        activeCount: (j['activeCount'] as num?)?.toInt() ?? 0,
        subscriptions: (j['subscriptions'] as List<dynamic>? ?? [])
            .map((e) => SubscriptionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SubscriptionItem {
  final String name;
  final double amount;
  final String cycle;

  const SubscriptionItem({
    required this.name,
    required this.amount,
    required this.cycle,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> j) =>
      SubscriptionItem(
        name: j['name'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        cycle: j['cycle'] as String? ?? 'MONTHLY',
      );
}

class ReportComparison {
  final PreviousMonth previousMonth;
  final ChangePercent changePercent;
  final String trend;

  const ReportComparison({
    required this.previousMonth,
    required this.changePercent,
    required this.trend,
  });

  factory ReportComparison.fromJson(Map<String, dynamic> j) =>
      ReportComparison(
        previousMonth: PreviousMonth.fromJson(
            j['previousMonth'] as Map<String, dynamic>? ?? {}),
        changePercent: ChangePercent.fromJson(
            j['changePercent'] as Map<String, dynamic>? ?? {}),
        trend: j['trend'] as String? ?? 'STABLE',
      );

  bool get isImproving => trend == 'IMPROVING';
  bool get isDeclining => trend == 'DECLINING';
}

class PreviousMonth {
  final double totalOutflow;
  final double totalInflow;

  const PreviousMonth({required this.totalOutflow, required this.totalInflow});

  factory PreviousMonth.fromJson(Map<String, dynamic> j) => PreviousMonth(
        totalOutflow: (j['totalOutflow'] as num?)?.toDouble() ?? 0,
        totalInflow: (j['totalInflow'] as num?)?.toDouble() ?? 0,
      );
}

class ChangePercent {
  final double outflow;
  final double inflow;

  const ChangePercent({required this.outflow, required this.inflow});

  factory ChangePercent.fromJson(Map<String, dynamic> j) => ChangePercent(
        outflow: (j['outflow'] as num?)?.toDouble() ?? 0,
        inflow: (j['inflow'] as num?)?.toDouble() ?? 0,
      );
}

class DailySpending {
  final String date;
  final double outflow;
  final double inflow;

  const DailySpending({
    required this.date,
    required this.outflow,
    required this.inflow,
  });

  factory DailySpending.fromJson(Map<String, dynamic> j) => DailySpending(
        date: j['date'] as String? ?? '',
        outflow: (j['outflow'] as num?)?.toDouble() ?? 0,
        inflow: (j['inflow'] as num?)?.toDouble() ?? 0,
      );
}

// ── Yearly Report ────────────────────────────────────────────────────────────

class YearlyReport {
  final int year;
  final YearlyOverview overview;
  final List<MonthlyBreakdown> monthlyBreakdown;
  final List<TopCategory> topCategories;
  final double subscriptionTotal;
  final double groupExpenseTotal;

  const YearlyReport({
    required this.year,
    required this.overview,
    required this.monthlyBreakdown,
    required this.topCategories,
    required this.subscriptionTotal,
    required this.groupExpenseTotal,
  });

  factory YearlyReport.fromJson(Map<String, dynamic> j) => YearlyReport(
        year: (j['year'] as num?)?.toInt() ?? 0,
        overview: YearlyOverview.fromJson(
            j['overview'] as Map<String, dynamic>? ?? {}),
        monthlyBreakdown: (j['monthlyBreakdown'] as List<dynamic>? ?? [])
            .map((e) => MonthlyBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        topCategories: (j['topCategories'] as List<dynamic>? ?? [])
            .map((e) => TopCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        subscriptionTotal:
            (j['subscriptionTotal'] as num?)?.toDouble() ?? 0,
        groupExpenseTotal:
            (j['groupExpenseTotal'] as num?)?.toDouble() ?? 0,
      );
}

class YearlyOverview {
  final double totalInflow;
  final double totalOutflow;
  final double netCashflow;
  final double avgMonthlyOutflow;
  final double avgMonthlyInflow;

  const YearlyOverview({
    required this.totalInflow,
    required this.totalOutflow,
    required this.netCashflow,
    required this.avgMonthlyOutflow,
    required this.avgMonthlyInflow,
  });

  factory YearlyOverview.fromJson(Map<String, dynamic> j) => YearlyOverview(
        totalInflow: (j['totalInflow'] as num?)?.toDouble() ?? 0,
        totalOutflow: (j['totalOutflow'] as num?)?.toDouble() ?? 0,
        netCashflow: (j['netCashflow'] as num?)?.toDouble() ?? 0,
        avgMonthlyOutflow: (j['avgMonthlyOutflow'] as num?)?.toDouble() ?? 0,
        avgMonthlyInflow: (j['avgMonthlyInflow'] as num?)?.toDouble() ?? 0,
      );
}

class MonthlyBreakdown {
  final String month;
  final double inflow;
  final double outflow;
  final double net;

  const MonthlyBreakdown({
    required this.month,
    required this.inflow,
    required this.outflow,
    required this.net,
  });

  factory MonthlyBreakdown.fromJson(Map<String, dynamic> j) =>
      MonthlyBreakdown(
        month: j['month'] as String? ?? '',
        inflow: (j['inflow'] as num?)?.toDouble() ?? 0,
        outflow: (j['outflow'] as num?)?.toDouble() ?? 0,
        net: (j['net'] as num?)?.toDouble() ?? 0,
      );
}

class TopCategory {
  final String tagName;
  final String tagIcon;
  final String tagColor;
  final double totalSpent;
  final int percent;

  const TopCategory({
    required this.tagName,
    required this.tagIcon,
    required this.tagColor,
    required this.totalSpent,
    required this.percent,
  });

  factory TopCategory.fromJson(Map<String, dynamic> j) => TopCategory(
        tagName: j['tagName'] as String? ?? '',
        tagIcon: j['tagIcon'] as String? ?? '📦',
        tagColor: j['tagColor'] as String? ?? '#888888',
        totalSpent: (j['totalSpent'] as num?)?.toDouble() ?? 0,
        percent: (j['percent'] as num?)?.toInt() ?? 0,
      );
}
