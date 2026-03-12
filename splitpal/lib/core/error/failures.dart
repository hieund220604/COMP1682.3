import 'package:equatable/equatable.dart';

// Abstract Failure class
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({
    required this.message,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, statusCode];
}

// Concrete Failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
  });
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network connection failed',
  });
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Unauthorized access',
    super.statusCode = 401,
  });
}

class ValidationFailure extends Failure {
  final Map<String, dynamic>? errors;

  const ValidationFailure({
    required super.message,
    this.errors,
    super.statusCode = 400,
  });

  @override
  List<Object?> get props => [message, statusCode, errors];
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.statusCode = 404,
  });
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'Request timeout',
    super.statusCode = 408,
  });
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unknown error occurred',
  });
}

/// Returned when login succeeds but 2FA verification is required.
class TwoFactorRequiredFailure extends Failure {
  final String tempToken;

  const TwoFactorRequiredFailure({
    required this.tempToken,
    super.message = 'Two-factor authentication required',
  });

  @override
  List<Object?> get props => [message, statusCode, tempToken];
}
