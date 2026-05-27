import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// Custom exception classes
// ============================================================================

/// Base app exception
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  AppException(
      this.message, {
        this.code,
        this.originalError,
        this.stackTrace,
      });

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Authentication-related exceptions
class AuthException extends AppException {
  final bool isUserDisabled;
  final bool isInvalidCredentials;
  final bool isAccountBanned;
  final bool isEmailNotVerified;
  final bool isWeakPassword;
  final bool isEmailAlreadyInUse;

  AuthException(
      super.message, {
        this.isUserDisabled = false,
        this.isInvalidCredentials = false,
        this.isAccountBanned = false,
        this.isEmailNotVerified = false,
        this.isWeakPassword = false,
        this.isEmailAlreadyInUse = false,
        super.code,
        super.originalError,
        super.stackTrace,
      });
}

/// Firestore/database exceptions
class DatabaseException extends AppException {
  final bool isPermissionDenied;
  final bool isNotFound;
  final bool isAlreadyExists;

  DatabaseException(
      super.message, {
        this.isPermissionDenied = false,
        this.isNotFound = false,
        this.isAlreadyExists = false,
        super.code,
        super.originalError,
        super.stackTrace,
      });
}

/// Storage exceptions
class StorageException extends AppException {
  final bool isObjectNotFound;
  final bool isUnauthorized;

  StorageException(
      super.message, {
        this.isObjectNotFound = false,
        this.isUnauthorized = false,
        super.code,
        super.originalError,
        super.stackTrace,
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
        super.stackTrace,
      });
}

/// Permission exceptions (device level)
class PermissionException extends AppException {
  PermissionException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Unknown/unexpected exceptions
class UnknownException extends AppException {
  UnknownException(super.message, {super.code, super.originalError, super.stackTrace});
}

// ============================================================================
// Error severity & status
// ============================================================================

enum ErrorSeverity {
  low,     // Non-critical (e.g., validation error)
  medium,  // Moderate (e.g., failed to load some data)
  high,    // Critical for feature (e.g., failed to save, but app works)
  critical, // App cannot proceed (e.g., auth required)
}

extension ErrorSeverityExtension on ErrorSeverity {
  bool get isLow => this == ErrorSeverity.low;
  bool get isMedium => this == ErrorSeverity.medium;
  bool get isHigh => this == ErrorSeverity.high;
  bool get isCritical => this == ErrorSeverity.critical;
}

enum ErrorStatus {
  initial,
  loading,
  success,
  error,
}

extension ErrorStatusExtension on ErrorStatus {
  bool get isInitial => this == ErrorStatus.initial;
  bool get isLoading => this == ErrorStatus.loading;
  bool get isSuccess => this == ErrorStatus.success;
  bool get isError => this == ErrorStatus.error;
}

// ============================================================================
// AppError model with analytics support
// ============================================================================

class AppError {
  final String message;
  final String? code;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Object? originalError;
  final StackTrace? stackTrace;
  String? context; // Not final so we can attach context later

  AppError({
    required this.message,
    this.code,
    this.severity = ErrorSeverity.medium,
    DateTime? timestamp,
    this.originalError,
    this.stackTrace,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AppError.fromException(
      Object error, {
        ErrorSeverity severity = ErrorSeverity.medium,
        String? context,
        StackTrace? stackTrace,
      }) {
    return AppError(
      message: _extractMessage(error),
      severity: severity,
      originalError: error,
      stackTrace: stackTrace ?? (error is Error ? error.stackTrace : null),
      context: context,
      code: error is AppException ? error.code : null,
    );
  }

  static String _extractMessage(Object error) {
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return error.message ?? error.code;
    if (error is FirebaseException) return error.message ?? error.code;
    return error.toString();
  }

  /// Convert to a map for analytics / crash reporting
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'code': code,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'originalError': originalError?.toString(),
      'stackTrace': stackTrace?.toString(),
    };
  }

  @override
  String toString() => 'AppError[$context]: $message (${severity.name})';
}

// ============================================================================
// Improved Result class (monadic)
// ============================================================================

class Result<T> {
  final T? _value;
  final AppError? _error;

  Result._(this._value, this._error);

  factory Result.success(T value) => Result._(value, null);
  factory Result.failure(AppError error) => Result._(null, error);
  factory Result.failureFromException(Object error, {String? context}) =>
      Result._(null, AppError.fromException(error, context: context));

  bool get isSuccess => _error == null;
  bool get isFailure => _error != null;

  T get data {
    if (!isSuccess) throw StateError('Cannot access data on a failed Result');
    return _value as T;
  }

  AppError get error {
    if (isSuccess) throw StateError('Cannot access error on a successful Result');
    return _error!;
  }

