import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/network/dio_client.dart';
import '../../core/utils/upload_repository.dart';
import '../../models/receipt.dart';

/// Fat Provider — calls DioClient directly for receipt diary operations.
class ReceiptProvider with ChangeNotifier {
  final DioClient _dio;
  final UploadRepository _uploadRepository;

  ReceiptProvider({
    required DioClient dio,
    required UploadRepository uploadRepository,
  })  : _dio = dio,
        _uploadRepository = uploadRepository;

  // ─── State ──────────────────────────────────────────────
  bool _loadingMonth = false;
  bool _loadingDay = false;
  bool _loadingBudget = false;
  bool _saving = false;
  String? _error;
  List<ReceiptDaySummary> _monthSummary = [];
  List<Receipt> _dayReceipts = [];
  List<ReceiptTag> _tags = [];

  bool get isLoadingMonth => _loadingMonth;
  bool get isLoadingDay => _loadingDay;
  bool get isSaving => _saving;
  String? get error => _error;
  List<ReceiptDaySummary> get monthSummary => _monthSummary;
  List<Receipt> get dayReceipts => _dayReceipts;
  List<ReceiptTag> get tags => _tags;
  bool get hasTags => _tags.isNotEmpty;
  bool get isLoadingBudget => _loadingBudget;

  // New field for budget
  List<dynamic> _budgetSummary = [];
  List<dynamic> get budgetSummary => _budgetSummary;

  void _setError(String? m) { _error = m; notifyListeners(); }

