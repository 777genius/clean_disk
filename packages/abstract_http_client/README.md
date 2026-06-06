# abstract_http_client

Platform-agnostic HTTP client contracts and base implementations for Dart.

## Features

- **Platform-agnostic**: No `dart:io` dependencies, works on all platforms including web
- **Type-safe**: Full generic support with compile-time type checking
- **Extensible**: Pluggable interceptors, token stores, and retry policies
- **Modern Dart**: Uses sealed classes, pattern matching (Dart 3.4+)
- **OpenTelemetry-ready**: Built-in observability with W3C Trace Context support

## Installation

```yaml
dependencies:
  abstract_http_client: ^1.0.0
```

## Core Concepts

### HttpClient

The main interface for making HTTP requests:

```dart
abstract class HttpClient {
  Future<void> initialize();
  Future<void> dispose();

  Future<HttpResponse<T>> send<T>(
    HttpRequest request, {
    ResponseDecoder<T>? decoder,
    CancelToken? cancelToken,
  });

  // Convenience methods
  Future<HttpResponse<T>> get<T>(...);
  Future<HttpResponse<T>> post<T>(...);
  Future<HttpResponse<T>> put<T>(...);
  Future<HttpResponse<T>> patch<T>(...);
  Future<HttpResponse<T>> delete<T>(...);
}
```

### HttpBody

Sealed class for type-safe request bodies:

```dart
// JSON body
final body = HttpBody.json({'name': 'John', 'age': 30});

// Form data
final body = HttpBody.form({'username': 'john', 'password': 'secret'});

// Multipart (file upload)
final body = HttpBody.multipart(parts: [
  HttpPart.field(name: 'title', value: 'My Document'),
  HttpPart.bytes(
    name: 'file',
    filename: 'doc.pdf',
    bytes: fileBytes,
    contentType: 'application/pdf',
  ),
]);

// Binary data
final body = HttpBody.binary(bytes, contentType: 'application/octet-stream');

// Streaming
final body = HttpBody.stream(byteStream, contentLength: 1024);

// Lazy (computed on demand)
final body = HttpBody.lazy(() => computeExpensiveJson());
```

### Token Management

Built-in support for authentication tokens:

```dart
// Store tokens
final tokenStore = InMemoryTokenStore();
await tokenStore.saveTokens(TokenPair(
  accessToken: 'eyJ...',
  refreshToken: 'eyJ...',
  accessTokenExpiresAt: DateTime.now().add(Duration(hours: 1)),
));

// Implement refresh logic
class MyRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async {
    final response = await context.client.post<Map<String, dynamic>>(
      '/auth/refresh',
      body: HttpBody.json({
        'refresh_token': context.currentTokens?.refreshToken,
      }),
    );
    return TokenPair.fromJson(response.data!);
  }
}
```

### Retry Policies

Configurable retry behavior:

```dart
// Exponential backoff
final policy = ExponentialBackoffPolicy(
  maxAttempts: 3,
  initialDelay: Duration(milliseconds: 500),
  maxDelay: Duration(seconds: 30),
  multiplier: 2.0,
);

// Constant delay
final policy = ConstantDelayPolicy(
  maxAttempts: 5,
  delay: Duration(seconds: 1),
);

// Custom retry on specific errors
final policy = ExponentialBackoffPolicy(
  maxAttempts: 3,
  retryableErrorTypes: {
    HttpErrorType.connectionTimeout,
    HttpErrorType.serverError,
  },
);
```

### Observability

OpenTelemetry-compatible tracing:

```dart
class MyTraceObserver implements HttpTraceObserver {
  @override
  void onStart(HttpTrace trace) {
    print('Request started: ${trace.request.path}');
  }

  @override
  void onFinish(HttpTrace trace, HttpResponse response) {
    print('Request completed in ${trace.duration}');
  }

  @override
  void onError(HttpTrace trace, HttpError error) {
    print('Request failed: ${error.type}');
  }
}

// W3C Trace Context propagation
final context = TraceContext(
  traceId: '00000000000000000000000000000001',
  spanId: '0000000000000001',
);
final headers = W3CTraceContextPropagator().inject(context);
// headers['traceparent'] = '00-00000000000000000000000000000001-0000000000000001-01'
```

### Interceptors

Chain of responsibility pattern for request/response processing:

```dart
class LoggingInterceptor extends HttpInterceptor {
  @override
  Future<HttpRequest> onRequest(
    HttpRequest request,
    RequestHandler next,
  ) async {
    print('-> ${request.method.value} ${request.path}');
    return next(request);
  }

  @override
  Future<HttpResponse> onResponse(
    HttpResponse response,
    ResponseHandler next,
  ) async {
    print('<- ${response.statusCode}');
    return next(response);
  }
}
```

## Error Handling

All errors are typed via `HttpErrorType`:

```dart
try {
  final response = await client.get('/users');
} on HttpError catch (e) {
  switch (e.type) {
    case HttpErrorType.connectionTimeout:
      showError('Connection timed out');
    case HttpErrorType.unauthorized:
      redirectToLogin();
    case HttpErrorType.notFound:
      showError('Resource not found');
    case HttpErrorType.serverError:
      showError('Server error, please try again');
    default:
      showError('An error occurred: ${e.message}');
  }

  // Check if error is retryable
  if (e.isRetryable) {
    // Implement retry logic
  }
}
```

## License

MIT License - see LICENSE file for details.
