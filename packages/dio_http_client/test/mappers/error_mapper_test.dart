import 'package:abstract_http_client/abstract_http_client.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_client/src/mappers/error_mapper.dart';
import 'package:test/test.dart';

void main() {
  const testRequest = HttpRequest(
    method: HttpMethod.get,
    path: '/test',
  );

  final testStackTrace = StackTrace.current;

  group('DioErrorMapper', () {
    group('toHttpError', () {
      test('should map connectionTimeout', () {
        final dioException = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
          message: 'Connection timeout',
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.connectionTimeout);
        expect(error.request, testRequest);
        expect(error.message, 'Connection timeout');
      });

      test('should map sendTimeout', () {
        final dioException = DioException(
          type: DioExceptionType.sendTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.sendTimeout);
      });

      test('should map receiveTimeout', () {
        final dioException = DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.receiveTimeout);
      });

      test('should map badCertificate', () {
        final dioException = DioException(
          type: DioExceptionType.badCertificate,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.badCertificate);
      });

      test('should map cancel to cancelled', () {
        final dioException = DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.cancelled);
      });

      test('should map connectionError to networkUnreachable', () {
        final dioException = DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.type, HttpErrorType.networkUnreachable);
      });

      group('badResponse status codes', () {
        test('should map 401 to unauthorized', () {
          final dioException = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/test'),
            ),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.unauthorized);
          expect(error.response, isNotNull);
          expect(error.response!.statusCode, 401);
        });

        test('should map 403 to forbidden', () {
          final dioException = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 403,
              requestOptions: RequestOptions(path: '/test'),
            ),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.forbidden);
        });

        test('should map 404 to notFound', () {
          final dioException = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: '/test'),
            ),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.notFound);
        });

        test('should map 429 to rateLimited', () {
          final dioException = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 429,
              requestOptions: RequestOptions(path: '/test'),
            ),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.rateLimited);
        });

        test('should map 5xx to serverError', () {
          for (final statusCode in [500, 502, 503, 504, 599]) {
            final dioException = DioException(
              type: DioExceptionType.badResponse,
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                statusCode: statusCode,
                requestOptions: RequestOptions(path: '/test'),
              ),
            );

            final error = DioErrorMapper.toHttpError(
              dioException,
              testRequest,
              testStackTrace,
            );

            expect(error.type, HttpErrorType.serverError,
                reason: 'Status $statusCode should be serverError',);
          }
        });

        test('should map other 4xx to badResponse', () {
          final dioException = DioException(
            type: DioExceptionType.badResponse,
            requestOptions: RequestOptions(path: '/test'),
            response: Response(
              statusCode: 400,
              requestOptions: RequestOptions(path: '/test'),
            ),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.badResponse);
        });
      });

      group('unknown errors', () {
        test('should detect DNS errors', () {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/test'),
            message: 'Failed host lookup: api.example.com',
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.dnsLookupFailed);
        });

        test('should detect network errors', () {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/test'),
            message: 'Network is unreachable',
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.networkUnreachable);
        });

        test('should detect socket errors', () {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/test'),
            message: 'Socket exception occurred',
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.networkUnreachable);
        });

        test('should detect CancelException', () {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/test'),
            error: const CancelException('User cancelled'),
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.cancelled);
        });

        test('should return unknown for unrecognized errors', () {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/test'),
            message: 'Some unknown error',
          );

          final error = DioErrorMapper.toHttpError(
            dioException,
            testRequest,
            testStackTrace,
          );

          expect(error.type, HttpErrorType.unknown);
        });
      });

      test('should preserve cause and stackTrace', () {
        final dioException = DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/test'),
        );

        final error = DioErrorMapper.toHttpError(
            dioException, testRequest, testStackTrace,);

        expect(error.cause, dioException);
        expect(error.stackTrace, testStackTrace);
      });
    });
  });
}
