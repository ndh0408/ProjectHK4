import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event_image.dart';
import '../../../../shared/models/category.dart';
import '../../../explore/presentation/screens/explore_screen.dart';

final galleryImagesProvider = FutureProvider.autoDispose<List<EventImage>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getGalleryImages(page: 0, size: 50);
  return response.content;
});

final galleryCategoryProvider = StateProvider<int?>((ref) => null);

final filteredGalleryProvider = FutureProvider.autoDispose<List<EventImage>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final categoryId = ref.watch(galleryCategoryProvider);

  if (categoryId != null) {
    final response = await api.getGalleryImagesByCategory(categoryId, page: 0, size: 50);
    return response.content;
  } else {
    final response = await api.getGalleryImages(page: 0, size: 50);
    return response.content;
  }
});

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(filteredGalleryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(galleryCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref, categoriesAsync),
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedCategory != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  categoriesAsync.when(
                    data: (categories) {
                      final cat = categories.firstWhere(
                        (c) => c.id == selectedCategory,
                        orElse: () => categories.first,
                      );
                      return Chip(
                        label: Text(cat.name),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          ref.read(galleryCategoryProvider.notifier).state = null;
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: imagesAsync.when(
              data: (images) {
                if (images.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No photos yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Event photos will appear here',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(filteredGalleryProvider);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return GestureDetector(
                        onTap: () => _openFullScreenGallery(context, images, index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: image.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => context.push('/event/${image.eventId}'),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.open_in_new,
                                    color: AppColors.textOnPrimary,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.textPrimary.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  image.eventTitle ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textOnPrimary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(filteredGalleryProvider),
                      child: const Text('Retry'),
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

  void _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: ref.watch(galleryCategoryProvider) == null,
                    onSelected: (_) {
                      ref.read(galleryCategoryProvider.notifier).state = null;
                      Navigator.pop(context);
                    },
                  ),
                  ...categories.map(
                    (cat) => ChoiceChip(
                      label: Text(cat.name),
                      selected: ref.watch(galleryCategoryProvider) == cat.id,
                      onSelected: (_) {
                        ref.read(galleryCategoryProvider.notifier).state = cat.id;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Failed to load categories'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openFullScreenGallery(BuildContext context, List<EventImage> images, int initialIndex) {
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
  late PageController _pageController;
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
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.textOnPrimary,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: AppColors.textOnPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textOnPrimary),
          onPressed: () => Navigator.pop(context),
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
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: image.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: AppColors.textOnPrimary),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: AppColors.textOnPrimary,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.textPrimary.withOpacity(0.7),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.images[_currentIndex].eventTitle ?? '',
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.images[_currentIndex].uploadedByName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'by ${widget.images[_currentIndex].uploadedByName}',
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final eventId = widget.images[_currentIndex].eventId;
                        context.push('/event/$eventId');
                      },
                      icon: const Icon(Icons.event, size: 18),
                      label: const Text('View Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
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
