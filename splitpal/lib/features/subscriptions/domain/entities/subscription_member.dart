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
}
