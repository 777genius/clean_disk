/// Dio-based implementation of abstract_http_client.
///
/// This library provides a production-ready HTTP client implementation
/// using Dio as the underlying HTTP engine.
///
/// ## Features
///
/// - Full implementation of `HttpClient` interface
/// - Automatic token refresh with queue management
/// - Configurable retry policy with exponential backoff
/// - Pretty request/response logging
/// - Distributed tracing support
/// - Easy cancellation with `CancelToken`
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:dio_http_client/dio_http_client.dart';
///
/// final client = DioHttpClient(
///   config: DioHttpClientConfig(
///     baseUrl: Uri.parse('https://api.example.com'),
///     connectTimeout: Duration(seconds: 30),
///     enableLogging: true,
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
///
/// await client.dispose();
/// ```
///
/// ## With Authentication
///
/// ```dart
/// final tokenStore = InMemoryTokenStore();
///
/// final client = DioHttpClient(
///   config: DioHttpClientConfig(
///     baseUrl: Uri.parse('https://api.example.com'),
///     tokenRefreshConfig: TokenRefreshConfig(
///       refreshEndpoint: '/auth/refresh',
///       onForceLogout: () => print('User logged out'),
///     ),
///   ),
///   tokenStore: tokenStore,
///   refreshDelegate: MyRefreshDelegate(),
/// );
/// ```
library;

// Re-export abstract_http_client for convenience
export 'package:abstract_http_client/abstract_http_client.dart';

// Client
export 'src/client/dio_http_client.dart';
export 'src/client/dio_http_client_config.dart';

// Interceptors
export 'src/interceptors/dio_auth_interceptor.dart';
export 'src/interceptors/dio_interceptor_adapter.dart';
export 'src/interceptors/dio_logging_interceptor.dart';
export 'src/interceptors/dio_retry_interceptor.dart';
export 'src/interceptors/dio_token_refresh_interceptor.dart';

// Mappers (for advanced use cases)
export 'src/mappers/body_encoder.dart';
export 'src/mappers/error_mapper.dart';
export 'src/mappers/request_mapper.dart';
export 'src/mappers/response_mapper.dart';

// Utils
export 'src/utils/cancel_token_adapter.dart';
