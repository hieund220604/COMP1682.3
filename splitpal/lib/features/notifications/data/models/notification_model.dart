import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationModel extends Equatable {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool read;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'read': read,
      'createdAt': createdAt,
    };
  }

  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      type: NotificationType.fromString(type),
      title: title,
      message: message,
      data: data,
      read: read,
      createdAt: DateTime.parse(createdAt),
    );
  }

  factory NotificationModel.fromEntity(NotificationEntity entity) {
    return NotificationModel(
      id: entity.id,
      type: entity.type.value,
      title: entity.title,
      message: entity.message,
      data: entity.data,
      read: entity.read,
      createdAt: entity.createdAt.toIso8601String(),
    );
  }

  @override
  List<Object?> get props => [id, type, title, message, data, read, createdAt];
}
