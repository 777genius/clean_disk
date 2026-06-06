import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Handler function type for processing HTTP requests.
typedef RequestHandler = FutureOr<void> Function(HttpRequest request);

/// A test HTTP server for E2E testing.
///
/// Provides a real HTTP server that can be configured with custom handlers
/// for different endpoints. Supports simulating delays, errors, and various
/// response scenarios.
///
/// Example:
/// ```dart
/// final server = TestHttpServer();
/// await server.start();
///
/// server.addHandler('/users', (request) async {
///   request.response
///     ..statusCode = HttpStatus.ok
///     ..headers.contentType = ContentType.json
///     ..write(jsonEncode({'id': 1, 'name': 'John'}));
///   await request.response.close();
/// });
///
/// // Use server.baseUrl in your HTTP client
/// // ...
///
/// await server.stop();
/// ```
class TestHttpServer {
  HttpServer? _server;
  final Map<String, RequestHandler> _handlers = {};
  final List<HttpRequest> _requests = [];
  RequestHandler? _defaultHandler;

  /// The base URL of the server (e.g., http://127.0.0.1:8080).
  Uri? get baseUrl => _server != null
      ? Uri.parse('http://127.0.0.1:${_server!.port}')
      : null;

  /// The port the server is listening on.
  int? get port => _server?.port;

  /// All requests received by the server.
  List<HttpRequest> get requests => List.unmodifiable(_requests);

  /// The last request received by the server.
  HttpRequest? get lastRequest => _requests.isNotEmpty ? _requests.last : null;

  /// Clears recorded requests.
  void clearRequests() => _requests.clear();

  /// Starts the server on a random available port.
  Future<Uri> start() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    _server!.listen(_handleRequest);
    return baseUrl!;
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _handlers.clear();
    _requests.clear();
    _defaultHandler = null;
  }

  /// Adds a handler for a specific path.
  ///
  /// The path should start with '/'. Method matching can be done inside
  /// the handler.
  void addHandler(String path, RequestHandler handler) {
    _handlers[path] = handler;
  }

  /// Removes a handler for a specific path.
  void removeHandler(String path) {
    _handlers.remove(path);
  }

  /// Sets a default handler for unmatched paths.
  void setDefaultHandler(RequestHandler handler) {
    _defaultHandler = handler;
  }

  /// Handles incoming HTTP requests.
  Future<void> _handleRequest(HttpRequest request) async {
    _requests.add(request);

    final path = request.uri.path;
    final handler = _handlers[path] ?? _defaultHandler;

    if (handler != null) {
      try {
        await handler(request);
      } catch (e) {
        if (!request.response.headers.persistentConnection) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Handler error: $e');
          await request.response.close();
        }
      }
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found: $path');
      await request.response.close();
    }
  }

  // Convenience methods for common responses

  /// Creates a JSON response handler.
  static RequestHandler jsonResponse(
    Object? data, {
    int statusCode = HttpStatus.ok,
    Map<String, String>? headers,
    Duration? delay,
  }) {
    return (request) async {
      if (delay != null) {
        await Future<void>.delayed(delay);
      }

      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.json;

      if (headers != null) {
        headers.forEach((key, value) {
          request.response.headers.add(key, value);
        });
      }

      if (data != null) {
        request.response.write(jsonEncode(data));
      }

      await request.response.close();
    };
  }

  /// Creates an error response handler.
  static RequestHandler errorResponse(
    int statusCode, {
    String? message,
    Object? body,
    Duration? delay,
  }) {
    return (request) async {
      if (delay != null) {
        await Future<void>.delayed(delay);
      }

      request.response.statusCode = statusCode;

      if (body != null) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
      } else if (message != null) {
        request.response.write(message);
      }

      await request.response.close();
    };
  }

  /// Creates a handler that delays response indefinitely (for timeout testing).
  static RequestHandler delayedResponse(Duration delay, {int? statusCode}) {
    return (request) async {
      await Future<void>.delayed(delay);

      request.response.statusCode = statusCode ?? HttpStatus.ok;
      await request.response.close();
    };
  }

  /// Creates a handler that never responds (for testing cancellation).
  static RequestHandler neverRespond() {
    return (request) async {
      // Never close the response - simulates a hanging connection
      await Completer<void>().future;
    };
  }

  /// Creates a handler that echoes the request body.
  static RequestHandler echoRequest() {
    return (request) async {
      final body = await utf8.decodeStream(request);

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'method': request.method,
          'path': request.uri.path,
          'query': request.uri.queryParameters,
          'headers': _headersToMap(request.headers),
          'body': body.isNotEmpty ? body : null,
        }));

      await request.response.close();
    };
  }

  /// Creates a handler that validates Authorization header.
  static RequestHandler requireAuth({
    required String expectedToken,
    RequestHandler? onAuthorized,
    int unauthorizedStatus = HttpStatus.unauthorized,
  }) {
    return (request) async {
      final authHeader = request.headers.value('Authorization');

      if (authHeader == null || !authHeader.contains(expectedToken)) {
        request.response
          ..statusCode = unauthorizedStatus
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'Unauthorized'}));
        await request.response.close();
        return;
      }

      if (onAuthorized != null) {
        await onAuthorized(request);
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'authenticated': true}));
        await request.response.close();
      }
    };
  }

  /// Creates a handler that returns different responses on each call.
  static RequestHandler sequence(List<RequestHandler> handlers) {
    var index = 0;
    return (request) async {
      if (index < handlers.length) {
        await handlers[index++](request);
      } else {
        // Repeat last handler
        await handlers.last(request);
      }
    };
  }

  /// Creates a counter that tracks how many times a path was called.
  static (RequestHandler, int Function()) counted(RequestHandler handler) {
    var count = 0;
    return (
      (request) async {
        count++;
        await handler(request);
      },
      () => count,
    );
  }

  static Map<String, String> _headersToMap(HttpHeaders headers) {
    final map = <String, String>{};
    headers.forEach((name, values) {
      map[name] = values.join(', ');
    });
    return map;
  }
}

/// Extension for easier response writing.
extension HttpResponseExtension on HttpResponse {
  /// Writes JSON data and closes the response.
  Future<void> json(Object? data, {int statusCode = HttpStatus.ok}) async {
    this.statusCode = statusCode;
    headers.contentType = ContentType.json;
    if (data != null) {
      write(jsonEncode(data));
    }
    await close();
  }

  /// Writes text and closes the response.
  Future<void> text(String text, {int statusCode = HttpStatus.ok}) async {
    this.statusCode = statusCode;
    headers.contentType = ContentType.text;
    write(text);
    await close();
  }

  /// Sends an error response.
  Future<void> error(int statusCode, {String? message, Object? body}) async {
    this.statusCode = statusCode;
    if (body != null) {
      headers.contentType = ContentType.json;
      write(jsonEncode(body));
    } else if (message != null) {
      write(message);
    }
    await close();
  }
}

/// Extension for reading request body.
extension HttpRequestExtension on HttpRequest {
  /// Reads the request body as a string.
  Future<String> readAsString() async {
    return utf8.decodeStream(this);
  }

  /// Reads the request body as JSON.
  Future<dynamic> readAsJson() async {
    final body = await readAsString();
    return body.isNotEmpty ? jsonDecode(body) : null;
  }

  /// Gets a query parameter value.
  String? queryParam(String name) => uri.queryParameters[name];

  /// Gets a header value.
  String? header(String name) => headers.value(name);
}
