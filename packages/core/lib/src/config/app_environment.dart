import 'media_url_resolver.dart';

enum AppFlavor { development, staging, production }

final class AppEnvironment {
  const AppEnvironment({
    required AppFlavor flavor,
    required Uri apiBaseUri,
    Uri? storageBaseUri,
  }) : _flavor = flavor,
       _apiBaseUri = apiBaseUri,
       _storageBaseUri = storageBaseUri;

  final AppFlavor _flavor;
  final Uri _apiBaseUri;
  final Uri? _storageBaseUri;

  AppFlavor get flavor => _flavor;

  Uri get apiBaseUri => _apiBaseUri;

  Uri? get storageBaseUri => _storageBaseUri;

  MediaUrlResolver get mediaUrlResolver {
    return MediaUrlResolver(baseUri: _storageBaseUri ?? _apiBaseUri);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppEnvironment &&
        other._flavor == _flavor &&
        other._apiBaseUri == _apiBaseUri &&
        other._storageBaseUri == _storageBaseUri;
  }

  @override
  int get hashCode => Object.hash(_flavor, _apiBaseUri, _storageBaseUri);

  bool get isDevelopment => _flavor == AppFlavor.development;

  bool get isProduction => _flavor == AppFlavor.production;

  static AppEnvironment development() {
    return AppEnvironment(
      flavor: AppFlavor.development,
      apiBaseUri: Uri.parse('https://api.clean-disk.local'),
    );
  }

  static AppEnvironment staging() {
    return AppEnvironment(
      flavor: AppFlavor.staging,
      apiBaseUri: Uri.parse('https://staging-api.clean-disk.local'),
    );
  }

  static AppEnvironment production() {
    return AppEnvironment(
      flavor: AppFlavor.production,
      apiBaseUri: Uri.parse('https://api.clean-disk.local'),
    );
  }

  static AppEnvironment fromDartDefines() {
    const flavor = String.fromEnvironment(
      'CLEAN_DISK_FLAVOR',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment(
      'CLEAN_DISK_API_BASE_URL',
      defaultValue: 'https://api.clean-disk.local',
    );
    const storageBaseUrl = String.fromEnvironment(
      'CLEAN_DISK_STORAGE_BASE_URL',
      defaultValue: '',
    );

    return fromValues(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      storageBaseUrl: storageBaseUrl,
    );
  }

  static AppEnvironment fromValues({
    required String flavor,
    required String apiBaseUrl,
    String? storageBaseUrl,
  }) {
    return AppEnvironment(
      flavor: parseFlavor(flavor),
      apiBaseUri: parseApiBaseUri(apiBaseUrl),
      storageBaseUri: parseOptionalBaseUri(
        storageBaseUrl,
        fieldName: 'storage base URL',
      ),
    );
  }

  static AppFlavor parseFlavor(String value) {
    final normalized = value.trim().toLowerCase();

    return switch (normalized) {
      'dev' || 'development' => AppFlavor.development,
      'stage' || 'staging' => AppFlavor.staging,
      'prod' || 'production' => AppFlavor.production,
      _ => throw FormatException('Unsupported app flavor: $value'),
    };
  }

  static Uri parseApiBaseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('Invalid API base URL: $value');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported API base URL scheme: ${uri.scheme}');
    }

    return _normalizeApiBaseUri(uri);
  }

  static Uri? parseOptionalBaseUri(String? value, {required String fieldName}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('Invalid $fieldName: $value');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported $fieldName scheme: ${uri.scheme}');
    }

    if (uri.hasPort) {
      return Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      );
    }

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      path: uri.path,
    );
  }

  static Uri _normalizeApiBaseUri(Uri uri) {
    final pathSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);

    if (pathSegments.length == 1 && pathSegments.single == 'api') {
      pathSegments.clear();
    }

    if (pathSegments.isEmpty) {
      return uri.replace(path: '');
    }

    return uri.replace(pathSegments: pathSegments);
  }
}
