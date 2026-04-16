import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/network/dio_client.dart';
import '../../core/error/exceptions.dart';

class UploadRepository {
  final DioClient _dioClient;

  UploadRepository({required DioClient dioClient}) : _dioClient = dioClient;

  Future<String> uploadImage(File file) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    return uploadImageBytes(bytes, fileName);
  }

  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('image', fileName.toLowerCase().endsWith('png') ? 'png' : 'jpeg'),
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
