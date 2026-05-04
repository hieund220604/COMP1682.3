import 'package:flutter/foundation.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import 'forecast_models.dart';

export 'forecast_models.dart';

class ForecastProvider extends ChangeNotifier {
  final DioClient _dio;

  ForecastProvider({required DioClient dio}) : _dio = dio;

  // ─── Summary state (injected from dashboard or fetched) ──────────────────
  ForecastSummary? _summary;
  bool _isLoading = false;
  String? _error;

  // ─── Full forecast state ─────────────────────────────────────────────────
  List<DailyForecastModel> _dailyForecasts = [];
  List<ForecastEventModel> _events = [];
  SpendingInsight? _spendingInsight;
  List<SmartTip> _smartTips = [];
  bool _isFullLoading = false;
  String? _fullError;
  int _horizonDays = 7;
  int _spendingDays = 7;

  // ─── Getters ─────────────────────────────────────────────────────────────
  ForecastSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<DailyForecastModel> get dailyForecasts => _dailyForecasts;
  List<ForecastEventModel> get events => _events;
  SpendingInsight? get spendingInsight => _spendingInsight;
  List<SmartTip> get smartTips => _smartTips;
  bool get isFullLoading => _isFullLoading;
  String? get fullError => _fullError;
  int get horizonDays => _horizonDays;
  int get spendingDays => _spendingDays;

  // ─── Actions ─────────────────────────────────────────────────────────────

  /// Lightweight 7-day summary for the dashboard card.
  Future<void> fetchSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _dio.get(ApiConstants.forecastSummary);
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) _summary = ForecastSummary.fromJson(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Full forecast with daily breakdown — used by CashflowForecastPage.
  Future<void> fetchFull({int days = 7, int? spendingDays}) async {
    _horizonDays = days;
    if (spendingDays != null) _spendingDays = spendingDays;
    _isFullLoading = true;
    _fullError = null;
    notifyListeners();
    try {
      final res = await _dio.get(
        '${ApiConstants.forecast}?days=$days&spendingDays=$_spendingDays',
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        final summaryJson = data['summary'] as Map<String, dynamic>?;
        if (summaryJson != null) {
          _summary = ForecastSummary.fromJson(summaryJson);
        }
        _dailyForecasts = (data['dailyForecasts'] as List<dynamic>? ?? [])
            .map((e) => DailyForecastModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _events = (data['events'] as List<dynamic>? ?? [])
            .map((e) => ForecastEventModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // New insight data
        final spendingJson = data['spendingInsight'] as Map<String, dynamic>?;
        if (spendingJson != null) {
          _spendingInsight = SpendingInsight.fromJson(spendingJson);
        }
        _smartTips = (data['smartTips'] as List<dynamic>? ?? [])
            .map((e) => SmartTip.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _fullError = e.toString();
    } finally {
      _isFullLoading = false;
      notifyListeners();
    }
  }

  /// Change horizon and re-fetch full data.
  Future<void> setHorizon(int days) => fetchFull(days: days);

  /// Change spending analysis period and re-fetch.
  Future<void> setSpendingDays(int days) =>
      fetchFull(days: _horizonDays, spendingDays: days);

  /// Populate summary from dashboard response (avoids extra HTTP round-trip).
  void injectFromDashboard(Map<String, dynamic>? json) {
    if (json == null) return;
    _summary = ForecastSummary.fromJson(json);
    notifyListeners();
  }
}
