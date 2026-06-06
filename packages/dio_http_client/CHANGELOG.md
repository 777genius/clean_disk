# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-03

### Added

- Initial release
- `DioHttpClient` implementing `HttpClient` interface
- `DioHttpClientConfig` with Dio-specific options:
  - Response type configuration
  - List format for query parameters
  - Granular logging control
- Interceptors:
  - `DioAuthInterceptor` for automatic Authorization header
  - `DioTokenRefreshInterceptor` with queue management
  - `DioRetryInterceptor` supporting all `RetryPolicy` implementations
  - `DioLoggingInterceptor` with pretty printing
- Mappers:
  - `DioRequestMapper` (HttpRequest -> Dio Options)
  - `DioResponseMapper` (Dio Response -> HttpResponse)
  - `DioErrorMapper` (DioException -> HttpError)
  - `DioBodyEncoder` (HttpBody -> Dio-compatible format)
- `CancelTokenAdapter` for seamless CancelToken integration
