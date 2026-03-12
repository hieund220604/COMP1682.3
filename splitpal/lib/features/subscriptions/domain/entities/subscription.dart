import 'subscription_member.dart';

class Subscription {
  final String id;
  final String groupId;
  final String? groupName;  // Group name for display
  final String name;
  final String? description;
  final double amount;
  final String currency;
  final String billingCycle;
  final String status;
  final DateTime nextBillingDate;
  final DateTime? lastBilledAt;
  final String createdBy;
  final String? createdByName;  // Creator name for display
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
}
