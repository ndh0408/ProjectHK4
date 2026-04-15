import 'package:flutter_riverpod/flutter_riverpod.dart';

class ComparisonNotifier extends StateNotifier<List<String>> {
  ComparisonNotifier() : super([]);

  void addEventId(String eventId) {
    if (!state.contains(eventId) && state.length < 4) {
      state = [...state, eventId];
    }
  }

  void removeEventId(String eventId) {
    state = state.where((id) => id != eventId).toList();
  }

  void toggleEventId(String eventId) {
    if (state.contains(eventId)) {
      removeEventId(eventId);
    } else if (state.length < 4) {
      addEventId(eventId);
    }
  }

  void clear() {
    state = [];
  }

  bool isSelected(String eventId) {
    return state.contains(eventId);
  }

  int get count => state.length;
  bool get canAddMore => state.length < 4;
  bool get hasEnoughForComparison => state.length >= 2;
}

final selectedEventsForComparisonProvider =
    StateNotifierProvider<ComparisonNotifier, List<String>>((ref) {
  return ComparisonNotifier();
});
