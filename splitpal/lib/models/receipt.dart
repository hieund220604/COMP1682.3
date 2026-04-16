import 'dart:io';

/// Unified Receipt models — replaces entity + model pairs.

class Receipt {
  final String id;
  final String imageUrl;
  final double totalAmount;
  final String? note;
  final DateTime receiptDate;
  final List<ReceiptTag> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Receipt({
    required this.id,
    required this.imageUrl,
    this.totalAmount = 0.0,
    this.note,
    required this.receiptDate,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final dynamic rawTags = json['tags'] ?? json['tagIds'];
    final List<ReceiptTag> tags;
    if (rawTags is List) {
      tags = rawTags.map((t) => ReceiptTag.fromJson(_normalizeTag(t))).toList();
    } else {
      tags = [];
    }

    return Receipt(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      imageUrl: _fixLocalhost(json['imageUrl'] ?? ''),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      note: json['note'],
      receiptDate: DateTime.parse(
          json['receiptDate'] ?? json['date'] ?? DateTime.now().toIso8601String()),
      tags: tags,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}

class ReceiptTag {
  final String id;
  final String name;
  final String color;

  const ReceiptTag({
    required this.id,
    required this.name,
    required this.color,
  });

  factory ReceiptTag.fromJson(Map<String, dynamic> json) => ReceiptTag(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: json['name'] ?? json['label'] ?? json['id'] ?? '',
        color: json['color'] ?? 'blue',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };
}

class ReceiptDaySummary {
  final String date; // YYYY-MM-DD (UTC)
  final int count;
  final double totalAmount;
  final List<String> thumbUrls;

  const ReceiptDaySummary({
    required this.date,
    required this.count,
    this.totalAmount = 0.0,
    this.thumbUrls = const [],
  });

  factory ReceiptDaySummary.fromJson(Map<String, dynamic> json) =>
      ReceiptDaySummary(
        date: json['date'] ?? '',
        count: (json['count'] ?? 0) as int,
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
        thumbUrls: (json['thumbUrls'] as List<dynamic>?)
                ?.map((e) => _fixLocalhost(e.toString()))
                .toList() ??
            const [],
      );
}

// ─── helpers ─────────────────────────────────────────────

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