  // Transform the value if success, otherwise propagate error
  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      try {
        return Result.success(mapper(_value as T));
      } catch (e, st) {
        return Result.failure(AppError.fromException(e, stackTrace: st));
      }
    }
    return Result.failure(_error!);
  }

  // FlatMap for chaining async-like operations
  Result<R> flatMap<R>(Result<R> Function(T) mapper) {
    if (isSuccess) {
      try {
        return mapper(_value as T);
      } catch (e, st) {
        return Result.failure(AppError.fromException(e, stackTrace: st));
      }
    }
    return Result.failure(_error!);
  }

  // Get value or fallback
  T getOrElse(T defaultValue) => isSuccess ? _value as T : defaultValue;

  // Execute onSuccess or onError callbacks
  void fold({
    void Function(T)? onSuccess,
    void Function(AppError)? onError,
  }) {
    if (isSuccess && onSuccess != null) {
      onSuccess(_value as T);
    } else if (isFailure && onError != null) {
      onError(_error!);
    }
  }

  // Convert to nullable value (returns null on failure)
  T? getOrNull() => isSuccess ? _value : null;
}

// ============================================================================
// Async error handling utilities
// ============================================================================

/// Wrap a Future with Result type
Future<Result<T>> runCatching<T>(
    Future<T> Function() block, {
      String? context,
    }) async {
  try {
    final value = await block();
    return Result.success(value);
  } catch (e, st) {
    final error = AppError.fromException(e, context: context, stackTrace: st);
    AppErrorHandler.handle(error);
    return Result.failure(error);
  }
}

/// Retry a failing async operation
Future<Result<T>> retry<T>(
    Future<Result<T>> Function() operation, {
      int maxRetries = 3,
      Duration delay = const Duration(seconds: 1),
      bool Function(AppError)? shouldRetry,
    }) async {
  int attempts = 0;
  while (attempts < maxRetries) {
    final result = await operation();
    if (result.isSuccess) return result;
    attempts++;
    if (attempts < maxRetries) {
      final error = result.error;
      if (shouldRetry != null && !shouldRetry(error)) {
        return result;
      }
      await Future.delayed(delay * attempts); // exponential backoff
    } else {
      return result;
    }
  }
  return Result.failure(AppError(message: 'Max retries exceeded'));
}

// ============================================================================
// Firebase error mapping
// ============================================================================

/// Convert Firebase Auth exception to AuthException
AuthException mapAuthException(FirebaseAuthException e, {StackTrace? stackTrace}) {
  final code = e.code;
  switch (code) {
    case 'user-disabled':
      return AuthException('This account has been disabled.', code: code, isUserDisabled: true, originalError: e, stackTrace: stackTrace);
    case 'invalid-email':
    case 'wrong-password':
    case 'user-not-found':
      return AuthException('Invalid email or password.', code: code, isInvalidCredentials: true, originalError: e, stackTrace: stackTrace);
    case 'too-many-requests':
      return AuthException('Too many failed attempts. Please try again later.', code: code, originalError: e, stackTrace: stackTrace);
    case 'email-already-in-use':
      return AuthException('Email already in use.', code: code, isEmailAlreadyInUse: true, originalError: e, stackTrace: stackTrace);
    case 'weak-password':
      return AuthException('Password is too weak.', code: code, isWeakPassword: true, originalError: e, stackTrace: stackTrace);
    case 'network-request-failed':
      return AuthException('Network error. Check your connection.', code: code, originalError: e, stackTrace: stackTrace);
    default:
      return AuthException(e.message ?? 'Authentication error.', code: code, originalError: e, stackTrace: stackTrace);
  }
}

/// Convert Firestore exception to DatabaseException
DatabaseException mapFirestoreException(FirebaseException e, {StackTrace? stackTrace}) {
  final code = e.code;
  switch (code) {
    case 'permission-denied':
      return DatabaseException('Permission denied. You may not be logged in or have insufficient privileges.',
          code: code, isPermissionDenied: true, originalError: e, stackTrace: stackTrace);
    case 'not-found':
      return DatabaseException('Document not found.', code: code, isNotFound: true, originalError: e, stackTrace: stackTrace);
    case 'already-exists':
      return DatabaseException('Document already exists.', code: code, isAlreadyExists: true, originalError: e, stackTrace: stackTrace);
    case 'unavailable':
    case 'deadline-exceeded':
      return DatabaseException('Service unavailable. Please try again.', code: code, originalError: e, stackTrace: stackTrace);
    default:
      return DatabaseException(e.message ?? 'Database error.', code: code, originalError: e, stackTrace: stackTrace);
  }
}

/// Convert Storage exception to StorageException
StorageException mapStorageException(FirebaseException e, {StackTrace? stackTrace}) {
  final code = e.code;
  switch (code) {
    case 'object-not-found':
      return StorageException('File not found.', code: code, isObjectNotFound: true, originalError: e, stackTrace: stackTrace);
    case 'unauthorized':
      return StorageException('Permission denied.', code: code, isUnauthorized: true, originalError: e, stackTrace: stackTrace);
    default:
      return StorageException(e.message ?? 'Storage error.', code: code, originalError: e, stackTrace: stackTrace);
  }
}

/// Top-level mapping for any Firebase error
AppException mapFirebaseError(Object error, {StackTrace? stackTrace}) {
  if (error is FirebaseAuthException) return mapAuthException(error, stackTrace: stackTrace);
  if (error is FirebaseException) {
    if (error.plugin == 'firebase_storage') return mapStorageException(error, stackTrace: stackTrace);
    return mapFirestoreException(error, stackTrace: stackTrace);
  }
  return UnknownException(error.toString(), originalError: error, stackTrace: stackTrace);
}

