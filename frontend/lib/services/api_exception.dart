/// Any failure while talking to the backend, with a message that is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Per-field messages from the server's validation errors, e.g. {'email': 'Enter a valid email'}.
  final Map<String, String> fieldErrors;

  /// True when the server could not be reached at all (offline, wrong address, timeout).
  final bool isNetworkError;

  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}
