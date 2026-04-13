import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/event.dart';

final personalizedRecommendationsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getPersonalizedRecommendations(limit: 10);
  } catch (e) {
    return [];
  }
});

final trendingEventsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getTrendingEvents(limit: 10);
  } catch (e) {
    return [];
  }
});

final similarEventsProvider =
    FutureProvider.autoDispose.family<List<Event>, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  try {
    return await api.getSimilarEvents(eventId, limit: 5);
  } catch (e) {
    return [];
  }
});
