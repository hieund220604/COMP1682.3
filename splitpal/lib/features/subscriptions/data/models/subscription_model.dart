import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_member.dart';
import 'subscription_member_model.dart';

class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.groupId,
    super.groupName,
    required super.name,
    super.description,
    required super.amount,
    required super.currency,
    required super.billingCycle,
    required super.status,
    required super.nextBillingDate,
    super.lastBilledAt,
    required super.createdBy,
    super.createdByName,
    required super.createdAt,
    super.cancelledAt,
    super.retryCount = 0,
    super.failureReason,
    super.lastAttemptAt,
    super.members = const [],
    super.memberCount = 0,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    List<SubscriptionMember> members = [];
    if (membersRaw is List) {
      members = membersRaw
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionMemberModel.fromJson)
          .toList();
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SubscriptionModel(
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
