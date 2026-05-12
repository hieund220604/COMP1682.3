import 'package:flutter/foundation.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import 'report_models.dart';

export 'report_models.dart';

class ReportProvider extends ChangeNotifier {
  final DioClient _dio;

  ReportProvider({required DioClient dio}) : _dio = dio;

  // ─── Monthly report state ────────────────────────────────────────────────
  MonthlyReport? _monthlyReport;
  bool _isMonthlyLoading = false;
  String? _monthlyError;
  String _selectedMonth = '';

  // ─── Yearly report state ─────────────────────────────────────────────────
  YearlyReport? _yearlyReport;
  bool _isYearlyLoading = false;
  String? _yearlyError;
  int _selectedYear = DateTime.now().year;

  // ─── Getters ─────────────────────────────────────────────────────────────
  MonthlyReport? get monthlyReport => _monthlyReport;
  bool get isMonthlyLoading => _isMonthlyLoading;
  String? get monthlyError => _monthlyError;
  String get selectedMonth => _selectedMonth;

  YearlyReport? get yearlyReport => _yearlyReport;
  bool get isYearlyLoading => _isYearlyLoading;
  String? get yearlyError => _yearlyError;
  int get selectedYear => _selectedYear;

  // ─── Actions ─────────────────────────────────────────────────────────────

  /// Fetch monthly financial report for the given month (YYYY-MM).
  Future<void> fetchMonthlyReport(String month) async {
    _selectedMonth = month;
    _isMonthlyLoading = true;
    _monthlyError = null;
    notifyListeners();

    try {
      final res = await _dio.get(
        '${ApiConstants.reportMonthly}?month=$month',
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        _monthlyReport = MonthlyReport.fromJson(data);
      }
    } catch (e) {
      _monthlyError = e.toString();
    } finally {
      _isMonthlyLoading = false;
      notifyListeners();
    }
  }

  /// Fetch yearly financial report.
  Future<void> fetchYearlyReport(int year) async {
    _selectedYear = year;
    _isYearlyLoading = true;
    _yearlyError = null;
    notifyListeners();

    try {
      final res = await _dio.get(
        '${ApiConstants.reportYearly}?year=$year',
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        _yearlyReport = YearlyReport.fromJson(data);
      }
    } catch (e) {
      _yearlyError = e.toString();
    } finally {
      _isYearlyLoading = false;
      notifyListeners();
    }
  }

  /// Change month and re-fetch.
  Future<void> setMonth(String month) => fetchMonthlyReport(month);

  /// Change year and re-fetch.
  Future<void> setYear(int year) => fetchYearlyReport(year);
}
