/// Model representing a Savings Goal.
class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String icon;
  final String status; // ACTIVE, COMPLETED, CANCELLED
  final DateTime? deadline;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Enriched fields from API (getGoals / getGoalById)
  final List<SavingsDeposit> deposits;
  final double totalWithInterest;
  final int depositCount;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.icon = '🎯',
    this.status = 'ACTIVE',
    this.deadline,
    this.createdAt,
    this.updatedAt,
    this.deposits = const [],
    this.totalWithInterest = 0.0,
    this.depositCount = 0,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final depositList = (json['deposits'] as List?)
            ?.map((e) => SavingsDeposit.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SavingsGoal(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      targetAmount: _toDouble(json['targetAmount']),
      currentAmount: _toDouble(json['currentAmount']),
      icon: json['icon'] as String? ?? '🎯',
      status: json['status'] as String? ?? 'ACTIVE',
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      deposits: depositList,
      totalWithInterest: _toDouble(json['totalWithInterest']),
      depositCount: (json['depositCount'] as num?)?.toInt() ?? depositList.length,
    );
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => status == 'COMPLETED' || progress >= 1.0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'targetAmount': targetAmount,
        'icon': icon,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
      };

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    if (v is Map && v.containsKey('\$numberDecimal')) {
      return double.tryParse(v['\$numberDecimal'].toString()) ?? 0.0;
    }
    return 0.0;
  }
}

/// Model representing a Savings Deposit.
class SavingsDeposit {
  final String id;
  final String goalId;
  final double amount;
  final int term;
  final String termLabel;
  final double annualRate;
  /// Interest user would receive if withdrawing NOW (penalty rate if early).
  final double accruedInterest;
  /// Interest projected at maturity (null for flexible deposits).
  final double? projectedInterest;
  final String status; // HOLDING, MATURED, WITHDRAWN
  final DateTime? depositDate;
  final DateTime? maturityDate;
  final DateTime? withdrawnAt;
  final DateTime? createdAt;

  const SavingsDeposit({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.term,
    this.termLabel = '',
    this.annualRate = 0.0,
    this.accruedInterest = 0.0,
    this.projectedInterest,
    this.status = 'HOLDING',
    this.depositDate,
    this.maturityDate,
    this.withdrawnAt,
    this.createdAt,
  });

  factory SavingsDeposit.fromJson(Map<String, dynamic> json) {
    return SavingsDeposit(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      goalId: (json['goalId'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      term: (json['term'] as num?)?.toInt() ?? 0,
      termLabel: json['termLabel'] as String? ?? '',
      annualRate: _toDouble(json['annualRate']),
      accruedInterest: _toDouble(json['accruedInterest']),
      projectedInterest: json['projectedInterest'] != null
          ? _toDouble(json['projectedInterest'])
          : null,
      status: json['status'] as String? ?? 'HOLDING',
      depositDate: json['depositDate'] != null
          ? DateTime.tryParse(json['depositDate'].toString())
          : null,
      maturityDate: json['maturityDate'] != null
          ? DateTime.tryParse(json['maturityDate'].toString())
          : null,
      withdrawnAt: json['withdrawnAt'] != null
          ? DateTime.tryParse(json['withdrawnAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isMatured => status == 'MATURED';
  bool get isWithdrawn => status == 'WITHDRAWN';
  bool get canWithdraw => status == 'HOLDING' || status == 'MATURED';

  /// Total value = principal + interest.
  double get totalValue => amount + accruedInterest;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    if (v is Map && v.containsKey('\$numberDecimal')) {
      return double.tryParse(v['\$numberDecimal'].toString()) ?? 0.0;
    }
    return 0.0;
  }
}

/// Summary data returned by the GET /api/savings/goals endpoint.
class SavingsSummary {
  final int totalGoals;
  final int activeGoals;
  final double totalSavings;
  final double totalInterest;
  final double totalBalance;

  const SavingsSummary({
    this.totalGoals = 0,
    this.activeGoals = 0,
    this.totalSavings = 0,
    this.totalInterest = 0,
    this.totalBalance = 0,
  });

  factory SavingsSummary.fromJson(Map<String, dynamic> json) {
    return SavingsSummary(
      totalGoals: (json['totalGoals'] as num?)?.toInt() ?? 0,
      activeGoals: (json['activeGoals'] as num?)?.toInt() ?? 0,
      totalSavings: (json['totalSavings'] as num?)?.toDouble() ?? 0,
      totalInterest: (json['totalInterest'] as num?)?.toDouble() ?? 0,
      totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0,
    );
  }
}
