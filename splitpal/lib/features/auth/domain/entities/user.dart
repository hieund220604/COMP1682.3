import 'package:equatable/equatable.dart';

class User extends Equatable {
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

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        balance,
        currency,
        isActive,
        twoFactorEnabled,
        pushNotificationsEnabled,
        createdAt,
      ];
}
