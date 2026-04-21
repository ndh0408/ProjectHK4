import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

final unreadMessageCountProvider = StateNotifierProvider.autoDispose<
    UnreadMessageCountNotifier, AsyncValue<int>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return UnreadMessageCountNotifier(api);
});

class UnreadMessageCountNotifier extends StateNotifier<AsyncValue<int>> {
  UnreadMessageCountNotifier(this._api) : super(const AsyncValue.data(0));

  final ApiService _api;

  Future<void> loadCount() async {
    try {
      final count = await _api.getUnreadMessageCount();
      if (mounted) {
        state = AsyncValue.data(count);
      }
    } catch (e) {
      if (mounted) {
        state = const AsyncValue.data(0);
      }
    }
  }

  void increment() {
    state.whenData((count) {
      state = AsyncValue.data(count + 1);
    });
  }

  void decrement() {
    state.whenData((count) {
      if (count > 0) {
        state = AsyncValue.data(count - 1);
      }
    });
  }

  void setZero() {
    state = const AsyncValue.data(0);
  }

  void refresh() {
    loadCount();
  }
}
