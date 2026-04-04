import 'package:equatable/equatable.dart';

class Receipt extends Equatable {
  final String id;
  final String imageUrl;
  final String? note;
  final DateTime receiptDate;
  final List<ReceiptTag> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Receipt({
    required this.id,
    required this.imageUrl,
    this.note,
    required this.receiptDate,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, imageUrl, note, receiptDate, tags, createdAt, updatedAt];
}

class ReceiptTag extends Equatable {
  final String id;
  final String name;
  final String color;

  const ReceiptTag({
    required this.id,
    required this.name,
    required this.color,
  });

  @override
  List<Object?> get props => [id, name, color];
}

class ReceiptDaySummary extends Equatable {
  final String date; // YYYY-MM-DD (UTC)
  final int count;
  final List<String> thumbUrls;

  const ReceiptDaySummary({
    required this.date,
    required this.count,
    this.thumbUrls = const [],
  });

  @override
  List<Object?> get props => [date, count, thumbUrls];
}
