class Invoice {
  final String id;
  final String groupId;
  final String title;
  final double amountTotal;
  final String currency;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime invoiceDate;
  final String? imageUrl;
  final String? note;
  final bool isLocked;
  final String? paymentRequestId;
  final bool isAdjustment;
  final String? originalInvoiceId;
  final String status; // DRAFT, SUBMITTED, LOCKED
  final DateTime createdAt;
  final List<InvoiceItem> items;

  // Multi-currency fields
  final double? convertedAmountTotal;
  final double? exchangeRate;
  final String? baseCurrency;

  Invoice({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amountTotal,
    required this.currency,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.invoiceDate,
    this.imageUrl,
    this.note,
    required this.isLocked,
    this.paymentRequestId,
    required this.isAdjustment,
    this.originalInvoiceId,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.convertedAmountTotal,
    this.exchangeRate,
    this.baseCurrency,
  });

  bool get hasCurrencyConversion => convertedAmountTotal != null && exchangeRate != null;
}

/// Per-user split entry returned by the backend.
class InvoiceItemSplit {
  final String userId;
  final double value; // % | exact amount | weight

  InvoiceItemSplit({required this.userId, required this.value});
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String name;
  final double amount;
  /// EQUAL | PERCENTAGE | CUSTOM | WEIGHT
  final String splitType;
  final List<String> assignedTo; // List of userIds
  final List<String> assignedToNames; // List of user names (from backend)
  final double sharePerPerson; // Calculated share per person (EQUAL only)
  final List<InvoiceItemSplit> splits; // Per-user splits (non-EQUAL)

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.name,
    required this.amount,
    this.splitType = 'EQUAL',
    required this.assignedTo,
    this.assignedToNames = const [],
    this.sharePerPerson = 0.0,
    this.splits = const [],
  });
}

class PaymentRequest {
  final String id;
  final String groupId;
  final String createdBy;
  final List<String> invoiceIds;
  final String status; // ISSUED, PARTIALLY_PAID, PAID, CANCELLED
  final DateTime issuedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  PaymentRequest({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.invoiceIds,
    required this.status,
    required this.issuedAt,
    this.paidAt,
    this.cancelledAt,
    required this.createdAt,
  });
}

class Transfer {
  final String id;
  final String paymentRequestId;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final String fromName; // User name (from backend)
  final String toName; // User name (from backend)
  final double amount;
  final String status; // PENDING, COMPLETED, FAILED, CANCELLED
  final DateTime? paidAt;
  final bool otpVerified;
  final DateTime createdAt;

  // Currency conversion info
  final String? originalCurrency;
  final double? originalAmount;
  final String? convertedCurrency;
  final double? exchangeRate;

  Transfer({
    required this.id,
    required this.paymentRequestId,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    this.fromName = '',
    this.toName = '',
    required this.amount,
    required this.status,
    this.paidAt,
    required this.otpVerified,
    required this.createdAt,
    this.originalCurrency,
    this.originalAmount,
    this.convertedCurrency,
    this.exchangeRate,
  });

  bool get isCancelled => status == 'CANCELLED';
  bool get isPending => status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';
  bool get hasCurrencyConversion => originalCurrency != null && originalAmount != null;
}

class MyBalance {
  final double totalOwed;
  final double totalOwedToMe;
  final double netBalance;
  final List<DebtSummary> debts;

  MyBalance({
    required this.totalOwed,
    required this.totalOwedToMe,
    required this.netBalance,
    required this.debts,
  });
}

class DebtSummary {
  final String creditorId;
  final String creditorName;
  final double amount;

  DebtSummary({
    required this.creditorId,
    required this.creditorName,
    required this.amount,
  });
}
