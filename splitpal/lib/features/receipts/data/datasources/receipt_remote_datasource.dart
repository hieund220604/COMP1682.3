import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/receipt_model.dart';

abstract class ReceiptRemoteDataSource {
  Future<List<ReceiptDaySummaryModel>> getMonthSummary(String month);
  Future<List<ReceiptModel>> getDayReceipts(String date, {List<String>? tagIds});
  Future<ReceiptModel> createReceipt({
    required String imageUrl,
    required DateTime receiptDate,
    String? note,
    required List<String> tagIds,
  });
  Future<ReceiptModel> updateReceipt({
    required String id,
    String? note,
    List<String>? tagIds,
  });
  Future<void> deleteReceipt(String id);

  Future<List<ReceiptTagModel>> getTags();
  Future<ReceiptTagModel> createTag({required String name, required String color});
  Future<ReceiptTagModel> updateTag({required String id, String? name, String? color});
  Future<void> deleteTag(String id);
}

class ReceiptRemoteDataSourceImpl implements ReceiptRemoteDataSource {
  final DioClient dioClient;

  ReceiptRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<ReceiptDaySummaryModel>> getMonthSummary(String month) async {
    try {
      final response = await dioClient.get('/receipts/month', queryParameters: {'month': month});
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data.map((e) => ReceiptDaySummaryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<ReceiptModel>> getDayReceipts(String date, {List<String>? tagIds}) async {
    try {
      final response = await dioClient.get(
        '/receipts/day/$date',
        queryParameters: tagIds != null && tagIds.isNotEmpty ? {'tagIds': tagIds.join(',')} : null,
      );
      final data = response.data['data'];
      final list = (data is Map && data['receipts'] is List)
          ? data['receipts'] as List
          : (data is List ? data : <dynamic>[]);
      return list.map((e) => ReceiptModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<ReceiptModel> createReceipt({
    required String imageUrl,
    required DateTime receiptDate,
    String? note,
    required List<String> tagIds,
  }) async {
    try {
      // Send date-only (UTC-normalized) to avoid timezone shift on backend normalization
      final dateOnly = receiptDate.toIso8601String().split('T').first;
      final response = await dioClient.post(
        '/receipts',
        data: {
          'imageUrl': imageUrl,
          'receiptDate': dateOnly,
          if (note != null) 'note': note,
          'tagIds': tagIds,
        },
      );
      return ReceiptModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<ReceiptModel> updateReceipt({required String id, String? note, List<String>? tagIds}) async {
    try {
      final response = await dioClient.put(
        '/receipts/$id',
        data: {
          if (note != null) 'note': note,
          if (tagIds != null) 'tagIds': tagIds,
        },
      );
      return ReceiptModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteReceipt(String id) async {
    try {
      await dioClient.delete('/receipts/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<ReceiptTagModel>> getTags() async {
    try {
      final response = await dioClient.get('/receipts/tags');
      final data = response.data['data'] as List<dynamic>? ?? [];
      return data.map((e) => ReceiptTagModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<ReceiptTagModel> createTag({required String name, required String color}) async {
    try {
      final response = await dioClient.post('/receipts/tags', data: {'name': name, 'color': color});
      return ReceiptTagModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<ReceiptTagModel> updateTag({required String id, String? name, String? color}) async {
    try {
      final response = await dioClient.put(
        '/receipts/tags/$id',
        data: {
          if (name != null) 'name': name,
          if (color != null) 'color': color,
        },
      );
      return ReceiptTagModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteTag(String id) async {
    try {
      await dioClient.delete('/receipts/tags/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final message = error.response?.data?['message']?.toString() ??
          error.message ??
          'Request failed';
      return ServerException(message: message, statusCode: status);
    }
    return ServerException(message: error.toString(), statusCode: 500);
  }
}
