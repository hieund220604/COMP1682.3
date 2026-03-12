import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  final bool success;
  final String message;
  final AuthData? data;
  final ErrorData? error;

  AuthResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory AuthResponse.fromJson(dynamic json) {
    // Accept raw String or Map defensively to avoid "String is not a subtype of int of index".
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        json = <String, dynamic>{'success': false, 'message': json};
      }
    }
    if (json is! Map<String, dynamic>) {
      json = <String, dynamic>{'success': false, 'message': 'Invalid response'};
    }

    final rawError = json['error'];
    return AuthResponse(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      data: json['data'] is Map<String, dynamic>
          ? AuthData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: rawError == null
          ? null
          : rawError is Map<String, dynamic>
              ? ErrorData.fromJson(rawError)
              : ErrorData(message: rawError.toString()),
    );
  }

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class AuthData {
  final String? token;
  final String? resetToken;
  final String? tempToken;
  final bool requires2FA;
  final UserModel? user;

  AuthData({
    this.token,
    this.resetToken,
    this.tempToken,
    this.requires2FA = false,
    this.user,
  });

  factory AuthData.fromJson(dynamic json) {
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        json = {};
      }
    }
    if (json is! Map<String, dynamic>) json = <String, dynamic>{};

    final rawUser = json['user'];
    Map<String, dynamic>? userJson;
    String? token = json['token'] as String?;

    if (rawUser is Map<String, dynamic>) {
      // Backend currently nests user + token inside `data.user`
      if (rawUser['user'] is Map<String, dynamic>) {
        userJson = rawUser['user'] as Map<String, dynamic>;
      } else {
        userJson = rawUser;
      }
      token ??= rawUser['token'] as String?;
    }

    return AuthData(
      token: token,
      resetToken: json['resetToken'] as String?,
      tempToken: json['tempToken'] as String?,
      requires2FA: json['requires2FA'] == true,
      user: userJson != null ? UserModel.fromJson(userJson) : null,
    );
  }

  Map<String, dynamic> toJson() => _$AuthDataToJson(this);
}

@JsonSerializable()
class ErrorData {
  final String message;
  final String? code;

  ErrorData({
    required this.message,
    this.code,
  });

  factory ErrorData.fromJson(Map<String, dynamic> json) =>
      _$ErrorDataFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorDataToJson(this);
}
