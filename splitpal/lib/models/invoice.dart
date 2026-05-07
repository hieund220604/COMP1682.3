// Unified Invoice models — replaces entity + model pairs.

/// Safely parse a numeric value that might be a Decimal128 Map, num, or String.
double _safeDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  if (v is Map) {
    // MongoDB Decimal128: {"\$numberDecimal": "100000"}
    final dec = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (dec != null) return double.tryParse(dec.toString()) ?? fallback;
  }
  return fallback;
}

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

  bool get hasCurrencyConversion =>
      convertedAmountTotal != null && exchangeRate != null;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    List<InvoiceItem> items = [];
    if (itemsRaw is List) {
      items = itemsRaw.map((i) => InvoiceItem.fromJson(i)).toList();
    }

    return Invoice(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['groupId'] ?? '',
      title: json['title'] ?? '',
      amountTotal: _safeDouble(json['amountTotal']),
      currency: json['currency'] ?? 'VND',
      uploadedBy: json['uploadedBy'] is Map
          ? (json['uploadedBy']['id'] ?? '')
          : (json['uploadedBy'] ?? ''),
      uploadedByName: json['uploadedBy'] is Map
          ? (json['uploadedBy']['displayName'] ??
              json['uploadedBy']['email'] ??
              'Unknown')
          : 'Unknown',
      invoiceDate: DateTime.parse(
          json['invoiceDate'] ?? DateTime.now().toIso8601String()),
      imageUrl: json['imageUrl'],
      note: json['note'],
      isLocked: json['isLocked'] ?? false,
      paymentRequestId: json['paymentRequestId'],
      isAdjustment: json['isAdjustment'] ?? false,
      originalInvoiceId: json['originalInvoiceId'],
      status: json['status'] ?? 'DRAFT',
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      items: items,
      convertedAmountTotal: json['convertedAmountTotal'] != null
          ? _safeDouble(json['convertedAmountTotal'])
          : null,
      exchangeRate: json['exchangeRate'] != null
          ? _safeDouble(json['exchangeRate'])
          : null,
      baseCurrency: json['baseCurrency'],
    );
  }
}

/// Per-user split entry returned by the backend.
class InvoiceItemSplit {
  final String userId;
  final double value;

  InvoiceItemSplit({required this.userId, required this.value});
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String name;
  final double amount;
  final String splitType; // EQUAL | PERCENTAGE | CUSTOM
  final List<String> assignedTo;
  final List<String> assignedToNames;
  final double sharePerPerson;
  final List<InvoiceItemSplit> splits;

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

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final assignedToRaw = json['assignedTo'];
    List<String> assignedTo = [];
    List<String> assignedToNames = [];

    if (assignedToRaw is List) {
      for (var item in assignedToRaw) {
        if (item is Map) {
          assignedTo.add(item['id'] ?? '');
          assignedToNames
              .add(item['displayName'] ?? item['email'] ?? 'Unknown');
        } else {
          assignedTo.add(item.toString());
        }
      }
    }

    return InvoiceItem(
      id: json['id'] ?? json['_id'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      name: json['name'] ?? '',
      amount: _safeDouble(json['amount']),
      splitType: json['splitType'] ?? 'EQUAL',
      assignedTo: assignedTo,
      assignedToNames: assignedToNames,
      sharePerPerson: _safeDouble(json['sharePerPerson']),
      splits: _parseSplits(json['splits']),
    );
  }

  static List<InvoiceItemSplit> _parseSplits(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      if (e is Map) {
        return InvoiceItemSplit(
          userId: (e['userId'] ?? '').toString(),
          value: _safeDouble(e['value']),
        );
      }
      return InvoiceItemSplit(userId: '', value: 0);
    }).toList();
  }
}

/// Data class for creating invoice items (sent to API).
class InvoiceItemCreate {
  final String name;
  final double amount;
  final String splitType;
  final List<String> assignedTo;
  final List<InvoiceItemSplitCreate> splits;

  InvoiceItemCreate({
    required this.name,
    required this.amount,
    this.splitType = 'EQUAL',
    required this.assignedTo,
    this.splits = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'splitType': splitType,
        'assignedTo': assignedTo,
        if (splits.isNotEmpty) 'splits': splits.map((s) => s.toJson()).toList(),
      };
}

/// DTO for per-user split when creating invoice items.
class InvoiceItemSplitCreate {
  final String userId;
  final double value;

  InvoiceItemSplitCreate({required this.userId, required this.value});

  Map<String, dynamic> toJson() => {'userId': userId, 'value': value};
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
  final DateTime? expiresAt;
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
    this.expiresAt,
    required this.createdAt,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    final invoiceIdsRaw = json['invoiceIds'];
    List<String> invoiceIds = [];
    if (invoiceIdsRaw is List) {
      invoiceIds = invoiceIdsRaw.map((e) => e.toString()).toList();
    }

