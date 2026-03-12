import 'package:flutter/material.dart';
import '../error/failures.dart';
import 'message_utils.dart';

/// Mixin to handle showing messages from API responses
/// Use this in your providers/controllers to automatically show messages
mixin MessageHandlerMixin on ChangeNotifier {
  // Internal state
  String? _successMessage;
  String? _errorMessage;
  bool _isLoading = false;

  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set success message
  void setSuccessMessage(String? message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  /// Set error message
  void setErrorMessage(String? message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  /// Clear all messages
  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Handle Either<Failure, Success> result and show appropriate message
  /// Returns true if successful, false if failed
  Future<bool> handleResult<T>(
    BuildContext? context,
    Future<dynamic> Function() apiCall, {
    String? successMessage,
    bool showSuccessMessage = true,
    bool showErrorMessage = true,
    Function(T data)? onSuccess,
    Function(String error)? onError,
  }) async {
    setLoading(true);
    clearMessages();

    try {
      final result = await apiCall();

      // Handle Either pattern (dartz)
      if (result.runtimeType.toString().contains('Right')) {
        // Success case
        final data = result.fold((l) => null, (r) => r);
        
        if (successMessage != null) {
          setSuccessMessage(successMessage);
          if (context != null && showSuccessMessage) {
            context.showSuccess(successMessage);
          }
        }

        if (onSuccess != null && data != null) {
          onSuccess(data);
        }

        setLoading(false);
        return true;
      } else {
        // Failure case
        final failure = result.fold((l) => l, (r) => null);
        final errorMsg = _getErrorMessage(failure);
        
        setErrorMessage(errorMsg);
        if (context != null && showErrorMessage) {
          context.showError(errorMsg);
        }

        if (onError != null) {
          onError(errorMsg);
        }

        setLoading(false);
        return false;
      }
    } catch (e) {
      final errorMsg = e.toString();
      setErrorMessage(errorMsg);
      
      if (context != null && showErrorMessage) {
        context.showError(errorMsg);
      }

      if (onError != null) {
        onError(errorMsg);
      }

      setLoading(false);
      return false;
    }
  }

  /// Extract error message from Failure
  String _getErrorMessage(dynamic failure) {
    if (failure == null) return 'An unknown error occurred';
    
    if (failure is ServerFailure) {
      return failure.message;
    } else if (failure is NetworkFailure) {
      return failure.message;
    } else if (failure is ValidationFailure) {
      return failure.message;
    } else if (failure is UnauthorizedFailure) {
      return failure.message;
    } else if (failure is NotFoundFailure) {
      return failure.message;
    } else if (failure is CacheFailure) {
      return failure.message;
    } else if (failure is UnknownFailure) {
      return failure.message;
    }
    
    return failure.toString();
  }

  /// Show automatic success message if available
  void showSuccessIfAvailable(BuildContext context) {
    if (_successMessage != null) {
      context.showSuccess(_successMessage!);
      _successMessage = null;
    }
  }

  /// Show automatic error message if available
  void showErrorIfAvailable(BuildContext context) {
    if (_errorMessage != null) {
      context.showError(_errorMessage!);
      _errorMessage = null;
    }
  }
}

/// Helper function to execute API calls with automatic message handling
Future<bool> executeWithMessage<T>(
  BuildContext context, {
  required Future<dynamic> Function() apiCall,
  String? loadingMessage,
  String? successMessage,
  bool showSuccessMessage = true,
  bool showErrorMessage = true,
  Function(T data)? onSuccess,
  Function(String error)? onError,
}) async {
  // Show loading
  if (loadingMessage != null) {
    context.showLoading(loadingMessage);
  }

  try {
    final result = await apiCall();

    // Hide loading
    if (loadingMessage != null) {
      context.hideMessage();
    }

    // Handle Either pattern
    return result.fold(
      (failure) {
        final errorMsg = _extractErrorMessage(failure);
        if (showErrorMessage) {
          context.showError(errorMsg);
        }
        onError?.call(errorMsg);
        return false;
      },
      (data) {
        if (successMessage != null && showSuccessMessage) {
          context.showSuccess(successMessage);
        }
        if (onSuccess != null) {
          onSuccess(data as T);
        }
        return true;
      },
    );
  } catch (e) {
    if (loadingMessage != null) {
      context.hideMessage();
    }
    
    final errorMsg = e.toString();
    if (showErrorMessage) {
      context.showError(errorMsg);
    }
    onError?.call(errorMsg);
    return false;
  }
}

/// Extract error message from failure
String _extractErrorMessage(dynamic failure) {
  if (failure is ServerFailure) {
    return failure.message;
  } else if (failure is NetworkFailure) {
    return failure.message;
  } else if (failure is ValidationFailure) {
    return failure.message;
  } else if (failure is UnauthorizedFailure) {
    return failure.message;
  } else if (failure is NotFoundFailure) {
    return failure.message;
  } else if (failure is CacheFailure) {
    return failure.message;
  } else if (failure is UnknownFailure) {
    return failure.message;
  }
  
  return 'An unknown error occurred';
}
