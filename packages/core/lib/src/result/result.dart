import '../errors/app_failure.dart';

sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = ResultSuccess<T>;

  const factory Result.failure(AppFailure failure) = ResultFailure<T>;

  bool get isSuccess => this is ResultSuccess<T>;

  bool get isFailure => this is ResultFailure<T>;

  List<Object?> get _props;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Result<T> &&
        other.runtimeType == runtimeType &&
        _listEquals(other._props, _props);
  }

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));
}

final class ResultSuccess<T> extends Result<T> {
  const ResultSuccess(this.value);

  final T value;

  @override
  List<Object?> get _props => [value];
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get _props => [failure];
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
