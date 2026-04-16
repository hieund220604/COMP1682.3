import 'package:flutter/material.dart';
import 'message_utils.dart';

/// Mixin to handle showing messages from API responses.
/// Simplified version — no Either/Failure, uses try-catch directly.
mixin MessageHandlerMixin on ChangeNotifier {
  String? _successMessage;
  String? _errorMessage;
  bool _isLoading = false;

  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSuccessMessage(String? message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Execute an async call with automatic loading/error handling.
  Future<bool> handleResult<T>(
    BuildContext? context,
    Future<T> Function() apiCall, {
    String? successMessage,
    bool showSuccessMessage = true,
    bool showErrorMessage = true,
    Function(T data)? onSuccess,
    Function(String error)? onError,
  }) async {
    setLoading(true);
    clearMessages();

    try {
      final data = await apiCall();

      if (successMessage != null) {
        setSuccessMessage(successMessage);
        if (context != null && showSuccessMessage) {
          context.showSuccess(successMessage);
        }
      }

      if (onSuccess != null) {
        onSuccess(data);
      }

      setLoading(false);
      return true;
    } catch (e) {
      final errorMsg = e.toString();
      setErrorMessage(errorMsg);

      if (context != null && showErrorMessage) {
        context.showError(errorMsg);
      }

      onError?.call(errorMsg);
      setLoading(false);
      return false;
    }
  }

  void showSuccessIfAvailable(BuildContext context) {
    if (_successMessage != null) {
      context.showSuccess(_successMessage!);
      _successMessage = null;
    }
  }

  void showErrorIfAvailable(BuildContext context) {
    if (_errorMessage != null) {
      context.showError(_errorMessage!);
      _errorMessage = null;
    }
  }
}

/// Helper function to execute API calls with automatic message handling.
Future<bool> executeWithMessage<T>(
  BuildContext context, {
  required Future<T> Function() apiCall,
  String? loadingMessage,
  String? successMessage,
  bool showSuccessMessage = true,
  bool showErrorMessage = true,
  Function(T data)? onSuccess,
  Function(String error)? onError,
}) async {
  if (loadingMessage != null) {
    context.showLoading(loadingMessage);
  }

  try {
    final data = await apiCall();

    if (loadingMessage != null) {
      context.hideMessage();
    }

    if (successMessage != null && showSuccessMessage) {
      context.showSuccess(successMessage);
    }
    onSuccess?.call(data);
    return true;
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
