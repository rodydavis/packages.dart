/// Base exception for AppReview package
class AppReviewException implements Exception {
  final String message;

  AppReviewException(this.message);

  @override
  String toString() => 'AppReviewException: $message';
}

/// Thrown when the review request fails
class AppReviewRequestFailedException extends AppReviewException {
  AppReviewRequestFailedException(String message) : super(message);
}

/// Thrown when the review is unavailable
class AppReviewUnavailableException extends AppReviewException {
  AppReviewUnavailableException(String message) : super(message);
}

/// Thrown when the store listing cannot be opened
class AppReviewStoreListingFailedException extends AppReviewException {
  AppReviewStoreListingFailedException(String message) : super(message);
}
