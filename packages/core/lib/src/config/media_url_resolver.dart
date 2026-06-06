final class MediaUrlResolver {
  const MediaUrlResolver({Uri? baseUri}) : _baseUri = baseUri;

  const MediaUrlResolver.identity() : _baseUri = null;

  final Uri? _baseUri;

  String? resolveString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(text);
    if (uri == null) {
      return null;
    }

    if (uri.hasScheme) {
      return uri.scheme == 'http' || uri.scheme == 'https' ? text : null;
    }

    final baseUri = _baseUri;
    if (baseUri == null) {
      return text;
    }

    return _asDirectory(baseUri).resolveUri(uri).toString();
  }

  Uri? resolveUri(String? value) {
    final resolved = resolveString(value);
    if (resolved == null) {
      return null;
    }

    return Uri.tryParse(resolved);
  }

  List<String> resolveStrings(Iterable<String> values) {
    return values
        .map(resolveString)
        .whereType<String>()
        .toList(growable: false);
  }

  static Uri _asDirectory(Uri uri) {
    final path = uri.path;
    if (path.isEmpty || path.endsWith('/')) {
      return uri;
    }

    return uri.replace(path: '$path/');
  }
}
