// Unified Subscription models — v2

/// Safely parse a numeric value that might be a Decimal128 Map, num, or String.
double _safeDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  if (v is Map) {
    final dec = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (dec != null) return double.tryParse(dec.toString()) ?? fallback;
  }
  return fallback;
}

class Subscription {
  final String id;
  final String? groupId;
  final String? groupName;
  final String name;
  final String? description;
  /// Fixed fee per member per cycle (NOT a total to be split).
  final double amount;
  final String currency;
  final String billingCycle;
  /// ACTIVE = owner hasn't cancelled. CANCELLED = owner closed.
  final String status;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final List<SubscriptionMember> members;
  final List<SubInvitation> pendingInvitations;
  final int memberCount;

  const Subscription({
    required this.id,
    this.groupId,
    this.groupName,
    required this.name,
    this.description,
    required this.amount,
    required this.currency,
    required this.billingCycle,
    required this.status,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.cancelledAt,
    this.members = const [],
    this.pendingInvitations = const [],
    this.memberCount = 0,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isCancelled => status == 'CANCELLED';

  /// Earliest nextBillingDate among ACTIVE members.
  DateTime? get nextBillingDate {
    final active = members.where((m) => m.isActive).toList();
    if (active.isEmpty) return null;
    return active
        .map((m) => m.nextBillingDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Most recent lastChargedAt among ACTIVE members.
  DateTime? get lastBilledAt {
    final active = members.where((m) => m.isActive).toList();
    if (active.isEmpty) return null;
    return active
        .map((m) => m.lastChargedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final membersRaw = json['members'];
    final List<SubscriptionMember> members = membersRaw is List
        ? membersRaw
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionMember.fromJson)
            .toList()
        : [];

    final invitesRaw = json['pendingInvitations'];
    final List<SubInvitation> invitations = invitesRaw is List
        ? invitesRaw
            .whereType<Map<String, dynamic>>()
            .map(SubInvitation.fromJson)
            .toList()
        : [];

    return Subscription(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      groupId: json['groupId']?.toString(),
      groupName: json['groupName'] as String?,
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      amount: _safeDouble(json['amount']),
      currency: (json['currency'] ?? 'VND').toString(),
      billingCycle: (json['billingCycle'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdByName: json['createdByName'] as String?,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      cancelledAt: parseDate(json['cancelledAt']),
      members: members,
      pendingInvitations: invitations,
      memberCount: json['memberCount'] is int
          ? json['memberCount'] as int
          : members.where((m) => m.isActive).length,
    );
  }
}

class SubscriptionMember {
  final String id;
  final String userId;
  /// Amount this member pays per cycle (frozen at join time).
  final double amount;
  final String status;
  final DateTime joinedAt;
  final DateTime nextBillingDate;
  final DateTime lastChargedAt;
  final int retryCount;
  final DateTime? leftAt;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const SubscriptionMember({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    required this.joinedAt,
    required this.nextBillingDate,
    required this.lastChargedAt,
    this.retryCount = 0,
    this.leftAt,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  bool get isActive => status == 'ACTIVE';
  bool get hasLeft => status == 'LEFT';

  factory SubscriptionMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return SubscriptionMember(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? user?['id'] ?? user?['_id'] ?? '').toString(),
      amount: _safeDouble(json['amount']),
      status: (json['status'] ?? '').toString(),
      joinedAt: parseDate(json['joinedAt']),
      nextBillingDate: parseDate(json['nextBillingDate']),
      lastChargedAt: parseDate(json['lastChargedAt']),
      retryCount: json['retryCount'] as int? ?? 0,
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'].toString())
          : null,
      email: user?['email'] as String?,
      displayName: user?['displayName'] as String?,
      avatarUrl: user?['avatarUrl'] as String?,
    );
  }
}

class SubInvitation {
  final String id;
  final String subscriptionId;
  final String inviteeId;
  final String invitedBy;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? inviteeEmail;
  final String? inviteeDisplayName;
  final String? inviteeAvatarUrl;

  const SubInvitation({
    required this.id,
    required this.subscriptionId,
    required this.inviteeId,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.inviteeEmail,
    this.inviteeDisplayName,
    this.inviteeAvatarUrl,
  });

  bool get isPending => status == 'PENDING';

  factory SubInvitation.fromJson(Map<String, dynamic> json) {
    final invitee = json['invitee'] as Map<String, dynamic>?;
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return SubInvitation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      inviteeId: (json['inviteeId'] ?? '').toString(),
      invitedBy: (json['invitedBy'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      expiresAt: parseDate(json['expiresAt']),
      createdAt: parseDate(json['createdAt']),
      inviteeEmail: invitee?['email'] as String?,
      inviteeDisplayName: invitee?['displayName'] as String?,
      inviteeAvatarUrl: invitee?['avatarUrl'] as String?,
    );
  }
}
