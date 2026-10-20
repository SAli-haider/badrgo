import 'dart:async';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/graphql_client.dart';
import '../../../../core/network/rest_client.dart';
import '../../../../core/network/sse/sse_client.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/trips_repository.dart';
import '../models/trip_model.dart';

/// Concrete implementation of TripsRepository.
///
/// Adheres strictly to requirements:
/// - TR-1: REST for every write (assign, cancel, refund, driver list).
/// - TR-2: GraphQL for paginated trip list and single nested trip detail.
/// - TR-3: SSE for live updates to the trip list (`trip.created`, `trip.updated`).
/// - M4: Handle 409 INVALID_STATE clearly.
class TripsRepositoryImpl implements TripsRepository {
  final GraphQLClient _graphQLClient;
  final RestClient _restClient;
  final SseClient _sseClient;

  static const String _paginatedTripsQuery = r'''
    query GetTrips($filter: TripFilter, $first: Int, $after: String) {
      trips(filter: $filter, first: $first, after: $after) {
        nodes {
          id
          status
          city {
            id
            name
          }
          rider {
            id
            name
            phone
          }
          driver {
            id
            name
            phone
            vehicle {
              make
              model
              plate
              color
            }
          }
          pickup {
            address
          }
          dropoff {
            address
          }
          distanceKm
          fare {
            currency
            amount
          }
          refunded {
            currency
            amount
          }
          refundReason
          cancelReason
          cancelledBy
          requestedAt
          assignedAt
          startedAt
          completedAt
          cancelledAt
          timeline {
            status
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
        totalCount
      }
    }
  ''';

  static const String _tripDetailQuery = r'''
    query GetTripDetail($id: ID!) {
      trip(id: $id) {
        id
        status
        city {
          id
          name
        }
        rider {
          id
          name
          phone
        }
        driver {
          id
          name
          phone
          vehicle {
            make
            model
            plate
            color
          }
        }
        pickup {
          address
        }
        dropoff {
          address
        }
        distanceKm
        fare {
          currency
          amount
        }
        refunded {
          currency
          amount
        }
        refundReason
        cancelReason
        cancelledBy
        requestedAt
        assignedAt
        startedAt
        completedAt
        cancelledAt
        timeline {
          status
        }
      }
    }
  ''';

  TripsRepositoryImpl({
    required GraphQLClient graphQLClient,
    required RestClient restClient,
    required SseClient sseClient,
  })  : _graphQLClient = graphQLClient,
        _restClient = restClient,
        _sseClient = sseClient;

  @override
  Future<ApiResult<PaginatedTripsEntity>> getTrips({
    TripFilterEntity? filter,
    int first = 20,
    String? after,
  }) async {
    final vars = <String, dynamic>{
      'first': first,
      'after': ?after,
    };

    if (filter != null) {
      final filterMap = <String, dynamic>{};
      if (filter.status != null && filter.status!.isNotEmpty) {
        filterMap['status'] = filter.status!.map((s) => s.apiValue).toList();
      }
      if (filter.search != null && filter.search!.trim().isNotEmpty) {
        filterMap['search'] = filter.search!.trim();
      }
      if (filter.from != null) {
        filterMap['from'] = filter.from!.toIso8601String();
      }
      if (filter.to != null) {
        filterMap['to'] = filter.to!.toIso8601String();
      }
      if (filter.cityId != null && filter.cityId!.isNotEmpty) {
        filterMap['cityId'] = filter.cityId;
      }
      if (filterMap.isNotEmpty) {
        vars['filter'] = filterMap;
      }
    }

    return _graphQLClient.query<PaginatedTripsEntity>(
      document: _paginatedTripsQuery,
      variables: vars,
      fromData: (data) => PaginatedTripsModel.fromGraphQL(data),
    );
  }

  @override
  Future<ApiResult<TripEntity>> getTripById(String id) async {
    return _graphQLClient.query<TripEntity>(
      document: _tripDetailQuery,
      variables: {'id': id},
      fromData: (data) {
        final tripData = data['trip'] as Map<String, dynamic>? ?? {};
        return TripModel.fromJson(tripData).toEntity();
      },
    );
  }

  @override
  Future<ApiResult<List<DriverEntity>>> getAvailableDrivers({String? cityId}) async {
    return _restClient.get<List<DriverEntity>>(
      '/api/drivers',
      queryParameters: {
        'status': 'available',
        if (cityId != null && cityId.isNotEmpty) 'cityId': cityId,
        'pageSize': 50,
      },
      fromJson: (json) {
        if (json is Map<String, dynamic> && json['data'] is List) {
          final list = json['data'] as List;
          return list
              .map((d) => DriverModel.fromJson(d as Map<String, dynamic>))
              .toList();
        }
        return [];
      },
    );
  }

  @override
  Future<ApiResult<TripEntity>> assignDriver({
    required String tripId,
    required String driverId,
  }) async {
    return _restClient.post<TripEntity>(
      '/api/trips/$tripId/assign',
      body: {'driverId': driverId},
      fromJson: _parseTripResponse,
    );
  }

  @override
  Future<ApiResult<TripEntity>> cancelTrip({
    required String tripId,
    required String reason,
  }) async {
    return _restClient.post<TripEntity>(
      '/api/trips/$tripId/cancel',
      body: {'reason': reason},
      fromJson: _parseTripResponse,
    );
  }

  @override
  Future<ApiResult<TripEntity>> refundTrip({
    required String tripId,
    required double amount,
    required String reason,
  }) async {
    return _restClient.post<TripEntity>(
      '/api/trips/$tripId/refund',
      body: {
        'amount': amount,
        'reason': reason,
      },
      fromJson: _parseTripResponse,
    );
  }

  TripEntity _parseTripResponse(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json.containsKey('trip') && json['trip'] is Map) {
        return TripModel.fromJson(json['trip'] as Map<String, dynamic>).toEntity();
      }
      return TripModel.fromJson(json).toEntity();
    }
    throw Exception('Invalid trip response');
  }

  @override
  Stream<TripEntity> subscribeTripCreated() {
    return _sseClient.listenTo('trip.created').map(_parseTripResponse);
  }

  @override
  Stream<TripEntity> subscribeTripUpdated() {
    return _sseClient.listenTo('trip.updated').map(_parseTripResponse);
  }

  @override
  Future<void> dispose() async {
    // Realtime connection lifecycle is managed centrally.
  }
}
