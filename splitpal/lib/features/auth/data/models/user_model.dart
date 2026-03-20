import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    super.displayName,
    super.avatarUrl,
    required super.balance,
    required super.currency,
    required super.isActive,
    super.twoFactorEnabled = false,
    super.pushNotificationsEnabled = true,
    required super.createdAt,
  });

  /// Manual parsing to tolerate backend payloads that don't include
  /// every field expected by the domain entity.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['userId'] ?? json['_id'];
    final balanceRaw = json['balance'];
    final currencyRaw = json['currency'];

    // Backend may send a `status` string instead of a boolean flag.
    final status = (json['status'] as String?)?.toLowerCase();
    final isActive = status != null
        ? status == 'active'
        : (json['isActive'] as bool?) ?? true;

    final createdAtRaw = json['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    return UserModel(
      id: (rawId ?? '').toString(),
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      balance: balanceRaw == null ? 0 : (balanceRaw as num).toDouble(),
      currency: currencyRaw as String? ?? 'VND',
      isActive: isActive,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      pushNotificationsEnabled:
          json['pushNotificationsEnabled'] as bool? ?? true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'balance': balance,
        'currency': currency,
        'isActive': isActive,
        'twoFactorEnabled': twoFactorEnabled,
        'pushNotificationsEnabled': pushNotificationsEnabled,
        'createdAt': createdAt.toIso8601String(),
      };

  // Convert to entity
  User toEntity() => User(
        id: id,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        balance: balance,
        currency: currency,
        isActive: isActive,
        twoFactorEnabled: twoFactorEnabled,
        pushNotificationsEnabled: pushNotificationsEnabled,
        createdAt: createdAt,
      );
}
