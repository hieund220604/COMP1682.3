// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
  success: json['success'] as bool,
  message: json['message'] as String,
  data: json['data'] == null
      ? null
      : AuthData.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorData.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
      'error': instance.error,
    };

AuthData _$AuthDataFromJson(Map<String, dynamic> json) => AuthData(
  token: json['token'] as String?,
  resetToken: json['resetToken'] as String?,
  user: json['user'] == null
      ? null
      : UserModel.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthDataToJson(AuthData instance) => <String, dynamic>{
  'token': instance.token,
  'resetToken': instance.resetToken,
  'user': instance.user,
};

ErrorData _$ErrorDataFromJson(Map<String, dynamic> json) => ErrorData(
  message: json['message'] as String,
  code: json['code'] as String?,
);

Map<String, dynamic> _$ErrorDataToJson(ErrorData instance) => <String, dynamic>{
  'message': instance.message,
  'code': instance.code,
};
