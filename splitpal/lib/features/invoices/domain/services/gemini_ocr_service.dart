import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

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
      final itemsRaw = json['items'] as List<dynamic>? ?? [];
      final items = itemsRaw
          .map((item) => InvoiceItemData.fromJson(item as Map<String, dynamic>))
          .toList();

      return InvoiceOcrData(
        title: json['title'] as String? ?? 'Unknown',
        invoiceDate: _parseDate(json['invoiceDate']),
        items: items,
        amountTotal: (json['amountTotal'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'VND',
        note: json['note'] as String?,
        confidence: json['confidence'] as String? ?? 'MEDIUM',
      );
    } catch (e) {
      throw Exception('Failed to parse OCR data: $e');
    }
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
    return InvoiceItemData(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'amount': amount,
  };
}

class GeminiOcrService {
  late final GenerativeModel _model;
  static const String _geminiModelName = 'gemini-1.5-flash';

  GeminiOcrService({required String apiKey}) {
    _model = GenerativeModel(
      model: _geminiModelName,
      apiKey: apiKey,
    );
  }

  final String _extractionPrompt = '''You are an expert invoice OCR system. Analyze this invoice image and extract ALL information in structured JSON format.

IMPORTANT: Return ONLY valid JSON (no markdown, no extra text). The JSON must follow this exact structure:
{
  "title": "vendor/shop name",
  "invoiceDate": "YYYY-MM-DD",
  "items": [
    {
      "name": "item name",
      "quantity": number,
      "unitPrice": number,
      "amount": number
    }
  ],
  "amountTotal": number,
  "currency": "VND/USD/EUR/...",
  "note": "any additional notes (optional)",
  "confidence": "HIGH/MEDIUM/LOW"
}

Rules:
1. Extract ALL line items from invoice
2. amountTotal must be the final total
3. Currency should be detected (VND for Vietnam, USD for US, etc.)
4. If date is unclear, use today's date in YYYY-MM-DD format
5. quantity: default to 1 if not specified
6. unitPrice: calculate if only amount is shown (amount/quantity)
7. confidence: HIGH if all data clear, MEDIUM if some unclear, LOW if mostly estimate
8. Return ONLY the JSON object, nothing else
9. DO NOT include markdown formatting (no ```json```)

Return valid JSON ONLY:''';

  Future<InvoiceOcrData> extractInvoiceFromImage(File imageFile) async {
    try {
      // Read image as bytes
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Determine MIME type
      final mimeType = _getMimeType(imageFile.path);

      // Call Gemini API
      final response = await _model.generateContent([
        Content.multi([
          TextPart(_extractionPrompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]);

      // Extract text response
      final responseText = response.text ?? '';

      if (responseText.isEmpty) {
        return InvoiceOcrData(
          title: '',
          invoiceDate: DateTime.now(),
          items: [],
          amountTotal: 0.0,
          currency: 'VND',
          confidence: 'LOW',
          extractionError: 'No response from Gemini API',
        );
      }

      // Parse JSON response
      final cleanedText = _cleanJsonResponse(responseText);
      final jsonData = jsonDecode(cleanedText);
      
      final ocrData = InvoiceOcrData.fromJson(jsonData as Map<String, dynamic>);
      return ocrData;
    } catch (e) {
      return InvoiceOcrData(
        title: '',
        invoiceDate: DateTime.now(),
        items: [],
        amountTotal: 0.0,
        currency: 'VND',
        confidence: 'LOW',
        extractionError: 'OCR Error: ${e.toString()}',
      );
    }
  }

  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _cleanJsonResponse(String response) {
    // Remove markdown code blocks if present
    String cleaned = response.replaceAll('```json', '').replaceAll('```', '');
    
    // Try to find JSON object boundaries
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    
    if (jsonStart != -1 && jsonEnd != -1 && jsonStart < jsonEnd) {
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
    }
    
    return cleaned.trim();
  }
}