    return PaymentRequest(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['groupId'] ?? '',
      createdBy: json['createdBy'] is Map
          ? (json['createdBy']['id'] ?? '')
          : (json['createdBy'] ?? ''),
      invoiceIds: invoiceIds,
      status: json['status'] ?? 'ISSUED',
      issuedAt:
          DateTime.parse(json['issuedAt'] ?? DateTime.now().toIso8601String()),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Represents a single debt allocation within a transfer,
/// mapping how much of the transfer pays toward a specific invoice debt.
class DebtAllocation {
  final String originalDebtId;
  final String invoiceId;
  final String invoiceTitle;
  final double allocatedAmount;

  DebtAllocation({
    required this.originalDebtId,
    required this.invoiceId,
    required this.invoiceTitle,
    required this.allocatedAmount,
  });

  factory DebtAllocation.fromJson(Map<String, dynamic> json) {
    return DebtAllocation(
      originalDebtId: json['originalDebtId'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      invoiceTitle: json['invoiceTitle'] ?? 'Unknown',
      allocatedAmount: _safeDouble(json['allocatedAmount']),
    );
  }
}

/// A single debt entry showing how much is owed from a specific invoice.
class DebtContextEntry {
  final String invoiceId;
  final String invoiceTitle;
  final double debtAmount;

  DebtContextEntry({
    required this.invoiceId,
    required this.invoiceTitle,
    required this.debtAmount,
  });

  factory DebtContextEntry.fromJson(Map<String, dynamic> json) {
    return DebtContextEntry(
      invoiceId: json['invoiceId'] ?? '',
      invoiceTitle: json['invoiceTitle'] ?? 'Unknown',
      debtAmount: _safeDouble(json['debtAmount']),
    );
  }
}

/// Full debt context between payer and receiver.
class DebtContext {
  final List<DebtContextEntry> youOwe;
  final List<DebtContextEntry> theyOwe;
  final double totalYouOwe;
  final double totalTheyOwe;

  DebtContext({
    required this.youOwe,
    required this.theyOwe,
    required this.totalYouOwe,
    required this.totalTheyOwe,
  });

  double get netAmount => totalYouOwe - totalTheyOwe;
  bool get hasOffset => theyOwe.isNotEmpty;

  factory DebtContext.fromJson(Map<String, dynamic> json) {
    return DebtContext(
      youOwe: (json['youOwe'] as List? ?? [])
          .map((e) => DebtContextEntry.fromJson(e))
          .toList(),
      theyOwe: (json['theyOwe'] as List? ?? [])
          .map((e) => DebtContextEntry.fromJson(e))
          .toList(),
      totalYouOwe: _safeDouble(json['totalYouOwe']),
      totalTheyOwe: _safeDouble(json['totalTheyOwe']),
    );
  }
}

class Transfer {
  final String id;
  final String paymentRequestId;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final String fromName;
  final String toName;
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

  // Debt allocation breakdown (nullable for hot-reload safety)
  final List<DebtAllocation>? _debtAllocations;
  List<DebtAllocation> get debtAllocations => _debtAllocations ?? const [];

  // Full debt context (nullable for hot-reload safety)
  final DebtContext? _debtContext;
  DebtContext? get debtContext => _debtContext;

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
    List<DebtAllocation> debtAllocations = const [],
    DebtContext? debtContext,
  }) : _debtAllocations = debtAllocations,
       _debtContext = debtContext;

  bool get isCancelled => status == 'CANCELLED';
  bool get isPending => status == 'PENDING';
  bool get isCompleted => status == 'COMPLETED';
  bool get hasCurrencyConversion =>
      originalCurrency != null && originalAmount != null;

  factory Transfer.fromJson(Map<String, dynamic> json) {
    String fromUserId = '';
    String toUserId = '';
    String fromName = '';
    String toName = '';

    if (json['fromUser'] is Map) {
      fromUserId = json['fromUser']['id'] ?? '';
      fromName = json['fromUser']['displayName'] ??
          json['fromUser']['email'] ??
          'Unknown';
    } else {
      fromUserId = json['fromUserId'] ?? '';
    }

    if (json['toUser'] is Map) {
      toUserId = json['toUser']['id'] ?? '';
      toName = json['toUser']['displayName'] ??
          json['toUser']['email'] ??
          'Unknown';
    } else {
      toUserId = json['toUserId'] ?? '';
    }

    // Parse debt allocations
    final allocsRaw = json['debtAllocations'];
    List<DebtAllocation> allocations = [];
    if (allocsRaw is List) {
      allocations = allocsRaw.map((a) => DebtAllocation.fromJson(a)).toList();
    }

    // Parse debt context
    DebtContext? debtContext;
    if (json['debtContext'] is Map<String, dynamic>) {
      debtContext = DebtContext.fromJson(json['debtContext']);
    }

    return Transfer(
      id: json['id'] ?? json['_id'] ?? '',
      paymentRequestId: json['paymentRequestId'] ?? '',
      groupId: json['groupId'] ?? '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      fromName: fromName,
      toName: toName,
      amount: _safeDouble(json['amount']),
      status: json['status'] ?? 'PENDING',
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      otpVerified: json['otpVerified'] ?? false,
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
      originalCurrency: json['originalCurrency'],
      originalAmount: json['originalAmount'] != null
          ? _safeDouble(json['originalAmount'])
          : null,
      convertedCurrency: json['convertedCurrency'],
      exchangeRate: json['exchangeRate'] != null
          ? _safeDouble(json['exchangeRate'])
          : null,
      debtAllocations: allocations,
      debtContext: debtContext,
    );
  }
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

  factory MyBalance.fromJson(Map<String, dynamic> json) {
    final debtsRaw = json['debts'];
    List<DebtSummary> debts = [];
    if (debtsRaw is List) {
      debts = debtsRaw.map((d) => DebtSummary.fromJson(d)).toList();
    }

    return MyBalance(
      totalOwed: _safeDouble(json['totalOwed']),
      totalOwedToMe: _safeDouble(json['totalOwedToMe']),
      netBalance: _safeDouble(json['netBalance']),
      debts: debts,
    );
  }
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

  factory DebtSummary.fromJson(Map<String, dynamic> json) => DebtSummary(
        creditorId: json['creditorId'] ?? '',
        creditorName: json['creditorName'] ?? '',
        amount: _safeDouble(json['amount']),
      );
}
