import '../../../../core/network/api_result.dart';
import '../entities/health_entity.dart';

/// Pure domain repository contract.
abstract class HealthRepository {
  Future<ApiResult<HealthEntity>> getHealth();
}
