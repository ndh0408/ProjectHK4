import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/theme.dart';
import '../../core/design_tokens/design_tokens.dart';
import '../models/event.dart';
import 'app_card.dart';
import 'status_chip.dart';

class EventListTile extends StatelessWidget {
  const EventListTile({
    super.key,
    required this.event,
    this.onTap,
    this.status,
    this.statusVariant = StatusChipVariant.primary,
    this.trailing,
    this.compact = false,
    this.margin,
  });

  final Event event;
  final VoidCallback? onTap;
  final String? status;
  final StatusChipVariant statusVariant;
  final Widget? trailing;
  final bool compact;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final metaTextStyle = AppTypography.caption.copyWith(
      color: AppColors.textSecondary,
    );

    return AppCard(
      margin: margin ??
          EdgeInsets.only(bottom: compact ? AppSpacing.md : AppSpacing.lg),
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventArtwork(
            imageUrl: event.imageUrl,
            title: event.title,
            compact: compact,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (event.category != null)
                            StatusChip(
                              label: event.category!.name,
                              variant: StatusChipVariant.neutral,
                              compact: true,
                            ),
                          if (status != null)
                            StatusChip(
                              label: status!,
                              variant: statusVariant,
                              compact: true,
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.title,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact ? AppTypography.h4 : AppTypography.h3).copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.iconDefault,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        DateFormat('EEE, MMM d • h:mm a')
                            .format(event.startDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaTextStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.iconDefault,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaTextStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primarySoft,
                            backgroundImage: event.organiser?.avatarUrl != null
                                ? CachedNetworkImageProvider(
                                    event.organiser!.avatarUrl!)
                                : null,
                            child: event.organiser?.avatarUrl == null
                                ? Text(
                                    (event.organiser?.fullName ?? 'O')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              event.organiserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaTextStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: event.isFree
                          ? 'Free'
                          : '\$${event.price.toStringAsFixed(0)}',
                      variant: event.isFree
                          ? StatusChipVariant.success
                          : StatusChipVariant.primary,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventArtwork extends StatelessWidget {
  const _EventArtwork({
    required this.imageUrl,
    required this.title,
    required this.compact,
  });

  final String? imageUrl;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 88.0 : 104.0;

    return ClipRRect(
      borderRadius: AppRadius.allMd,
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _FallbackArtwork(title: title),
              )
            : _FallbackArtwork(title: title),
      ),
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        title.substring(0, 1).toUpperCase(),
        style: AppTypography.h2.copyWith(color: Colors.white),
      ),
    );
  }
}
