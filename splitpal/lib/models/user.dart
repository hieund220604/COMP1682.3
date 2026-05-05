/// Unified User model — replaces User entity + UserModel.

/// Safely parse balance that might be Decimal128 Map, num, or String.
double _parseBalance(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  if (v is Map) {
    final dec = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (dec != null) return double.tryParse(dec.toString()) ?? 0;
  }
  return 0;
}
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
  final bool isPro;
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
    this.isPro = false,
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
      balance: _parseBalance(balanceRaw),
      currency: currencyRaw as String? ?? 'VND',
      isActive: isActive,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      pushNotificationsEnabled:
          json['pushNotificationsEnabled'] as bool? ?? true,
      isPro: json['isPro'] as bool? ?? false,
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
        'isPro': isPro,
        'createdAt': createdAt.toIso8601String(),
      };
}
