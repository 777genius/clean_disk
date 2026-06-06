// ignore_for_file: avoid_print, unused_local_variable

import 'dart:typed_data';

import 'package:abstract_http_client/abstract_http_client.dart';

/// Example showing the core concepts of abstract_http_client.
///
/// This package provides interfaces and base implementations.
/// For a concrete implementation, see `dio_http_client`.
void main() {
  // Example: Creating request bodies
  bodyExamples();

  // Example: Token management
  tokenExamples();

  // Example: Retry policies
  retryPolicyExamples();

  // Example: Error handling
  errorHandlingExamples();
}

void bodyExamples() {
  print('--- Body Examples ---');

  // JSON body
  const jsonBody = HttpBody.json({'name': 'John', 'age': 30});
  print('JSON body content type: ${jsonBody.contentType}');

  // Form data
  const formBody = HttpBody.form({'username': 'john', 'password': 'secret'});
  print('Form body content type: ${formBody.contentType}');

  // Multipart (file upload)
  final multipartBody = HttpBody.multipart(
    parts: [
      const HttpPart.field(name: 'title', value: 'My Document'),
      HttpPart.bytes(
        name: 'file',
        filename: 'doc.txt',
        bytes: Uint8List.fromList([72, 101, 108, 108, 111]), // "Hello"
        contentType: 'text/plain',
      ),
    ],
  );
  print('Multipart body created');

  // Empty body
  const emptyBody = HttpBody.empty();
  print('Empty body content type: ${emptyBody.contentType}');
}

void tokenExamples() {
  print('\n--- Token Examples ---');

  // Create token pair
  final tokens = TokenPair(
    accessToken: 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...',
    refreshToken: 'dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...',
    accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
  );

  print('Access token expired: ${tokens.isAccessTokenExpired}');
  print('Refresh token expired: ${tokens.isRefreshTokenExpired}');

  // In-memory token store
  final tokenStore = InMemoryTokenStore();
  print('Token store created');
}

void retryPolicyExamples() {
  print('\n--- Retry Policy Examples ---');

  // Exponential backoff
  const exponential = ExponentialBackoffPolicy(
    
  );
  print('Exponential: delay for attempt 1 = ${exponential.getDelay(1)}');
  print('Exponential: delay for attempt 2 = ${exponential.getDelay(2)}');
  print('Exponential: delay for attempt 3 = ${exponential.getDelay(3)}');

  // Constant delay
  const constant = ConstantDelayPolicy(
    maxAttempts: 5,
  );
  print('Constant: delay = ${constant.getDelay(1)}');

  // No retry
  const noRetry = NoRetryPolicy();
  print('NoRetry policy created');
}

void errorHandlingExamples() {
  print('\n--- Error Handling Examples ---');

  // Create an error
  const error = HttpError(
    type: HttpErrorType.connectionTimeout,
    request: HttpRequest(
      method: HttpMethod.get,
      path: '/users',
    ),
    message: 'Connection timed out after 30 seconds',
  );

  print('Error type: ${error.type}');
  print('Is retryable: ${error.isRetryable}');

  // Pattern matching on error types
  final message = switch (error.type) {
    HttpErrorType.connectionTimeout => 'Connection timed out',
    HttpErrorType.unauthorized => 'Please login again',
    HttpErrorType.notFound => 'Resource not found',
    HttpErrorType.serverError => 'Server error, please try again',
    _ => 'An error occurred',
  };
  print('User message: $message');
}
