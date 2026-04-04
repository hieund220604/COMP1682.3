import 'dart:io';

import '../../domain/entities/receipt.dart';

class ReceiptModel extends Receipt {
  const ReceiptModel({
    required super.id,
    required super.imageUrl,
    super.note,
    required super.receiptDate,
    required super.tags,
    required super.createdAt,
    super.updatedAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawTags = json['tags'] ?? json['tagIds'];
    final List<ReceiptTagModel> tags;
    if (rawTags is List) {
      tags = rawTags.map((t) => ReceiptTagModel.fromJson(_normalizeTag(t))).toList();
    } else {
      tags = [];
    }

    return ReceiptModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      imageUrl: _fixLocalhost(json['imageUrl'] ?? ''),
      note: json['note'],
      receiptDate: DateTime.parse(json['receiptDate'] ?? json['date'] ?? DateTime.now().toIso8601String()),
      tags: tags,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}

class ReceiptTagModel extends ReceiptTag {
  const ReceiptTagModel({
    required super.id,
    required super.name,
    required super.color,
  });

  factory ReceiptTagModel.fromJson(Map<String, dynamic> json) {
    return ReceiptTagModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? json['label'] ?? json['id'] ?? '',
      color: json['color'] ?? 'blue',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };
}

class ReceiptDaySummaryModel extends ReceiptDaySummary {
  const ReceiptDaySummaryModel({
    required super.date,
    required super.count,
    super.thumbUrls,
  });

  factory ReceiptDaySummaryModel.fromJson(Map<String, dynamic> json) {
    return ReceiptDaySummaryModel(
      date: json['date'] ?? '',
      count: (json['count'] ?? 0) as int,
      thumbUrls: (json['thumbUrls'] as List<dynamic>?)?.map((e) => _fixLocalhost(e.toString())).toList() ?? const [],
    );
  }
}

Map<String, dynamic> _normalizeTag(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) return {'id': raw, 'name': raw};
  return {'id': raw.toString(), 'name': raw.toString()};
}

String _fixLocalhost(String url) {
  if (Platform.isAndroid && url.contains('localhost')) {
    return url.replaceAll('localhost', '10.0.2.2');
  }
  return url;
}
