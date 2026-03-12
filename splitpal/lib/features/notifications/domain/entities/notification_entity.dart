import 'package:equatable/equatable.dart';

enum NotificationType {
  expenseCreated('EXPENSE_CREATED'),
  expenseUpdated('EXPENSE_UPDATED'),
  invoiceCreated('INVOICE_CREATED'),
  settlementCreated('SETTLEMENT_CREATED'),
  paymentReceived('PAYMENT_RECEIVED'),
  inviteReceived('INVITE_RECEIVED'),
  groupJoined('GROUP_JOINED'),
  balanceUpdated('BALANCE_UPDATED');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.expenseCreated,
    );
  }
}

class NotificationEntity extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  NotificationEntity copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, type, title, message, data, read, createdAt];
}
