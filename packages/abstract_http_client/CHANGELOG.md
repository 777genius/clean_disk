# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-03

### Added

- Initial release
- `HttpClient` abstract interface
- `HttpRequest` and `HttpResponse` models
- `HttpBody` sealed class with support for:
  - JSON bodies
  - Form data
  - Multipart uploads
  - Binary data
  - Streaming bodies
  - Lazy (computed) bodies
- `HttpError` with comprehensive error types
- `HttpMethod` enum with safety and idempotency helpers
- Token management:
  - `TokenPair` model
  - `TokenStore` interface with `InMemoryTokenStore` implementation
  - `TokenRefreshDelegate` interface
  - `TokenRefreshConfig` for configurable refresh behavior
- Retry policies:
  - `RetryPolicy` interface
  - `ExponentialBackoffPolicy`
  - `ConstantDelayPolicy`
  - `NoRetryPolicy`
- Interceptors:
  - `HttpInterceptor` base class
  - `InterceptorChain` implementation
- Observability:
  - `HttpTrace` for request tracing
  - `HttpTraceObserver` interface
  - `TraceContext` for W3C Trace Context
  - `TraceContextPropagator` for distributed tracing
- `CancelToken` for request cancellation
- `CircuitBreakerPolicy` interface (reserved for future implementation)
