import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../home/presentation/widgets/event_card.dart';
import '../../../home/providers/events_provider.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
  });

  final String query;
  final List<Event> results;
  final bool isLoading;
  final bool hasSearched;
  final String? error;

  SearchState copyWith({
    String? query,
    List<Event>? results,
    bool? isLoading,
    bool? hasSearched,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: error,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._api) : super(const SearchState());

  final ApiService _api;
  Timer? _debounce;

  void updateQuery(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);

    if (query.isEmpty) {
      state = state.copyWith(results: [], hasSearched: false);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(search(query));
    });
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null, hasSearched: true);

    try {
      final response = await _api.getEvents(search: query, size: 20);
      state = state.copyWith(
        results: response.content,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ErrorUtils.extractMessage(e),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return SearchNotifier(api);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.query});

  final String query;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.query.isNotEmpty) {
        unawaited(ref.read(searchProvider.notifier).search(widget.query));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.query.isEmpty,
          decoration: InputDecoration(
            hintText: 'Search events...',
            hintStyle: TextStyle(color: AppColors.textOnPrimary.withValues(alpha: 0.7)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          style: const TextStyle(color: AppColors.textOnPrimary),
          cursorColor: AppColors.textOnPrimary,
          onChanged: (value) {
            ref.read(searchProvider.notifier).updateQuery(value);
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              unawaited(ref.read(searchProvider.notifier).search(value));
            }
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchProvider.notifier).updateQuery('');
              },
            ),
        ],
      ),
      body: _buildBody(context, searchState),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () {
          unawaited(ref.read(searchProvider.notifier).search(state.query));
        },
      );
    }

    if (!state.hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Search for events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter keywords to find events',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${state.results.length} result${state.results.length != 1 ? 's' : ''} for "${state.query}"',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final event = state.results[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventCard(
                  event: event,
                  showStatusLabel: true,
                  onTap: () {
                    ref.read(selectedEventProvider.notifier).state = event;
                    unawaited(context.push('/event/${event.id}'));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
