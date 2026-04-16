/// Unified User model — replaces User entity + UserModel.
class User {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final double balance;
  final String currency;
  final bool isActive;
  final bool twoFactorEnabled;
  final bool pushNotificationsEnabled;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.balance,
    required this.currency,
    required this.isActive,
    this.twoFactorEnabled = false,
    this.pushNotificationsEnabled = true,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['userId'] ?? json['_id'];
    final balanceRaw = json['balance'];
    final currencyRaw = json['currency'];

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

    return User(
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
}
