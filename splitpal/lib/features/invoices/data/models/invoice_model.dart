import '../../domain/entities/invoice.dart';

class InvoiceModel extends Invoice {
  InvoiceModel({
    required super.id,
    required super.groupId,
    required super.title,
    required super.amountTotal,
    required super.currency,
    required super.uploadedBy,
    required super.uploadedByName,
    required super.invoiceDate,
    super.imageUrl,
    super.note,
    required super.isLocked,
    super.paymentRequestId,
    required super.isAdjustment,
    super.originalInvoiceId,
    required super.status,
    required super.createdAt,
    super.items,
    super.convertedAmountTotal,
    super.exchangeRate,
    super.baseCurrency,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    List<InvoiceItem> items = [];
    if (itemsRaw is List) {
      items = itemsRaw.map((i) => InvoiceItemModel.fromJson(i)).toList();
    }

    return InvoiceModel(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['groupId'] ?? '',
      title: json['title'] ?? '',
      amountTotal: (json['amountTotal'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'VND',
      uploadedBy: json['uploadedBy'] is Map 
          ? (json['uploadedBy']['id'] ?? '') 
          : (json['uploadedBy'] ?? ''),
      uploadedByName: json['uploadedBy'] is Map
          ? (json['uploadedBy']['displayName'] ?? json['uploadedBy']['email'] ?? 'Unknown')
          : 'Unknown',
      invoiceDate: DateTime.parse(json['invoiceDate'] ?? DateTime.now().toIso8601String()),
      imageUrl: json['imageUrl'],
      note: json['note'],
      isLocked: json['isLocked'] ?? false,
      paymentRequestId: json['paymentRequestId'],
      isAdjustment: json['isAdjustment'] ?? false,
      originalInvoiceId: json['originalInvoiceId'],
      status: json['status'] ?? 'DRAFT',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      items: items,
      convertedAmountTotal: json['convertedAmountTotal'] != null ? (json['convertedAmountTotal']).toDouble() : null,
      exchangeRate: json['exchangeRate'] != null ? (json['exchangeRate']).toDouble() : null,
      baseCurrency: json['baseCurrency'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amountTotal': amountTotal,
      'currency': currency,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'invoiceDate': invoiceDate.toIso8601String(),
      'imageUrl': imageUrl,
      'note': note,
      'isLocked': isLocked,
      'paymentRequestId': paymentRequestId,
      'isAdjustment': isAdjustment,
      'originalInvoiceId': originalInvoiceId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((i) => (i as InvoiceItemModel).toJson()).toList(),
      if (convertedAmountTotal != null) 'convertedAmountTotal': convertedAmountTotal,
      if (exchangeRate != null) 'exchangeRate': exchangeRate,
      if (baseCurrency != null) 'baseCurrency': baseCurrency,
    };
  }
}

class InvoiceItemModel extends InvoiceItem {
  InvoiceItemModel({
    required super.id,
    required super.invoiceId,
    required super.name,
    required super.amount,
    super.splitType,
    required super.assignedTo,
    super.assignedToNames,
    super.sharePerPerson,
    super.splits,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final assignedToRaw = json['assignedTo'];
    List<String> assignedTo = [];
    List<String> assignedToNames = [];
    
    if (assignedToRaw is List) {
      for (var item in assignedToRaw) {
        if (item is Map) {
          // Backend returns: [{id, displayName, avatarUrl}]
          assignedTo.add(item['id'] ?? '');
          assignedToNames.add(item['displayName'] ?? item['email'] ?? 'Unknown');
        } else {
          // Fallback for simple string IDs
          assignedTo.add(item.toString());
        }
      }
    }

    return InvoiceItemModel(
      id: json['id'] ?? json['_id'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      splitType: json['splitType'] ?? 'EQUAL',
      assignedTo: assignedTo,
      assignedToNames: assignedToNames,
      sharePerPerson: (json['sharePerPerson'] ?? 0).toDouble(),
      splits: _parseSplits(json['splits']),
    );
  }

  static List<InvoiceItemSplit> _parseSplits(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      if (e is Map) {
        return InvoiceItemSplit(
          userId: (e['userId'] ?? '').toString(),
          value: (e['value'] ?? 0).toDouble(),
        );
      }
      return InvoiceItemSplit(userId: '', value: 0);
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'name': name,
      'amount': amount,
      'splitType': splitType,
      'assignedTo': assignedTo,
      'assignedToNames': assignedToNames,
      'sharePerPerson': sharePerPerson,
      if (splits.isNotEmpty)
        'splits': splits.map((s) => {'userId': s.userId, 'value': s.value}).toList(),
    };
  }
}

class PaymentRequestModel extends PaymentRequest {
  PaymentRequestModel({
    required super.id,
    required super.groupId,
    required super.createdBy,
    required super.invoiceIds,
    required super.status,
    required super.issuedAt,
    super.paidAt,
    super.cancelledAt,
    required super.createdAt,
  });

  factory PaymentRequestModel.fromJson(Map<String, dynamic> json) {
    final invoiceIdsRaw = json['invoiceIds'];
    List<String> invoiceIds = [];
    if (invoiceIdsRaw is List) {
      invoiceIds = invoiceIdsRaw.map((e) => e.toString()).toList();
    }

    return PaymentRequestModel(
      id: json['id'] ?? json['_id'] ?? '',
      groupId: json['groupId'] ?? '',
      createdBy: json['createdBy'] is Map 
          ? (json['createdBy']['id'] ?? '') 
          : (json['createdBy'] ?? ''),
      invoiceIds: invoiceIds,
      status: json['status'] ?? 'ISSUED',
      issuedAt: DateTime.parse(json['issuedAt'] ?? DateTime.now().toIso8601String()),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class TransferModel extends Transfer {
  TransferModel({
    required super.id,
    required super.paymentRequestId,
    required super.groupId,
    required super.fromUserId,
    required super.toUserId,
    super.fromName,
    super.toName,
    required super.amount,
    required super.status,
    super.paidAt,
    required super.otpVerified,
    required super.createdAt,
    super.originalCurrency,
    super.originalAmount,
    super.convertedCurrency,
    super.exchangeRate,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    // Extract user IDs and names from user objects if present
    String fromUserId = '';
    String toUserId = '';
    String fromName = '';
    String toName = '';

    if (json['fromUser'] is Map) {
      fromUserId = json['fromUser']['id'] ?? '';
      fromName = json['fromUser']['displayName'] ?? json['fromUser']['email'] ?? 'Unknown';
    } else {
      fromUserId = json['fromUserId'] ?? '';
    }

    if (json['toUser'] is Map) {
      toUserId = json['toUser']['id'] ?? '';
      toName = json['toUser']['displayName'] ?? json['toUser']['email'] ?? 'Unknown';
    } else {
      toUserId = json['toUserId'] ?? '';
    }

    return TransferModel(
      id: json['id'] ?? json['_id'] ?? '',
      paymentRequestId: json['paymentRequestId'] ?? '',
      groupId: json['groupId'] ?? '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      fromName: fromName,
      toName: toName,
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'PENDING',
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      otpVerified: json['otpVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      originalCurrency: json['originalCurrency'],
      originalAmount: json['originalAmount'] != null ? (json['originalAmount']).toDouble() : null,
      convertedCurrency: json['convertedCurrency'],
      exchangeRate: json['exchangeRate'] != null ? (json['exchangeRate']).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentRequestId': paymentRequestId,
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromName': fromName,
      'toName': toName,
      'amount': amount,
      'status': status,
      'paidAt': paidAt?.toIso8601String(),
      'otpVerified': otpVerified,
      'createdAt': createdAt.toIso8601String(),
      if (originalCurrency != null) 'originalCurrency': originalCurrency,
      if (originalAmount != null) 'originalAmount': originalAmount,
      if (convertedCurrency != null) 'convertedCurrency': convertedCurrency,
      if (exchangeRate != null) 'exchangeRate': exchangeRate,
    };
  }
}

class MyBalanceModel extends MyBalance {
  MyBalanceModel({
    required super.totalOwed,
    required super.totalOwedToMe,
    required super.netBalance,
    required super.debts,
  });

  factory MyBalanceModel.fromJson(Map<String, dynamic> json) {
    final debtsRaw = json['debts'];
    List<DebtSummary> debts = [];
    if (debtsRaw is List) {
      debts = debtsRaw.map((d) => DebtSummaryModel.fromJson(d)).toList();
    }

    return MyBalanceModel(
      totalOwed: (json['totalOwed'] ?? 0).toDouble(),
      totalOwedToMe: (json['totalOwedToMe'] ?? 0).toDouble(),
      netBalance: (json['netBalance'] ?? 0).toDouble(),
      debts: debts,
    );
  }
}

class DebtSummaryModel extends DebtSummary {
  DebtSummaryModel({
    required super.creditorId,
    required super.creditorName,
    required super.amount,
  });

  factory DebtSummaryModel.fromJson(Map<String, dynamic> json) {
    return DebtSummaryModel(
      creditorId: json['creditorId'] ?? '',
      creditorName: json['creditorName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}
