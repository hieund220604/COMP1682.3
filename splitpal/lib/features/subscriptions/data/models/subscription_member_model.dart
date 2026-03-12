import '../../domain/entities/subscription_member.dart';

class SubscriptionMemberModel extends SubscriptionMember {
  const SubscriptionMemberModel({
    required super.id,
    required super.userId,
    required super.shareAmount,
    required super.status,
    required super.joinedAt,
    super.leftAt,
    super.email,
    super.displayName,
    super.avatarUrl,
  });

  factory SubscriptionMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return SubscriptionMemberModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? user?['id'] ?? user?['_id'] ?? '').toString(),
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
