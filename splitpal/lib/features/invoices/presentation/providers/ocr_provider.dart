import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../invoices/domain/services/gemini_ocr_service.dart';

class OcrProvider with ChangeNotifier {
  final GeminiOcrService _geminiService;

  OcrProvider({required GeminiOcrService geminiService})
      : _geminiService = geminiService;

  // State
  bool _isProcessing = false;
  String? _errorMessage;
  InvoiceOcrData? _extractedData;
  double _processingProgress = 0.0;

  // Getters
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  InvoiceOcrData? get extractedData => _extractedData;
  double get processingProgress => _processingProgress;

  Future<InvoiceOcrData?> processInvoiceImage(File imageFile) async {
    _isProcessing = true;
    _errorMessage = null;
    _processingProgress = 0.2;
    notifyListeners();

    try {
      _processingProgress = 0.5;
      notifyListeners();

      final result = await _geminiService.extractInvoiceFromImage(imageFile);

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
    } catch (e) {
      _errorMessage = 'Error processing image: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
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
