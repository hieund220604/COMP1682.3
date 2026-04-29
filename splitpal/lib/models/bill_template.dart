/// BillTemplate models for recurring invoice feature.

class BillTemplateItemSplit {
  final String userId;
  final double value;

  const BillTemplateItemSplit({required this.userId, required this.value});

  factory BillTemplateItemSplit.fromJson(Map<String, dynamic> json) =>
      BillTemplateItemSplit(
        userId: json['userId'] ?? '',
        value: (json['value'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'value': value};
}

class BillTemplateItem {
  final String name;
  final double amount;
  final String splitType; // EQUAL | PERCENTAGE | CUSTOM | WEIGHT
  final List<String> assignedTo; // [] = all active members at generation time
  final List<BillTemplateItemSplit> splits;

  const BillTemplateItem({
    required this.name,
    required this.amount,
    this.splitType = 'EQUAL',
    required this.assignedTo,
    this.splits = const [],
  });

  factory BillTemplateItem.fromJson(Map<String, dynamic> json) {
    return BillTemplateItem(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      splitType: json['splitType'] ?? 'EQUAL',
      assignedTo: (json['assignedTo'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      splits: (json['splits'] as List?)
              ?.map((e) => BillTemplateItemSplit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'splitType': splitType,
        'assignedTo': assignedTo,
        if (splits.isNotEmpty)
          'splits': splits.map((s) => s.toJson()).toList(),
      };
}

class BillTemplatePayer {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const BillTemplatePayer({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  String get name => displayName ?? email ?? 'Unknown';

  factory BillTemplatePayer.fromJson(Map<String, dynamic> json) =>
      BillTemplatePayer(
        id: json['id'] ?? json['_id'] ?? '',
        email: json['email'],
        displayName: json['displayName'],
        avatarUrl: json['avatarUrl'],
      );
}

class BillTemplate {
  final String id;
  final String groupId;
  final String name;
  final String? description;

  // Schedule
  final String billingCycle; // DAILY | WEEKLY | MONTHLY
  final int? billingDay; // WEEKLY: 1-7, MONTHLY: 1-28

  // Invoice config
  final String currency;
  final List<BillTemplateItem> items;
  final BillTemplatePayer payer;

  // State
  final String status; // ACTIVE | PAUSED | ARCHIVED
  final String createdBy;

  // Tracking
  final DateTime? lastGeneratedAt;
  final DateTime nextBillDate;
  final int daysUntilNext;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BillTemplate({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    required this.billingCycle,
    this.billingDay,
    required this.currency,
    required this.items,
    required this.payer,
    required this.status,
    required this.createdBy,
    this.lastGeneratedAt,
    required this.nextBillDate,
    required this.daysUntilNext,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isPaused => status == 'PAUSED';

  double get totalAmount => items.fold(0, (s, i) => s + i.amount);

  /// Human-readable cycle label
  String get cycleLabel {
    switch (billingCycle) {
      case 'DAILY':
        return 'Daily';
      case 'WEEKLY':
        final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return 'Weekly · ${billingDay != null && billingDay! <= 7 ? days[billingDay!] : ''}';
      case 'MONTHLY':
        return 'Monthly · Day $billingDay';
      default:
        return billingCycle;
    }
  }

  factory BillTemplate.fromJson(Map<String, dynamic> json) {
    return BillTemplate(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['groupId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      billingCycle: json['billingCycle'] ?? 'MONTHLY',
      billingDay: json['billingDay'],
      currency: json['currency'] ?? 'VND',
      items: (json['items'] as List?)
              ?.map((e) => BillTemplateItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      payer: json['payer'] is Map
          ? BillTemplatePayer.fromJson(json['payer'] as Map<String, dynamic>)
          : BillTemplatePayer(id: json['payerId'] ?? ''),
      status: json['status'] ?? 'ACTIVE',
      createdBy: json['createdBy'] ?? '',
      lastGeneratedAt: json['lastGeneratedAt'] != null
          ? DateTime.parse(json['lastGeneratedAt'])
          : null,
      nextBillDate: DateTime.parse(
          json['nextBillDate'] ?? DateTime.now().toIso8601String()),
      daysUntilNext: json['daysUntilNext'] ?? 0,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Request DTO for creating/updating a template
class BillTemplateRequest {
  final String name;
  final String? description;
  final String billingCycle;
  final int? billingDay;
  final String? currency;
  final List<BillTemplateItem> items;
  final String? payerId;

  const BillTemplateRequest({
    required this.name,
    this.description,
    required this.billingCycle,
    this.billingDay,
    this.currency,
    required this.items,
    this.payerId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'billingCycle': billingCycle,
        if (billingDay != null) 'billingDay': billingDay,
        if (currency != null) 'currency': currency,
        'items': items.map((i) => i.toJson()).toList(),
        if (payerId != null) 'payerId': payerId,
      };
}
