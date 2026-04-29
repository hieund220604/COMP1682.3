import 'package:flutter/foundation.dart';
import '../../core/network/dio_client.dart';
import '../../models/bill_template.dart';
import '../../models/invoice.dart';

class BillTemplateProvider with ChangeNotifier {
  final DioClient _dio;

  BillTemplateProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  List<BillTemplate> _templates = [];
  BillTemplate? _selectedTemplate;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BillTemplate> get templates => _templates;
  List<BillTemplate> get activeTemplates =>
      _templates.where((t) => t.status != 'ARCHIVED').toList();
  BillTemplate? get selectedTemplate => _selectedTemplate;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? m) {
    _errorMessage = m;
    notifyListeners();
  }

  void clearError() => _setError(null);

  // ─── Load Templates ──────────────────────────────────────────────────────────
  Future<void> loadTemplates(String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.get('/groups/$groupId/bill-templates');
      _templates = (resp.data['data'] as List)
          .map((j) => BillTemplate.fromJson(j as Map<String, dynamic>))
          .toList();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // ─── Create Template ─────────────────────────────────────────────────────────
  Future<bool> createTemplate(
      String groupId, BillTemplateRequest data) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post(
        '/groups/$groupId/bill-templates',
        data: data.toJson(),
      );
      final template =
          BillTemplate.fromJson(resp.data['data'] as Map<String, dynamic>);
      _templates.insert(0, template);
      _selectedTemplate = template;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Update Template ─────────────────────────────────────────────────────────
  Future<bool> updateTemplate(
      String groupId, String templateId, Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.put(
        '/groups/$groupId/bill-templates/$templateId',
        data: data,
      );
      final updated =
          BillTemplate.fromJson(resp.data['data'] as Map<String, dynamic>);
      final idx = _templates.indexWhere((t) => t.id == templateId);
      if (idx != -1) _templates[idx] = updated;
      _selectedTemplate = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Pause / Resume / Archive ─────────────────────────────────────────────────
  Future<bool> pauseTemplate(String groupId, String templateId) async {
    return _patchStatus(groupId, templateId, 'pause');
  }

  Future<bool> resumeTemplate(String groupId, String templateId) async {
    return _patchStatus(groupId, templateId, 'resume');
  }

  Future<bool> archiveTemplate(String groupId, String templateId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.delete('/groups/$groupId/bill-templates/$templateId');
      _templates.removeWhere((t) => t.id == templateId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _patchStatus(
      String groupId, String templateId, String action) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.patch(
          '/groups/$groupId/bill-templates/$templateId/$action');
      await loadTemplates(groupId); // Reload to get updated status
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Generate Now ─────────────────────────────────────────────────────────────
  /// Manually trigger invoice generation without waiting for scheduler.
  Future<Invoice?> generateNow(String groupId, String templateId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post(
          '/groups/$groupId/bill-templates/$templateId/generate-now');
      _setLoading(false);
      return Invoice.fromJson(resp.data['data'] as Map<String, dynamic>);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // ─── Confirm DRAFT Invoice ────────────────────────────────────────────────────
  /// Confirm a DRAFT recurring invoice → SUBMITTED.
  /// After this, the normal PaymentRequest flow applies.
  Future<Invoice?> confirmDraft(String groupId, String invoiceId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post('/invoices/$groupId/$invoiceId/confirm');
      _setLoading(false);
      return Invoice.fromJson(resp.data['data'] as Map<String, dynamic>);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // ─── Update DRAFT Invoice Items ───────────────────────────────────────────────
  /// Update item amounts on a DRAFT invoice before confirming.
  /// Calls PUT /invoices/:groupId/:invoiceId with updated items and amountTotal.
  Future<bool> updateDraftItems(
    String groupId,
    String invoiceId, {
    required String title,
    required double amountTotal,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.put(
        '/invoices/$groupId/$invoiceId',
        data: {
          'title': title,
          'amountTotal': amountTotal,
          'items': items,
          if (note != null) 'note': note,
        },
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
}
