import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/event_image.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../explore/presentation/screens/explore_screen.dart';

final galleryImagesProvider = FutureProvider.autoDispose<List<EventImage>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getGalleryImages(page: 0, size: 50);
  return response.content;
});

final galleryCategoryProvider = StateProvider<int?>((ref) => null);

final filteredGalleryProvider = FutureProvider.autoDispose<List<EventImage>>((
  ref,
) async {
  final api = ref.watch(apiServiceProvider);
  final categoryId = ref.watch(galleryCategoryProvider);

  if (categoryId != null) {
    final response =
        await api.getGalleryImagesByCategory(categoryId, page: 0, size: 50);
    return response.content;
  }

  final response = await api.getGalleryImages(page: 0, size: 50);
  return response.content;
});

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final crossAxisCount = screenWidth >= 1100
        ? 4
        : screenWidth >= 700
            ? 3
            : 2;
    final childAspectRatio = screenWidth >= 1100
        ? 0.82
        : screenWidth >= 700
            ? 0.74
            : textScale > 1.05
                ? 0.54
                : 0.58;
    final l10n = AppLocalizations.of(context)!;
    final imagesAsync = ref.watch(filteredGalleryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(galleryCategoryProvider);

    final selectedCategoryName = categoriesAsync.maybeWhen(
      data: (categories) {
        final match = categories.cast<Category?>().firstWhere(
              (category) => category?.id == selectedCategory,
              orElse: () => null,
            );
        return match?.name;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.galleryTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Filter gallery',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  onPressed: () =>
                      _showFilterSheet(context, ref, categoriesAsync),
                  icon: const Icon(Icons.tune_rounded),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: l10n.refreshTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  onPressed: () => ref.invalidate(filteredGalleryProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: imagesAsync.when(
        data: (images) {
          if (images.isEmpty) {
            return EmptyState(
              icon: Icons.photo_library_outlined,
              iconColor: AppColors.primary,
              title: 'No photos yet',
              subtitle:
                  'Event imagery will appear here as attendees and organisers publish moments.',
              actionLabel: l10n.refresh,
              onAction: () => ref.invalidate(filteredGalleryProvider),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(filteredGalleryProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageX,
                      AppSpacing.xl,
                      AppSpacing.pageX,
                      0,
                    ),
                    child: Column(
                      children: [
                        AppCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          borderColor: AppColors.borderLight,
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: AppRadius.allLg,
                                ),
                                child: const Icon(
                                  Icons.collections_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${images.length} captured moments',
                                      style: AppTypography.h3.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      selectedCategoryName != null
                                          ? 'Filtered to $selectedCategoryName so users can browse a tighter visual story.'
                                          : 'Visual browsing now keeps enough context on each card to preserve the event connection.',
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selectedCategoryName != null)
                          AppCard(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.filter_alt_outlined,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Showing only $selectedCategoryName',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Clear filter',
                                  onPressed: () {
                                    ref
                                        .read(galleryCategoryProvider.notifier)
                                        .state = null;
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                        const SectionHeader(
                          title: 'Latest event moments',
                          subtitle:
                              'The grid uses fewer columns so imagery, titles and captions stay readable on real devices.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageX,
                    0,
                    AppSpacing.pageX,
                    AppSpacing.massive,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      childAspectRatio: childAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final image = images[index];
                        return _GalleryCard(
                          image: image,
                          onTap: () =>
                              _openFullScreenGallery(context, images, index),
                          onOpenEvent: () =>
                              context.push('/event/${image.eventId}'),
                        );
                      },
                      childCount: images.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading gallery...'),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(filteredGalleryProvider),
        ),
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    AppBottomSheet.show(
      context: context,
      title: 'Filter gallery',
      subtitle: 'Focus on one event category at a time.',
      child: categoriesAsync.when(
        data: (categories) => Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _FilterOptionChip(
              label: 'All',
              selected: ref.watch(galleryCategoryProvider) == null,
              onTap: () {
                ref.read(galleryCategoryProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            ...categories.map(
              (category) => _FilterOptionChip(
                label: category.name,
                selected: ref.watch(galleryCategoryProvider) == category.id,
                onTap: () {
                  ref.read(galleryCategoryProvider.notifier).state =
                      category.id;
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Text('Failed to load categories'),
      ),
    );
  }

  void _openFullScreenGallery(
    BuildContext context,
    List<EventImage> images,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.image,
    required this.onTap,
    required this.onOpenEvent,
  });

  final EventImage image;
  final VoidCallback onTap;
  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: AspectRatio(
                  aspectRatio: 1.32,
                  child: CachedNetworkImage(
                    imageUrl: image.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.primarySoft,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primarySoft,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: StatusChip(
                  label: image.isCover ? 'Cover' : 'Photo',
                  variant: image.isCover
                      ? StatusChipVariant.warning
                      : StatusChipVariant.primary,
                  compact: true,
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: IconButton(
                  tooltip: 'Open event',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: onOpenEvent,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.eventTitle ?? 'Event moment',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    image.caption?.trim().isNotEmpty == true
                        ? image.caption!
                        : 'Open the full photo and related event details.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.textLight,
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          image.uploadedByName?.trim().isNotEmpty == true
                              ? image.uploadedByName!
                              : 'Event gallery',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.allPill,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surfaceVariant,
            borderRadius: AppRadius.allPill,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  final List<EventImage> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeImage = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: AppTypography.h4.copyWith(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final image = widget.images[index];
              return InteractiveViewer(
                minScale: 0.75,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: image.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.massive,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.textPrimary.withValues(alpha: 0.92),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeImage.eventTitle ?? 'Event moment',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                    ),
                    if (activeImage.caption?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        activeImage.caption!,
                        style: AppTypography.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        if (activeImage.uploadedByName?.trim().isNotEmpty ==
                            true)
                          Expanded(
                            child: Text(
                              'By ${activeImage.uploadedByName}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        if (activeImage.createdAt != null)
                          Text(
                            DateFormat('MMM d, yyyy').format(
                              activeImage.createdAt!,
                            ),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'View related event',
                      icon: Icons.event_outlined,
                      expanded: true,
                      onPressed: () =>
                          context.push('/event/${activeImage.eventId}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
