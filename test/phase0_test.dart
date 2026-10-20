import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/config/app_config.dart';
import 'package:badrgo_ops_console/core/errors/app_exception.dart';
import 'package:badrgo_ops_console/core/errors/error_code.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/network/rest_client.dart';
import 'package:badrgo_ops_console/core/network/graphql_client.dart';
import 'package:badrgo_ops_console/core/utils/currency_formatter.dart';
import 'package:badrgo_ops_console/core/utils/date_formatter.dart';
import 'package:badrgo_ops_console/core/utils/phone_masker.dart';
import 'package:badrgo_ops_console/features/health/domain/entities/health_entity.dart';
import 'package:badrgo_ops_console/features/health/domain/repositories/health_repository.dart';
import 'package:badrgo_ops_console/features/health/presentation/bloc/health_cubit.dart';
import 'package:badrgo_ops_console/features/health/presentation/bloc/health_state.dart';

class MockHealthRepository implements HealthRepository {
  final bool shouldFail;
  MockHealthRepository({this.shouldFail = false});

  @override
  Future<ApiResult<HealthEntity>> getHealth() async {
    if (shouldFail) {
      return const ApiFailure(
        AppException(
          code: ErrorCode.networkError,
          message: 'Connection failed',
        ),
      );
    }
    return const ApiSuccess(
      HealthEntity(
        isOk: true,
        time: '2026-10-20T12:00:00Z',
        simulatorActive: true,
        openStreams: 10,
        openSockets: 2,
      ),
    );
  }
}

void main() {
  group('Phase 0: Environment & AppConfig Verification', () {
    test('AppConfig has correct default URLs and builders', () {
      expect(AppConfig.baseUrl, 'https://sandbox.badrgo.com');
      expect(AppConfig.baseWsUrl, 'wss://sandbox.badrgo.com');

      final wsUrl = AppConfig.buildWsUrl('test-token-123');
      expect(wsUrl, 'wss://sandbox.badrgo.com/ws?token=test-token-123');

      final sseUrl = AppConfig.buildSseUrl('test-token-123', lastEventId: 'evt-456');
      expect(sseUrl, contains('token=test-token-123'));
      expect(sseUrl, contains('lastEventId=evt-456'));
    });
  });

  group('Phase 0: Error Envelopes & Exception Parsing', () {
    test('Parses standard REST error format', () {
      const responseBody = '''
      {
        "error": {
          "code": "INVALID_STATE",
          "message": "Trip cannot be cancelled in COMPLETED state"
        }
      }
      ''';

      final exception = AppException.fromRestResponse(
        statusCode: 409,
        body: responseBody,
      );

      expect(exception.code, ErrorCode.invalidState);
      expect(exception.message, 'Trip cannot be cancelled in COMPLETED state');
      expect(exception.statusCode, 409);
    });

    test('Parses 503 Maintenance error with Retry-After header', () {
      const responseBody = '''
      {
        "error": {
          "code": "MAINTENANCE",
          "message": "API restarting for scheduled update",
          "details": {
            "reason": "planned",
            "retryAfterSeconds": 20
          }
        }
      }
      ''';

      final exception = AppException.fromRestResponse(
        statusCode: 503,
        body: responseBody,
        retryAfterHeader: 20,
      );

      expect(exception.code, ErrorCode.maintenance);
      expect(exception.retryAfterSeconds, 20);
      expect(exception.statusCode, 503);
    });

    test('Parses GraphQL error with extensions.code', () {
      final graphQLError = {
        'message': 'Permission denied',
        'extensions': {
          'code': 'FORBIDDEN',
        },
      };

      final exception = AppException.fromGraphQLError(graphQLError);
      expect(exception.code, ErrorCode.forbidden);
      expect(exception.message, 'Permission denied');
    });
  });

  group('Phase 0: DRY Utilities (Phone Masking, Currency, Dates)', () {
    test('PhoneMasker correctly masks for viewer and unmasks for others', () {
      const phone = '+97455123456';
      final masked = PhoneMasker.mask(phone, shouldMask: true);
      final unmasked = PhoneMasker.mask(phone, shouldMask: false);

      expect(masked, contains('••••'));
      expect(masked, startsWith('+974'));
      expect(masked, endsWith('56'));
      expect(unmasked, phone);
    });

    test('CurrencyFormatter renders multi-currency list items correctly', () {
      final qar = CurrencyFormatter.format(15420.50, 'QAR');
      final usd = CurrencyFormatter.format(15420.50, 'USD');

      expect(qar, 'QAR 15,420.50');
      expect(usd, 'USD 15,420.50');
    });

    test('DateFormatter formats elapsed duration for downtime', () {
      const duration = Duration(minutes: 5, seconds: 20);
      final formatted = DateFormatter.formatDuration(duration);
      expect(formatted, '5m 20s');
    });
  });

  group('Phase 0: Dio Network Clients Initialization', () {
    test('RestClient and GraphQLClient instantiate with Dio', () {
      final restClient = RestClient();
      final graphQLClient = GraphQLClient();

      expect(restClient.dio.options.baseUrl, 'https://sandbox.badrgo.com');
      restClient.updateToken('sample_token');
      expect(restClient.currentToken, 'sample_token');

      graphQLClient.updateToken('sample_token');
    });
  });

  group('Phase 0: Clean MVVM with BLoC Architecture Flow', () {
    test('HealthCubit emits [HealthLoading, HealthLoaded] via Domain Repository', () async {
      final repo = MockHealthRepository();
      final cubit = HealthCubit(healthRepository: repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const HealthLoading(),
          isA<HealthLoaded>().having((s) => s.health.isOk, 'isOk', true),
        ]),
      );

      await cubit.checkHealth();
    });

    test('HealthCubit emits [HealthLoading, HealthError] on failure', () async {
      final repo = MockHealthRepository(shouldFail: true);
      final cubit = HealthCubit(healthRepository: repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const HealthLoading(),
          isA<HealthError>().having((s) => s.message, 'message', 'Connection failed'),
        ]),
      );

      await cubit.checkHealth();
    });
  });
}
