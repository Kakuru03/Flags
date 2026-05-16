import 'package:flutter/foundation.dart';

/// Custom exception classes for the app
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Authentication-related exceptions
class AuthException extends AppException {
  final bool isUserDisabled;
  final bool isInvalidCredentials;
  final bool isAccountBanned;

  AuthException(
    super.message, {
    this.isUserDisabled = false,
    this.isInvalidCredentials = false,
    this.isAccountBanned = false,
    super.code,
    super.originalError,
  });
}

/// Firestore/database exceptions
class DatabaseException extends AppException {
  DatabaseException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Storage exceptions
class StorageException extends AppException {
  StorageException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException(
    super.message, {
    this.fieldErrors,
    super.code,
    super.originalError,
  });
}

/// Permission exceptions
class PermissionException extends AppException {
  PermissionException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Error status for managing UI states
enum ErrorStatus {
  initial,
  loading,
  success,
  error,
}

/// Extension methods for ErrorStatus
extension ErrorStatusExtension on ErrorStatus {
  bool get isInitial => this == ErrorStatus.initial;
  bool get isLoading => this == ErrorStatus.loading;
  bool get isSuccess => this == ErrorStatus.success;
  bool get isError => this == ErrorStatus.error;

  String get displayName {
    switch (this) {
      case ErrorStatus.initial:
        return 'Initial';
      case ErrorStatus.loading:
        return 'Loading';
      case ErrorStatus.success:
        return 'Success';
      case ErrorStatus.error:
        return 'Error';
    }
  }
}

/// Error model for passing error data
class AppError {
  final String message;
  final String? code;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Object? originalError;
  final StackTrace? stackTrace;

  AppError({
    required this.message,
    this.code,
    this.severity = ErrorSeverity.medium,
    DateTime? timestamp,
    this.originalError,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AppError.fromException(
    Object error, {
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    return AppError(
      message: _extractMessage(error),
      severity: severity,
      originalError: error,
stackTrace: error is Error ? error.stackTrace : null,
    );
  }

  static String _extractMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  String toString() => 'AppError: $message (${severity.name})';
}

/// Result class for handling operation results
class Result<T> {
  final T? data;
  final AppError? error;
  final bool isSuccess;

  Result._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory Result.success(T data) {
    return Result._(data: data, isSuccess: true);
  }

  factory Result.failure(AppError error) {
    return Result._(error: error, isSuccess: false);
  }

  factory Result.failureFromException(Object error) {
    return Result._(
      error: AppError.fromException(error),
      isSuccess: false,
    );
  }

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    }
    return failure(error ?? AppError(message: 'Unknown error'));
  }
}

/// Error handler that can be used throughout the app
class AppErrorHandler {
  /// Handle an error and log it
  static void handle(
    Object error, {
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    // Log the error
    if (kDebugMode) {
      print('Error in $context: $error');
    }

    // In production, you could send to error reporting service
    // Example: sentry.captureException(error, context: context);
  }

  /// Convert error to user-friendly message
  static String toUserMessage(Object error) {
    String errorStr = error.toString().toLowerCase();

    if (error is NetworkException || errorStr.contains('network')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    if (error is AuthException) {
      if (error.isAccountBanned) {
        return 'This account has been suspended. Please contact support for assistance.';
      }
      if (error.isInvalidCredentials) {
        return 'Invalid email or password. Please try again.';
      }
      if (error.isUserDisabled) {
        return 'This account has been disabled. Please contact support.';
      }
      return 'Authentication failed. Please try again.';
    }

    if (error is DatabaseException || errorStr.contains('firestore')) {
      return 'Unable to save data. Please try again.';
    }

    if (error is StorageException || errorStr.contains('storage')) {
      return 'Unable to upload file. Please try again.';
    }

    if (error is PermissionException || errorStr.contains('permission')) {
      return 'Permission denied. Please check app permissions in settings.';
    }

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    if (errorStr.contains('null') || errorStr.contains('no such method')) {
      return 'An internal error occurred. Please restart the app.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Check if error is network-related
  static bool isNetworkError(Object error) {
    String errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('connect') ||
        errorStr.contains('timeout') ||
        error is NetworkException;
  }

  /// Check if error is auth-related
  static bool isAuthError(Object error) {
    return error is AuthException;
  }

  /// Check if error can be retried
  static bool canRetry(Object error) {
    return isNetworkError(error);
  }
}

/// Extension to easily handle errors
extension ObjectExtension on Object {
  /// Convert to user-friendly message
  String toUserMessage() => AppErrorHandler.toUserMessage(this);

  /// Check if this is a network error
  bool get isNetworkError => AppErrorHandler.isNetworkError(this);

  /// Check if this is an auth error
  bool get isAuthError => AppErrorHandler.isAuthError(this);

  /// Check if can retry
  bool get canRetry => AppErrorHandler.canRetry(this);
}
