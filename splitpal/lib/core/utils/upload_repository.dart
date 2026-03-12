import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/error/exceptions.dart';

class UploadRepository {
  final DioClient _dioClient;

  UploadRepository({required DioClient dioClient}) : _dioClient = dioClient;

  Future<String> uploadImage(File file) async {
    try {
      final String fileName = file.path.split('/').last;
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _dioClient.post(
        '/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['url'];
      } else {
        throw ServerException(
          message: response.data['error']?['message'] ?? 'Upload failed',
          statusCode: response.statusCode ?? 500,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Upload failed: $e', statusCode: 500);
    }
  }
}
