import 'package:flutter/foundation.dart';
import 'package:splitpal/models/receipt.dart';

class BudgetSummary {
  final ReceiptTag tag;
  final double spent;
  final double? remaining;
  final double? percentage;

  const BudgetSummary({
    required this.tag,
    required this.spent,
    this.remaining,
    this.percentage,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      tag: ReceiptTag(
        id: json['tagId'] ?? '',
        name: json['name'] ?? '',
        icon: json['icon'],
        color: json['color'] ?? 'blue',
        monthlyBudget: json['monthlyBudget']?.toDouble(),
        isArchived: json['isArchived'] ?? false,
      ),
      spent: (json['spent'] ?? 0).toDouble(),
      remaining: json['remaining']?.toDouble(),
      percentage: json['percentage']?.toDouble(),
    );
  }
}
