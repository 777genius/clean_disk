# dio_http_client

Production-ready HTTP client implementation using [Dio](https://pub.dev/packages/dio).

Implements the `abstract_http_client` interfaces with full support for:
- Automatic token refresh with queue management
- Configurable retry policies
- Pretty request/response logging
- Distributed tracing support
- Easy request cancellation

## Installation

```yaml
dependencies:
  dio_http_client: ^1.0.0
```

## Quick Start

```dart
import 'package:dio_http_client/dio_http_client.dart';

// Create client
final client = DioHttpClient(
  config: DioHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com'),
    connectTimeout: Duration(seconds: 30),
    enableLogging: true,
  ),
);

// Initialize
await client.initialize();

// Make requests
final response = await client.get<Map<String, dynamic>>(
  '/users/123',
  decoder: (data) => data as Map<String, dynamic>,
);

print(response.data);

// Clean up
await client.dispose();
```

## Configuration

### Basic Configuration

```dart
final config = DioHttpClientConfig(
  baseUrl: Uri.parse('https://api.example.com'),
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(seconds: 30),
  sendTimeout: Duration(seconds: 30),
  defaultHeaders: {
    'Accept': 'application/json',
    'X-App-Version': '1.0.0',
  },
  followRedirects: true,
  maxRedirects: 5,
);
```

### With Authentication

```dart
final tokenStore = InMemoryTokenStore();

final client = DioHttpClient(
  config: DioHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com'),
    tokenRefreshConfig: TokenRefreshConfig(
      refreshEndpoint: '/auth/refresh',
      onTokenRefreshed: (tokens) {
        print('Tokens refreshed!');
      },
      onForceLogout: () {
        // Navigate to login
        print('Session expired, please login again');
      },
    ),
  ),
  tokenStore: tokenStore,
  refreshDelegate: MyRefreshDelegate(),
);

// Save tokens after login
await tokenStore.saveTokens(TokenPair(
  accessToken: loginResponse.accessToken,
  refreshToken: loginResponse.refreshToken,
));
```

### With Retry Policy

```dart
final client = DioHttpClient(
  config: DioHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com'),
    retryPolicy: ExponentialBackoffPolicy(
      maxAttempts: 3,
      initialDelay: Duration(milliseconds: 500),
    ),
  ),
);
```

### With Observability

```dart
final client = DioHttpClient(
  config: DioHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com'),
  ),
  traceObserver: CompositeTraceObserver([
    PrintingTraceObserver(),
    MyDatadogObserver(),
    MyOpenTelemetryObserver(),
  ]),
);
```

## Token Refresh

The `DioTokenRefreshInterceptor` handles automatic token refresh:

1. Detects 401 Unauthorized responses
2. Queues concurrent requests while refreshing
3. Retries original request with new token
4. Calls `onForceLogout` if refresh fails

```dart
class MyRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async {
    try {
      final response = await context.client.post<Map<String, dynamic>>(
        '/auth/refresh',
        body: HttpBody.json({
          'refresh_token': context.currentTokens?.refreshToken,
        }),
      );

      return TokenPair.fromJson(response.data!);
    } on HttpError catch (e) {
      if (e.type == HttpErrorType.unauthorized) {
        // Refresh token is invalid, user needs to re-login
        return null;
      }
      rethrow;
    }
  }
}
```

## Request Cancellation

```dart
final cancelToken = CancelToken();

// Start request
final future = client.get('/slow-endpoint', cancelToken: cancelToken);

// Cancel after 5 seconds
Future.delayed(Duration(seconds: 5), () {
  cancelToken.cancel('User navigated away');
});

try {
  final response = await future;
} on HttpError catch (e) {
  if (e.type == HttpErrorType.cancelled) {
    print('Request was cancelled');
  }
}

// Auto-cancel with timeout
final timeoutToken = CancelToken.timeout(Duration(seconds: 10));
final response = await client.get('/endpoint', cancelToken: timeoutToken);
```

## Logging

Enable pretty logging for debugging:

```dart
final client = DioHttpClient(
  config: DioHttpClientConfig(
    baseUrl: Uri.parse('https://api.example.com'),
    enableLogging: true,
    logRequestBody: true,
    logResponseBody: true,
    logRequestHeaders: true,
    logResponseHeaders: false, // Don't log response headers
  ),
);
```

Output:
```
+-- REQUEST --+
| GET https://api.example.com/users/123
| Headers:
|   Authorization: ***
|   Accept: application/json
+-------------+

+-- RESPONSE --+
| 200 OK
| Body:
|   {
|     "id": 123,
|     "name": "John Doe"
|   }
+--------------+
```

## Advanced Usage

### Access Dio Instance

```dart
final client = DioHttpClient(config: config);
await client.initialize();

// Access underlying Dio for advanced configuration
client.dio.options.extra['custom'] = 'value';
```

### Custom Interceptors

```dart
// Add Dio interceptors directly
client.dio.interceptors.add(MyCustomDioInterceptor());

// Or use abstract HttpInterceptor (via adapter)
final client = DioHttpClient(
  config: config,
  interceptors: [
    MyLoggingInterceptor(),
    MyAnalyticsInterceptor(),
  ],
);
```

## API Reference

### DioHttpClient

| Property | Description |
|----------|-------------|
| `config` | Client configuration |
| `dio` | Underlying Dio instance |
| `isInitialized` | Whether client is initialized |

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize client and interceptors |
| `dispose()` | Clean up resources |
| `send<T>()` | Send HTTP request |
| `get<T>()` | Convenience method for GET |
| `post<T>()` | Convenience method for POST |
| `put<T>()` | Convenience method for PUT |
| `patch<T>()` | Convenience method for PATCH |
| `delete<T>()` | Convenience method for DELETE |

### DioHttpClientConfig

Extends `HttpClientConfig` with Dio-specific options:

| Property | Default | Description |
|----------|---------|-------------|
| `contentType` | null | Default content type |
| `responseType` | json | Response type (json, stream, plain, bytes) |
| `listFormat` | multi | Query string list format |
| `logRequestBody` | true | Log request bodies |
| `logResponseBody` | true | Log response bodies |
| `logRequestHeaders` | true | Log request headers |
| `logResponseHeaders` | true | Log response headers |

## License

MIT License - see LICENSE file for details.
