/// Platform-agnostic HTTP client contracts and base implementations.
///
/// This library provides the foundation for building HTTP clients with:
/// - Clean abstractions for testability
/// - Interceptor-based request/response processing
/// - Token refresh and authentication support
/// - Retry policies with exponential backoff
/// - Circuit breaker for fault tolerance
/// - Distributed tracing support (OpenTelemetry-compatible)
///
/// ## Getting Started
///
/// Use this library with an implementation package like `dio_http_client`:
///
/// ```dart
/// import 'package:abstract_http_client/abstract_http_client.dart';
/// import 'package:dio_http_client/dio_http_client.dart';
///
/// final client = DioHttpClient(
///   config: HttpClientConfig(
///     baseUrl: Uri.parse('https://api.example.com'),
///     defaultHeaders: {'X-Api-Key': 'secret'},
///   ),
/// );
///
/// await client.initialize();
///
/// final response = await client.get<Map<String, dynamic>>(
///   '/users/123',
///   decoder: (data) => data as Map<String, dynamic>,
/// );
///
/// print(response.data);
/// ```
library;

// Auth
export 'src/auth/token_pair.dart';
export 'src/auth/token_refresh_delegate.dart';
export 'src/auth/token_store.dart';

// Client
export 'src/client/http_client.dart';
export 'src/client/http_client_config.dart';

// Interceptors
export 'src/interceptors/http_interceptor.dart';
export 'src/interceptors/interceptor_chain.dart';

// Models
export 'src/models/http_body.dart';
export 'src/models/http_error.dart';
export 'src/models/http_method.dart';
export 'src/models/http_request.dart';
export 'src/models/http_response.dart';

// Observability
export 'src/observability/http_trace.dart';
export 'src/observability/http_trace_observer.dart';
export 'src/observability/trace_context.dart';

// Resilience & Retry
export 'src/resilience/circuit_breaker.dart';
export 'src/retry/retry_policy.dart';

// Utils
export 'src/utils/cancel_token.dart';
