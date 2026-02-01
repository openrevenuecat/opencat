/// Typed errors for the OpenCat SDK.
class OpenCatError implements Exception {
  final OpenCatErrorType type;
  final String message;

  const OpenCatError._(this.type, this.message);

  factory OpenCatError.purchaseCancelled() =>
      const OpenCatError._(OpenCatErrorType.purchaseCancelled, 'Purchase was cancelled by the user.');

  factory OpenCatError.purchaseFailed(String detail) =>
      OpenCatError._(OpenCatErrorType.purchaseFailed, detail);

  factory OpenCatError.networkError(String detail) =>
      OpenCatError._(OpenCatErrorType.networkError, detail);

  factory OpenCatError.storeError(String detail) =>
      OpenCatError._(OpenCatErrorType.storeError, detail);

  factory OpenCatError.notConfigured() =>
      const OpenCatError._(OpenCatErrorType.notConfigured, 'OpenCat SDK is not configured. Call configureStandalone() or configureWithServer() first.');

  @override
  String toString() => 'OpenCatError(${type.name}): $message';
}

enum OpenCatErrorType {
  purchaseCancelled,
  purchaseFailed,
  networkError,
  storeError,
  notConfigured,
}
