import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:test/test.dart';

void main() {
  test('Result exposes success and failure state', () {
    const success = Result<int>.success(1);
    const failure = Result<int>.failure(
      AppFailure.validation(message: 'Invalid value'),
    );

    expect(success.isSuccess, isTrue);
    expect(success.isFailure, isFalse);
    expect(failure.isSuccess, isFalse);
    expect(failure.isFailure, isTrue);
  });

  test('Result and Failure compare by value', () {
    expect(const Result<int>.success(1), const Result<int>.success(1));
    expect(
      const Result<int>.failure(
        AppFailure.network(message: 'Offline', statusCode: 503),
      ),
      const Result<int>.failure(
        AppFailure.network(message: 'Offline', statusCode: 503),
      ),
    );
    expect(
      const AppFailure.validation(message: 'Invalid', field: 'path'),
      const AppFailure.validation(message: 'Invalid', field: 'path'),
    );
  });

  test('Unit compares all instances as the same value', () {
    expect(const Unit(), Unit.value);
    expect(
      const Result<Unit>.success(Unit.value),
      const Result<Unit>.success(Unit()),
    );
  });
}