// ============================================================================
// Improved error handler with logging & crash reporting
// ============================================================================

class AppErrorHandler {
  /// Callback for external crash reporting (e.g., Sentry, Firebase Crashlytics)
  static void Function(AppError)? onErrorReport;

  /// Initialize with your crash reporting service
  static void init({void Function(AppError)? reportCallback}) {
    onErrorReport = reportCallback;
  }

  /// Handle an error – log, report, and optionally show user message
  static void handle(
      Object error, {
        String? context,
        ErrorSeverity severity = ErrorSeverity.medium,
        bool reportToCrashService = true,
      }) {
    final appError = error is AppError
        ? AppError(
      message: error.message,
      code: error.code,
      severity: error.severity,
      timestamp: error.timestamp,
      originalError: error.originalError,
      stackTrace: error.stackTrace,
      context: error.context ?? context,
    )
        : AppError.fromException(error, severity: severity, context: context);

    // Log to console (development) or analytics (production)
    if (kDebugMode) {
      dev.log(
        'AppError in ${appError.context ?? 'unknown'}',
        name: 'ErrorHandler',
        error: appError.originalError ?? appError,
        stackTrace: appError.stackTrace,
      );
    } else {
      // In production, you might send to your analytics service
      // AnalyticsService.logError(appError.toMap());
    }

    // Send to external crash reporting service
    if (reportToCrashService && onErrorReport != null) {
      onErrorReport!(appError);
    }
  }

  /// Convert error to a user-friendly message with optional localization
  static String toUserMessage(Object error, {String? Function(String key)? t}) {
    // Helper with null-safe translation
    String _tr(String key, String defaultMsg) => t?.call(key) ?? defaultMsg;

    if (error is NetworkException || (error.toString().toLowerCase().contains('network'))) {
      return _tr('error.network', 'Unable to connect. Please check your internet connection.');
    }
    if (error is AuthException) {
      if (error.isAccountBanned) return _tr('error.account_banned', 'Account suspended. Contact support.');
      if (error.isInvalidCredentials) return _tr('error.invalid_credentials', 'Invalid email or password.');
      if (error.isUserDisabled) return _tr('error.user_disabled', 'Account disabled. Contact support.');
      if (error.isEmailNotVerified) return _tr('error.email_not_verified', 'Please verify your email first.');
      if (error.isWeakPassword) return _tr('error.weak_password', 'Password is too weak.');
      if (error.isEmailAlreadyInUse) return _tr('error.email_in_use', 'Email already registered.');
      return _tr('error.auth_general', 'Authentication failed. Please try again.');
    }
    if (error is DatabaseException) {
      if (error.isPermissionDenied) {
        return _tr('error.permission_denied', 'You don\'t have permission for this action.');
      }
      return _tr('error.database', 'Unable to save or load data. Please try again.');
    }
    if (error is StorageException) {
      if (error.isObjectNotFound) return _tr('error.file_not_found', 'File not found.');
      if (error.isUnauthorized) return _tr('error.storage_unauthorized', 'Permission denied to access storage.');
      return _tr('error.storage', 'Unable to upload/download file.');
    }
    if (error is PermissionException) {
      return _tr('error.permission', 'Please grant required permission in settings.');
    }
    if (error is ValidationException) {
      return error.message;
    }
    // Generic fallback
    return _tr('error.generic', 'Something went wrong. Please try again.');
  }

  /// Determine if error can be retried automatically
  static bool canRetry(Object error) {
    if (error is NetworkException) return true;
    if (error is DatabaseException) {
      // Permission denied cannot be retried without user action
      return !error.isPermissionDenied;
    }
    final str = error.toString().toLowerCase();
    return str.contains('network') ||
        str.contains('timeout') ||
        str.contains('unavailable');
  }

  /// Check if error is authentication related
  static bool isAuthError(Object error) => error is AuthException;
  static bool isNetworkError(Object error) => error is NetworkException || error.toString().toLowerCase().contains('network');
  static bool isPermissionError(Object error) =>
      (error is DatabaseException && error.isPermissionDenied) ||
          (error is StorageException && error.isUnauthorized) ||
          error is PermissionException;
}

// ============================================================================
// Extension methods for easy error handling on objects and futures
// ============================================================================

extension ObjectErrorExtension on Object {
  String toUserMessage({String? Function(String key)? t}) => AppErrorHandler.toUserMessage(this, t: t);
  bool get isNetworkError => AppErrorHandler.isNetworkError(this);
  bool get isAuthError => AppErrorHandler.isAuthError(this);
  bool get isPermissionError => AppErrorHandler.isPermissionError(this);
  bool get canRetry => AppErrorHandler.canRetry(this);
}

/// Extension on Future<T> to convert to Result<T> easily
extension FutureResultExtension<T> on Future<T> {
  Future<Result<T>> toResult({String? context}) => runCatching(() => this, context: context);
}