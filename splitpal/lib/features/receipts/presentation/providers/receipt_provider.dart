import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/upload_repository.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/usecases/create_receipt.dart';
import '../../domain/usecases/create_tag.dart';
import '../../domain/usecases/delete_receipt.dart';
import '../../domain/usecases/delete_tag.dart';
import '../../domain/usecases/get_day_receipts.dart';
import '../../domain/usecases/get_month_summary.dart';
import '../../domain/usecases/get_tags.dart';
import '../../domain/usecases/update_receipt.dart';
import '../../domain/usecases/update_tag.dart';

class ReceiptProvider with ChangeNotifier {
  final GetMonthSummary getMonthSummaryUseCase;
  final GetDayReceipts getDayReceiptsUseCase;
  final CreateReceipt createReceiptUseCase;
  final UpdateReceipt updateReceiptUseCase;
  final DeleteReceipt deleteReceiptUseCase;
  final GetTags getTagsUseCase;
  final CreateTag createTagUseCase;
  final UpdateTag updateTagUseCase;
  final DeleteTag deleteTagUseCase;
  final UploadRepository uploadRepository;

  ReceiptProvider({
    required this.getMonthSummaryUseCase,
    required this.getDayReceiptsUseCase,
    required this.createReceiptUseCase,
    required this.updateReceiptUseCase,
    required this.deleteReceiptUseCase,
    required this.getTagsUseCase,
    required this.createTagUseCase,
    required this.updateTagUseCase,
    required this.deleteTagUseCase,
    required this.uploadRepository,
  });

  // State
  bool _loadingMonth = false;
  bool _loadingDay = false;
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

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> loadTags() async {
    final result = await getTagsUseCase();
    result.fold(
      (failure) => _setError(_failureMessage(failure)),
      (data) {
        _tags = data;
        notifyListeners();
      },
    );
  }

  Future<void> loadMonth(String month) async {
    _loadingMonth = true;
    _setError(null);
    final result = await getMonthSummaryUseCase(month);
    result.fold(
      (failure) => _setError(_failureMessage(failure)),
      (data) {
        _monthSummary = data;
        _loadingMonth = false;
        notifyListeners();
      },
    );
    _loadingMonth = false;
    notifyListeners();
  }

  Future<void> loadDay(String date, {List<String>? tagIds}) async {
    _loadingDay = true;
    _setError(null);
    final result = await getDayReceiptsUseCase(date, tagIds: tagIds);
    result.fold(
      (failure) => _setError(_failureMessage(failure)),
      (data) {
        _dayReceipts = data;
        _loadingDay = false;
        notifyListeners();
      },
    );
    _loadingDay = false;
    notifyListeners();
  }

  Future<Receipt?> createReceiptFromFile({
    required File file,
    required DateTime receiptDate,
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
      final imageUrl = await uploadRepository.uploadImage(file);
      final result = await createReceiptUseCase(
        imageUrl: imageUrl,
        receiptDate: receiptDate,
        note: note,
        tagIds: tagIds,
      );
      return result.fold(
        (failure) {
          _setError(_failureMessage(failure));
          return null;
        },
        (receipt) {
          _dayReceipts.insert(0, receipt);
          _saving = false;
          notifyListeners();
          return receipt;
        },
      );
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateReceipt({
    required String id,
    String? note,
    List<String>? tagIds,
  }) async {
    _saving = true;
    _setError(null);
    notifyListeners();
    final result = await updateReceiptUseCase(id: id, note: note, tagIds: tagIds);
    return result.fold(
      (failure) {
        _setError(_failureMessage(failure));
        _saving = false;
        notifyListeners();
        return false;
      },
      (receipt) {
        final idx = _dayReceipts.indexWhere((r) => r.id == id);
        if (idx != -1) _dayReceipts[idx] = receipt;
        _saving = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> deleteReceipt(String id) async {
    _saving = true;
    notifyListeners();
    final result = await deleteReceiptUseCase(id);
    return result.fold(
      (failure) {
        _setError(_failureMessage(failure));
        _saving = false;
        notifyListeners();
        return false;
      },
      (_) {
        _dayReceipts.removeWhere((r) => r.id == id);
        _saving = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<ReceiptTag?> createTag(String name, String color) async {
    final result = await createTagUseCase(name: name, color: color);
    return result.fold(
      (failure) {
        _setError(_failureMessage(failure));
        return null;
      },
      (tag) {
        _tags.add(tag);
        notifyListeners();
        return tag;
      },
    );
  }

  Future<bool> updateTag(String id, {String? name, String? color}) async {
    final result = await updateTagUseCase(id: id, name: name, color: color);
    return result.fold(
      (failure) {
        _setError(_failureMessage(failure));
        return false;
      },
      (tag) {
        final idx = _tags.indexWhere((t) => t.id == id);
        if (idx != -1) _tags[idx] = tag;
        // Also update tags on receipts in memory
        _dayReceipts = _dayReceipts
            .map((r) => r.copyWithTags(tag))
            .toList();
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> deleteTag(String id) async {
    final result = await deleteTagUseCase(id);
    return result.fold(
      (failure) {
        _setError(_failureMessage(failure));
        return false;
      },
      (_) {
        _tags.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      },
    );
  }

  String _failureMessage(Failure failure) => failure.message;
}

extension _ReceiptCopy on Receipt {
  Receipt copyWithTags(ReceiptTag updatedTag) {
    final updatedTags = tags.map((t) => t.id == updatedTag.id ? updatedTag : t).toList();
    return Receipt(
      id: id,
      imageUrl: imageUrl,
      note: note,
      receiptDate: receiptDate,
      tags: updatedTags,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
