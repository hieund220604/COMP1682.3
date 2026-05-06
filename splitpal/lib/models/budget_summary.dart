import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/core/utils/safe_parse.dart';

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
      monthlyBudget: json['monthlyBudget'] != null ? safeDouble(json['monthlyBudget']) : null,
        isArchived: json['isArchived'] ?? false,
      ),
      spent: safeDouble(json['spent']),
      remaining: safeDoubleOrNull(json['remaining']),
      percentage: safeDoubleOrNull(json['percentage']),
    );
  }
}
