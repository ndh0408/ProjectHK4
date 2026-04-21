import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
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
    _controller.addListener(_handleControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.query.isNotEmpty) {
        unawaited(ref.read(searchProvider.notifier).search(widget.query));
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(
            right: AppSpacing.lg,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: AppSearchField(
            controller: _controller,
            hintText: 'Search events, venues or organisers',
            autofocus: widget.query.isEmpty,
            onChanged: ref.read(searchProvider.notifier).updateQuery,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                unawaited(ref.read(searchProvider.notifier).search(value));
              }
            },
            trailing: _controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchProvider.notifier).updateQuery('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textMuted,
                    splashRadius: 18,
                  ),
          ),
        ),
      ),
      body: _buildBody(context, searchState),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.isLoading) {
      return const LoadingState(
        message: 'Searching events and ticket inventory...',
      );
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
      return Padding(
        padding: AppSpacing.screenPadding,
        child: EmptyState(
          icon: Icons.travel_explore_rounded,
          title: 'Start with a keyword',
          subtitle:
              'Search by event name, city, category or organiser to jump straight into the right ticket flow.',
        ),
      );
    }

    if (state.results.isEmpty) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching events',
          subtitle:
              'Try a shorter keyword, another city, or browse categories from Explore instead.',
          actionLabel: 'Open Explore',
          onAction: () => context.push('/explore'),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppCard(
          background: AppColors.primarySoft,
          borderColor: AppColors.primary.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.results.length} result${state.results.length != 1 ? 's' : ''}',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Showing the best event matches for "${state.query}".',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...state.results.map(
          (event) => EventListTile(
            event: event,
            onTap: () {
              ref.read(selectedEventProvider.notifier).state = event;
              unawaited(context.push('/event/${event.id}'));
            },
            status: event.isFull
                ? 'Sold out'
                : event.isFree
                    ? 'Free'
                    : 'Book now',
            statusVariant: event.isFull
                ? StatusChipVariant.warning
                : event.isFree
                    ? StatusChipVariant.success
                    : StatusChipVariant.primary,
          ),
        ),
      ],
    );
  }
}
