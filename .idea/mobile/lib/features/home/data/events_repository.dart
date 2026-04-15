import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/event.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(apiClientProvider));
});

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.size,
    required this.number,
  });

  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int size;
  final int number;

  bool get hasMore => number < totalPages - 1;
}

class EventsRepository {
  EventsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResponse<Event>> getEvents({
    int page = 0,
    int size = 10,
    String? search,
    String? categorySlug,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categorySlug != null) 'category': categorySlug,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.events,
      queryParameters: queryParams,
    );

    final content = (response['content'] as List<dynamic>)
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedResponse(
      content: content,
      totalElements: response['totalElements'] as int,
      totalPages: response['totalPages'] as int,
      size: response['size'] as int,
      number: response['number'] as int,
    );
  }

  Future<Event> getEventById(int id) async {
    return _apiClient.get<Event>(
      '${ApiConstants.events}/$id',
      fromJson: Event.fromJson,
    );
  }
}
