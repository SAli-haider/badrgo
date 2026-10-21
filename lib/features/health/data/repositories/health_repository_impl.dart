import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/health_entity.dart';
import '../../domain/repositories/health_repository.dart';
import '../models/health_model.dart';

class HealthRepositoryImpl implements HealthRepository {
  final RestClient _restClient;

  HealthRepositoryImpl({required RestClient restClient}) : _restClient = restClient;

  @override
  Future<ApiResult<HealthEntity>> getHealth() async {
    final result = await _restClient.get<HealthModel>(
      AppConfig.healthEndpoint,
      fromJson: (json) => HealthModel.fromJson(json as Map<String, dynamic>),
    );

    return result.when(
      success: (model) => ApiSuccess(model.toEntity()),
      failure: (exception) => ApiFailure(exception),
    );
  }
}
