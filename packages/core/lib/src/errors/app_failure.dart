sealed class AppFailure {
  const AppFailure({required this.message});

  final String message;

  List<Object?> get _props => [message];

  const factory AppFailure.validation({
    required String message,
    String? field,
  }) = ValidationFailure;

  const factory AppFailure.network({required String message, int? statusCode}) =
      NetworkFailure;

  const factory AppFailure.cache({required String message, Object? cause}) =
      CacheFailure;

  const factory AppFailure.unauthorized({required String message}) =
      UnauthorizedFailure;

  const factory AppFailure.unexpected({
    required String message,
    Object? cause,
  }) = UnexpectedFailure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AppFailure &&
        other.runtimeType == runtimeType &&
        _listEquals(other._props, _props);
  }

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({required super.message, this.field});

  final String? field;

  @override
  List<Object?> get _props => [message, field];
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({required super.message, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get _props => [message, statusCode];
}

final class CacheFailure extends AppFailure {
  const CacheFailure({required super.message, this.cause});

  final Object? cause;

  @override
  List<Object?> get _props => [message, cause];
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({required super.message});
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({required super.message, this.cause});

  final Object? cause;

  @override
  List<Object?> get _props => [message, cause];
}

bool _listEquals(List<Object?> first, List<Object?> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}
