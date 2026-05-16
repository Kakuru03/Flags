import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// A widget that catches errors in its child widget tree
/// and displays a user-friendly error screen instead of a white screen
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? fallbackMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackMessage,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  String errorMessage = '';
  Object? errorObject;

  @override
  void initState() {
    super.initState();
    // Set up Flutter error reporter for the widget tree
    ErrorWidget.builder = (errorDetails) {
      return _buildErrorWidget(errorDetails);
    };
  }

void didCatchError(Object error, StackTrace stackTrace) {
    // Log error for debugging
    if (kDebugMode) {
      print('ErrorBoundary caught error: $error');
      print('Stack trace: $stackTrace');
    }

    setState(() {
      hasError = true;
      errorObject = error;
      errorMessage = _getUserFriendlyMessage(error);
    });
  }

  String _getUserFriendlyMessage(Object error) {
    String message = widget.fallbackMessage ?? 'Something went wrong';

    if (error is Exception) {
      String errorStr = error.toString().toLowerCase();

      if (errorStr.contains('firebase')) {
        if (errorStr.contains('network') || errorStr.contains('socket')) {
          return 'Unable to connect. Please check your internet connection.';
        }
        if (errorStr.contains('permission') || errorStr.contains('denied')) {
          return 'Permission denied. Please check app permissions.';
        }
        if (errorStr.contains('not-found') || errorStr.contains('404')) {
          return 'Service temporarily unavailable. Please try again later.';
        }
      }

      if (errorStr.contains('null') || errorStr.contains('no such method')) {
        return 'An internal error occurred. Please restart the app.';
      }

      if (errorStr.contains('socket') || errorStr.contains('connect')) {
        return 'Unable to connect. Please check your internet connection.';
      }

      if (errorStr.contains('timeout')) {
        return 'Request timed out. Please try again.';
      }
    }

    return message;
  }

  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.fallbackMessage ?? 'Please try restarting the app',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Try to recover by resetting state
                    setState(() {
                      hasError = false;
                      errorMessage = '';
                      errorObject = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorDetails.exceptionAsString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return _buildErrorWidget(FlutterErrorDetails(
        exception: errorObject ?? Exception(errorMessage),
        stack: StackTrace.current,
      ));
    }

    return widget.child;
  }

  /// Method to manually trigger error state (can be called from anywhere)
  void reportError(Object error) {
    didCatchError(error, StackTrace.current);
  }

  /// Method to reset error state and try again
  void reset() {
    setState(() {
      hasError = false;
      errorMessage = '';
      errorObject = null;
    });
  }
}

/// A simpler error boundary that wraps a single widget
/// and shows a fallback on error
class SafeWidget extends StatelessWidget {
  final Widget Function(BuildContext context, Object? error) errorBuilder;
  final Widget Function(BuildContext context) builder;

  const SafeWidget({
    super.key,
    required this.errorBuilder,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('SafeWidget caught error: $e');
        print('Stack trace: $stackTrace');
      }
      return errorBuilder(context, e);
    }
  }
}

/// Extension to make any widget tree have error boundaries
extension ErrorBoundaryExtension on Widget {
  Widget withErrorBoundary({String? message}) {
    return ErrorBoundary(
      fallbackMessage: message,
      child: this,
    );
  }
}
