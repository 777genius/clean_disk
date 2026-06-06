/// HTTP request methods.
///
/// Represents the standard HTTP methods as defined in
/// [RFC 7231](https://tools.ietf.org/html/rfc7231#section-4).
enum HttpMethod {
  /// GET method for retrieving resources.
  get('GET'),

  /// POST method for creating resources.
  post('POST'),

  /// PUT method for replacing resources.
  put('PUT'),

  /// PATCH method for partial updates.
  patch('PATCH'),

  /// DELETE method for removing resources.
  delete('DELETE'),

  /// HEAD method for retrieving headers only.
  head('HEAD'),

  /// OPTIONS method for retrieving allowed methods.
  options('OPTIONS')
  ;

  const HttpMethod(this.value);

  /// The HTTP method string value.
  final String value;

  /// Whether this method is considered safe (no side effects).
  ///
  /// Safe methods are GET, HEAD, and OPTIONS.
  bool get isSafe => switch (this) {
    HttpMethod.get || HttpMethod.head || HttpMethod.options => true,
    _ => false,
  };

  /// Whether this method is idempotent.
  ///
  /// Idempotent methods are GET, HEAD, OPTIONS, PUT, and DELETE.
  bool get isIdempotent => switch (this) {
    HttpMethod.get ||
    HttpMethod.head ||
    HttpMethod.options ||
    HttpMethod.put ||
    HttpMethod.delete => true,
    _ => false,
  };

  /// Parse a string to [HttpMethod].
  ///
  /// Throws [ArgumentError] if the string doesn't match any method.
  static HttpMethod parse(String value) {
    final upperValue = value.toUpperCase();
    for (final method in HttpMethod.values) {
      if (method.value == upperValue) {
        return method;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown HTTP method');
  }

  /// Try to parse a string to [HttpMethod].
  ///
  /// Returns `null` if the string doesn't match any method.
  static HttpMethod? tryParse(String value) {
    final upperValue = value.toUpperCase();
    for (final method in HttpMethod.values) {
      if (method.value == upperValue) {
        return method;
      }
    }
    return null;
  }

  @override
  String toString() => value;
}