  // ─── Tags ───────────────────────────────────────────────
  Future<void> loadTags() async {
    try {
      final resp = await _dio.get('/receipts/tags');
      final data = resp.data['data'] as List<dynamic>? ?? [];
      _tags = data.map((e) => ReceiptTag.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<ReceiptTag?> createTag(String name, String color, {double? monthlyBudget, String? icon}) async {
    try {
      final resp = await _dio.post('/receipts/tags', data: {
        'name': name, 
        'color': color,
        if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
        if (icon != null) 'icon': icon,
      });
      final tag = ReceiptTag.fromJson(resp.data['data']);
      _tags.add(tag);
      notifyListeners();
      return tag;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> updateTag(String id, {String? name, String? color, double? monthlyBudget, String? icon, bool? isArchived}) async {
    try {
      final resp = await _dio.put('/receipts/tags/$id', data: {
        if (name != null) 'name': name,
        if (color != null) 'color': color,
        if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
        if (icon != null) 'icon': icon,
        if (isArchived != null) 'isArchived': isArchived,
      });
      final tag = ReceiptTag.fromJson(resp.data['data']);
      final idx = _tags.indexWhere((t) => t.id == id);
      if (idx != -1) _tags[idx] = tag;
      // Update tags on receipts in memory
      _dayReceipts = _dayReceipts.map((r) => _copyWithUpdatedTag(r, tag)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteTag(String id) async {
    try {
      await _dio.delete('/receipts/tags/$id');
      _tags.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ─── Month Summary ─────────────────────────────────────
  Future<void> loadMonth(String month) async {
    _loadingMonth = true;
    _setError(null);
    try {
      final resp = await _dio.get('/receipts/month', queryParameters: {'month': month});
      final data = resp.data['data'] as List<dynamic>? ?? [];
      _monthSummary = data.map((e) => ReceiptDaySummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _setError(e.toString());
    }
    _loadingMonth = false;
    notifyListeners();
  }

  // ─── Budget Summary ─────────────────────────────────────────
  Future<void> loadBudgetSummary(String month) async {
    _loadingBudget = true;
    _setError(null);
    notifyListeners();
    try {
      final resp = await _dio.get('/budget/summary', queryParameters: {'month': month});
      final data = resp.data['data'] as List<dynamic>? ?? [];
      // To avoid circular dependency with a new model file inside the provider, 
      // we'll just store the raw JSON map or dynamically parse it in UI using the model.
      _budgetSummary = data;
    } catch (e) {
      _setError(e.toString());
    }
    _loadingBudget = false;
    notifyListeners();
  }

  // ─── Day Receipts ──────────────────────────────────────
  Future<void> loadDay(String date, {List<String>? tagIds}) async {
    _loadingDay = true;
    _setError(null);
    try {
      final resp = await _dio.get(
        '/receipts/day/$date',
        queryParameters: tagIds != null && tagIds.isNotEmpty
            ? {'tagIds': tagIds.join(',')}
            : null,
      );
      final data = resp.data['data'];
      final list = (data is Map && data['receipts'] is List)
          ? data['receipts'] as List
          : (data is List ? data : <dynamic>[]);
      _dayReceipts = list.map((e) => Receipt.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _setError(e.toString());
    }
    _loadingDay = false;
    notifyListeners();
  }

  // ─── AI OCR ─────────────────────────────────────────────
  Future<double?> scanReceiptWithAI(Uint8List bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes, 
          filename: fileName,
          contentType: MediaType('image', fileName.toLowerCase().endsWith('png') ? 'png' : 'jpeg'),
        ),
      });

      final resp = await _dio.post(
        '/ai/ocr',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (resp.data != null && resp.data['data'] != null) {
        final amountTotal = resp.data['data']['amountTotal'];
        if (amountTotal != null) {
          return double.tryParse(amountTotal.toString());
        }
      }
      return null;
    } catch (e) {
      debugPrint('OCR Error: $e');
      return null;
    }
  }

  // ─── CRUD ───────────────────────────────────────────────
  Future<Receipt?> createReceiptFromFile({
    required Uint8List bytes,
    required String fileName,
    required DateTime receiptDate,
    required double totalAmount,
    String? note,
    required List<String> tagIds,
  }) async {
    if (tagIds.isEmpty) {
      _setError('Please select at least one tag');
      return null;
    }
    _saving = true;
    _setError(null);
    notifyListeners();
    try {
      final imageUrl = await _uploadRepository.uploadImageBytes(bytes, fileName);
      final dateOnly = receiptDate.toIso8601String().split('T').first;
      final resp = await _dio.post('/receipts', data: {
        'imageUrl': imageUrl,
        'totalAmount': totalAmount,
        'receiptDate': dateOnly,
        if (note != null) 'note': note,
        'tagIds': tagIds,
      });
      final receipt = Receipt.fromJson(resp.data['data']);
      _dayReceipts.insert(0, receipt);
      _saving = false;
      notifyListeners();
      return receipt;
    } catch (e) {
      _setError(e.toString());
      _saving = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateReceipt({
    required String id,
    double? totalAmount,
    String? note,
    List<String>? tagIds,
  }) async {
    _saving = true;
    _setError(null);
    notifyListeners();
    try {
      final resp = await _dio.put('/receipts/$id', data: {
        if (totalAmount != null) 'totalAmount': totalAmount,
        if (note != null) 'note': note,
        if (tagIds != null) 'tagIds': tagIds,
      });
      final receipt = Receipt.fromJson(resp.data['data']);
      final idx = _dayReceipts.indexWhere((r) => r.id == id);
      if (idx != -1) _dayReceipts[idx] = receipt;
      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReceipt(String id) async {
    _saving = true;
    notifyListeners();
    try {
      await _dio.delete('/receipts/$id');
      _dayReceipts.removeWhere((r) => r.id == id);
      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Helper ─────────────────────────────────────────────
  Receipt _copyWithUpdatedTag(Receipt r, ReceiptTag updatedTag) {
    final updatedTags = r.tags.map((t) => t.id == updatedTag.id ? updatedTag : t).toList();
    return Receipt(
      id: r.id,
      imageUrl: r.imageUrl,
      totalAmount: r.totalAmount,
      note: r.note,
      receiptDate: r.receiptDate,
      tags: updatedTags,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }
}
