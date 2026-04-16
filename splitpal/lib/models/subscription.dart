// Unified Subscription models — replaces entity + model pairs.

class Subscription {
  final String id;
  final String groupId;
  final String? groupName;
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final String billingCycle;
  final String status;
  final DateTime nextBillingDate;
  final DateTime? lastBilledAt;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final int retryCount;
  final String? failureReason;
  final DateTime? lastAttemptAt;
  final List<SubscriptionMember> members;
  final int memberCount;

  const Subscription({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.name,
    this.description,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.status,
    required this.nextBillingDate,
    this.lastBilledAt,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.cancelledAt,
    this.retryCount = 0,
    this.failureReason,
    this.lastAttemptAt,
    this.members = const [],
    this.memberCount = 0,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    List<SubscriptionMember> members = [];
    if (membersRaw is List) {
      members = membersRaw
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionMember.fromJson)
          .toList();
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return Subscription(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      groupName: json['groupName'] as String?,
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: (json['currency'] ?? 'VND').toString(),
      billingCycle: (json['billingCycle'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      nextBillingDate: parseDate(json['nextBillingDate']) ?? DateTime.now(),
      lastBilledAt: parseDate(json['lastBilledAt']),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdByName: json['createdByName'] as String?,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      cancelledAt: parseDate(json['cancelledAt']),
      retryCount: json['retryCount'] as int? ?? 0,
      failureReason: json['failureReason'] as String?,
      lastAttemptAt: parseDate(json['lastAttemptAt']),
      members: members,
      memberCount: json['memberCount'] is int
          ? json['memberCount'] as int
          : members.length,
    );
  }
}

class SubscriptionMember {
  final String id;
  final String userId;
  final double shareAmount;
  final String status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const SubscriptionMember({
    required this.id,
    required this.userId,
    required this.shareAmount,
    required this.status,
    required this.joinedAt,
    this.leftAt,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  factory SubscriptionMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return SubscriptionMember(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId:
          (json['userId'] ?? user?['id'] ?? user?['_id'] ?? '').toString(),
      shareAmount: (json['shareAmount'] is num)
          ? (json['shareAmount'] as num).toDouble()
          : double.tryParse(json['shareAmount']?.toString() ?? '') ?? 0,
      status: (json['status'] ?? '').toString(),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
          DateTime.now(),
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'].toString())
          : null,
      email: user?['email'] as String?,
      displayName: user?['displayName'] as String?,
      avatarUrl: user?['avatarUrl'] as String?,
    );
  }
}
