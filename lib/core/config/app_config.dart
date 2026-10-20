/// Core configuration for the badrgo Ops Console.
///
/// Follows the requirement:
/// "No secrets in the repo. Make the API URL configurable,
/// for example --dart-define=API_URL=..."
class AppConfig {
  AppConfig._();

  /// Base URL of the badrgo backend sandbox.
  /// Configurable at compile time via:
  /// `--dart-define=API_URL=https://sandbox.badrgo.com`
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://sandbox.badrgo.com',
  );

  // REST Endpoints
  static const String loginEndpoint = '/api/auth/sign-in/email';
  static const String logoutEndpoint = '/api/auth/sign-out';
  static const String meEndpoint = '/api/me';
  static const String healthEndpoint = '/api/health';
  static const String driversEndpoint = '/api/drivers';
  static const String alertsEndpoint = '/api/alerts';
  static const String usersEndpoint = '/api/users';

  // GraphQL Endpoint
  static const String graphqlEndpoint = '/graphql';

  // SSE & WebSocket Endpoints
  static const String sseEndpoint = '/api/events';
  static const String wsEndpoint = '/ws';

  /// Converts http/https base URL to ws/wss URL
  static String get baseWsUrl {
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    } else if (baseUrl.startsWith('http://')) {
      return baseUrl.replaceFirst('http://', 'ws://');
    }
    return 'wss://$baseUrl';
  }

  /// Builds WebSocket connection URL with token query parameter:
  /// "Browsers cannot set headers on EventSource or WebSocket,
  /// so pass ?token=`<token>` on those two."
  static String buildWsUrl(String token) {
    final uri = Uri.parse('$baseWsUrl$wsEndpoint');
    return uri.replace(queryParameters: {'token': token}).toString();
  }

  /// Builds SSE connection URL with token query parameter.
  static String buildSseUrl(String token, {String? lastEventId}) {
    final uri = Uri.parse('$baseUrl$sseEndpoint');
    final queryParams = <String, String>{'token': token};
    if (lastEventId != null && lastEventId.isNotEmpty) {
      queryParams['lastEventId'] = lastEventId;
    }
    return uri.replace(queryParameters: queryParams).toString();
  }
}
