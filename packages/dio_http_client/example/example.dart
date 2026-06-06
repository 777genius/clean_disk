// ignore_for_file: avoid_print, unused_local_variable

import 'package:dio_http_client/dio_http_client.dart';

/// Example showing how to use dio_http_client.
void main() async {
  await basicUsageExample();
  await authenticationExample();
  await cancellationExample();
}

/// Basic usage example
Future<void> basicUsageExample() async {
  print('--- Basic Usage ---');

  // Create client with configuration
  final client = DioHttpClient(
    config: DioHttpClientConfig(
      baseUrl: Uri.parse('https://jsonplaceholder.typicode.com'),
      enableLogging: true,
    ),
  );

  try {
    // Initialize client
    await client.initialize();
    print('Client initialized');

    // Make a GET request
    final response = await client.get<Map<String, dynamic>>(
      '/posts/1',
      decoder: (data) => data as Map<String, dynamic>,
    );

    print('Response status: ${response.statusCode}');
    print('Post title: ${response.data?['title']}');

    // Make a POST request
    final createResponse = await client.post<Map<String, dynamic>>(
      '/posts',
      body: const HttpBody.json({
        'title': 'My New Post',
        'body': 'This is the post body',
        'userId': 1,
      }),
      decoder: (data) => data as Map<String, dynamic>,
    );

    print('Created post ID: ${createResponse.data?['id']}');
  } on HttpError catch (e) {
    print('HTTP Error: ${e.type} - ${e.message}');
  } finally {
    // Clean up
    await client.dispose();
    print('Client disposed');
  }
}

/// Authentication example with token refresh
Future<void> authenticationExample() async {
  print('\n--- Authentication Example ---');

  // Create token store
  final tokenStore = InMemoryTokenStore();

  // Save initial tokens (normally from login response)
  await tokenStore.saveTokens(
    TokenPair(
      accessToken: 'initial_access_token',
      refreshToken: 'initial_refresh_token',
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );

  // Create client with auth support
  final client = DioHttpClient(
    config: DioHttpClientConfig(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenRefreshConfig: TokenRefreshConfig(
        refreshEndpoint: '/auth/refresh',
        onTokenRefreshed: (tokens) {
          print('Tokens refreshed successfully!');
        },
        onForceLogout: () {
          print('Session expired, redirecting to login...');
        },
      ),
    ),
    tokenStore: tokenStore,
    refreshDelegate: ExampleRefreshDelegate(),
  );

  print('Auth client created');
  print('Note: This is a demonstration - no real API calls are made');
}

/// Request cancellation example
Future<void> cancellationExample() async {
  print('\n--- Cancellation Example ---');

  final client = DioHttpClient(
    config: DioHttpClientConfig(
      baseUrl: Uri.parse('https://httpbin.org'),
    ),
  );

  await client.initialize();

  // Create a cancel token
  final cancelToken = CancelToken();

  try {
    // Start a slow request
    print('Starting slow request...');
    final future = client.get<dynamic>(
      '/delay/5', // 5 second delay
      cancelToken: cancelToken,
    );

    // Cancel after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      print('Cancelling request...');
      cancelToken.cancel('User cancelled the request');
    });

    await future;
    print('Request completed (should not reach here)');
  } on HttpError catch (e) {
    if (e.type == HttpErrorType.cancelled) {
      print('Request was cancelled: ${e.message}');
    } else {
      print('Error: ${e.type}');
    }
  } finally {
    await client.dispose();
  }

  // Auto-cancel with timeout
  print('\nUsing timeout cancel token:');
  final timeoutToken = CancelToken.timeout(const Duration(seconds: 2));
  print('Token will auto-cancel after 2 seconds');
}

/// Example refresh delegate implementation
class ExampleRefreshDelegate implements TokenRefreshDelegate {
  @override
  Future<TokenPair?> refresh(TokenRefreshContext context) async {
    print('Refreshing tokens...');

    // In a real app, this would call the refresh endpoint
    // final response = await context.client.post<Map<String, dynamic>>(
    //   '/auth/refresh',
    //   body: HttpBody.json({
    //     'refresh_token': context.currentTokens?.refreshToken,
    //   }),
    // );
    // return TokenPair.fromJson(response.data!);

    // For this example, return mock tokens
    return TokenPair(
      accessToken: 'new_access_token',
      refreshToken: 'new_refresh_token',
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
}
