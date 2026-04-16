// Unified Notification model — replaces NotificationEntity + NotificationModel.

enum NotificationType {
  expenseCreated('EXPENSE_CREATED'),
  expenseUpdated('EXPENSE_UPDATED'),
  invoiceCreated('INVOICE_CREATED'),
  settlementCreated('SETTLEMENT_CREATED'),
  paymentReceived('PAYMENT_RECEIVED'),
  inviteReceived('INVITE_RECEIVED'),
  groupJoined('GROUP_JOINED'),
  balanceUpdated('BALANCE_UPDATED'),
  paymentRequestCancelled('PAYMENT_REQUEST_CANCELLED'),
  paymentRefunded('PAYMENT_REFUNDED');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.expenseCreated,
    );
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'title': title,
        'message': message,
        'data': data,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };
}
