import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

// ─── Data Classes ────────────────────────────────────────────────────────────

class InvoiceOcrData {
  final String title;
  final DateTime invoiceDate;
  final List<InvoiceItemData> items;
  final double amountTotal;
  final String currency;
  final String? note;
  final String confidence; // HIGH, MEDIUM, LOW
  final String? extractionError;

  InvoiceOcrData({
    required this.title,
    required this.invoiceDate,
    required this.items,
    required this.amountTotal,
    required this.currency,
    this.note,
    required this.confidence,
    this.extractionError,
  });

  factory InvoiceOcrData.fromJson(Map<String, dynamic> json) {
    try {
      final itemsRaw =
          (json['items'] as List<dynamic>?) ??
          (json['lineItems'] as List<dynamic>?) ??
          const <dynamic>[];
      final items = itemsRaw
          .map((item) => InvoiceItemData.fromJson(item as Map<String, dynamic>))
          .toList();

      final confidenceRaw =
          (json['confidence'] as String?)?.trim().toUpperCase() ?? 'MEDIUM';
      final confidence =
          confidenceRaw == 'HIGH' || confidenceRaw == 'LOW' || confidenceRaw == 'MEDIUM'
              ? confidenceRaw
              : 'MEDIUM';

      return InvoiceOcrData(
        title:
            (json['title'] as String?)?.trim().isNotEmpty == true
                ? (json['title'] as String).trim()
                : (json['vendorName'] as String?)?.trim().isNotEmpty == true
                    ? (json['vendorName'] as String).trim()
                    : (json['merchant'] as String?)?.trim().isNotEmpty == true
                        ? (json['merchant'] as String).trim()
                        : 'Scanned Invoice',
        invoiceDate: _parseDate(
          json['invoiceDate'] ?? json['date'] ?? json['issuedDate'],
        ),
        items: items,
        amountTotal: _parseNum(
          json['amountTotal'] ?? json['totalAmount'] ?? json['total'],
        ),
        currency:
            ((json['currency'] ?? json['currencyCode']) as String?)
                ?.trim()
                .toUpperCase() ??
            'VND',
        note: (json['note'] ?? json['description']) as String?,
        confidence: confidence,
        extractionError: (json['extractionError'] as String?)?.trim(),
      );
    } catch (e) {
      throw Exception('Failed to parse OCR data: $e');
    }
  }

  static double _parseNum(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final normalized = raw
          .replaceAll(RegExp(r'[^0-9,.-]'), '')
          .replaceAll(',', '')
          .trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  static DateTime _parseDate(dynamic date) {
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'invoiceDate': invoiceDate.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
    'amountTotal': amountTotal,
    'currency': currency,
    'note': note,
    'confidence': confidence,
    'extractionError': extractionError,
  };
}

class InvoiceItemData {
  final String name;
  final int quantity;
  final double unitPrice;
  final double amount;

  InvoiceItemData({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory InvoiceItemData.fromJson(Map<String, dynamic> json) {
    final amount = InvoiceOcrData._parseNum(
      json['amount'] ?? json['total'] ?? json['lineTotal'],
    );
    int quantity = InvoiceOcrData._parseNum(
      json['quantity'] ?? json['qty'],
    ).round();
    if (quantity <= 0) quantity = 1;

    double unitPrice = InvoiceOcrData._parseNum(
      json['unitPrice'] ?? json['price'] ?? json['rate'],
    );
    if (unitPrice <= 0 && amount > 0) {
      unitPrice = amount / quantity;
    }

    return InvoiceItemData(
      name:
          ((json['name'] ?? json['itemName'] ?? json['description']) as String?)
              ?.trim() ??
          '',
      quantity: quantity,
      unitPrice: unitPrice,
      amount: amount > 0 ? amount : unitPrice * quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'amount': amount,
  };

  void dispose() {}
}

// ─── Provider ───────────────────────────────────────────────────────────────

class AiProvider with ChangeNotifier {
  final DioClient _dio;

  AiProvider({required DioClient dio}) : _dio = dio;

  /// Labels for UI style selection.
  static const Map<String, String> debtReminderStyles = {
    'funny': 'Funny and cheerful',
    'polite': 'Polite and respectful',
    'serious': 'Serious and decisive',
    'poetic': 'Poetic and dreamy',
    'gangster': 'Gangster and fun',
  };

  // ─── OCR State ───────────────────────────────────────────────────────────

  bool _isProcessing = false;
  String? _errorMessage;
  InvoiceOcrData? _extractedData;
  double _processingProgress = 0.0;

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  InvoiceOcrData? get extractedData => _extractedData;
  double get processingProgress => _processingProgress;

  /// Process an invoice image via backend OCR API.
  Future<InvoiceOcrData?> processInvoiceImage(
    File imageFile, {
    String? groupId,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    _processingProgress = 0.1;
    notifyListeners();

    try {
      // Step 1: Prepare upload
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        if (groupId != null) 'groupId': groupId,
      });

      _processingProgress = 0.3;
      notifyListeners();

      // Step 2: Upload & wait for AI response
      final resp = await _dio.post(
        ApiConstants.aiOcrInvoice,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Map upload progress to 0.3 → 0.6 range
            _processingProgress = 0.3 + (sent / total) * 0.3;
            notifyListeners();
          }
        },
      );

      _processingProgress = 0.8;
      notifyListeners();

      // Step 3: Parse response
      final data = resp.data;
      final payload =
          (data is Map && data.containsKey('data')) ? data['data'] : data;
      if (payload is! Map) {
        throw Exception('Invalid OCR response');
      }

      final result = InvoiceOcrData.fromJson(
          Map<String, dynamic>.from(payload as Map));
      _processingProgress = 1.0;

      if (result.extractionError != null) {
        _errorMessage = result.extractionError;
        _isProcessing = false;
        notifyListeners();
        return result;
      }

      _extractedData = result;
      _isProcessing = false;
      notifyListeners();
      return result;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        _errorMessage = e.response?.data['message'];
      } else {
        _errorMessage = 'Error processing image: ${e.message}';
      }
      _isProcessing = false;
      _processingProgress = 0.0;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Error processing image: ${e.toString()}';
      _isProcessing = false;
      _processingProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  /// Extract invoice suggestion from chat message text (via server API).
  Future<Map<String, dynamic>> extractInvoiceFromText(
    String text, {
    String? groupId,
  }) async {
    if (text.trim().isEmpty) throw Exception('Message is empty');

    try {
      final resp = await _dio.post(ApiConstants.aiExtractInvoice, data: {
        'text': text.trim(),
        if (groupId != null) 'groupId': groupId,
      });

      final data = resp.data;
      final payload =
          (data is Map && data.containsKey('data')) ? data['data'] : data;
      return Map<String, dynamic>.from(payload ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        throw Exception(e.response?.data['message']);
      }
      rethrow;
    }
  }

  /// Generate a debt reminder via backend AI API.
  Future<String> generateDebtReminder({
    required String debtorName,
    required List<Map<String, dynamic>> debts,
    required String style,
  }) async {
    final resp = await _dio.post(ApiConstants.aiDebtReminder, data: {
      'debtorName': debtorName,
      'debts': debts,
      'style': style,
    });

    final data = resp.data;
    final payload =
        (data is Map && data.containsKey('data')) ? data['data'] : data;
    if (payload is Map && payload['message'] is String) {
      return payload['message'] as String;
    }
    throw Exception('Invalid debt reminder response');
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetOcrData() {
    _extractedData = null;
    _errorMessage = null;
    _processingProgress = 0.0;
    notifyListeners();
  }
}