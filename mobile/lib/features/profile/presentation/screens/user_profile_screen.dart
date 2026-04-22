import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';

final userProfileByIdProvider =
    FutureProvider.family.autoDispose<User, String>((ref, userId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getUserProfileById(userId);
});

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileByIdProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: profileAsync.when(
        data: (user) => _UserProfileBody(user: user),
        loading: () => const LoadingState(message: 'Loading profile...'),
        error: (error, _) => Padding(
          padding: AppSpacing.screenPadding,
          child: ErrorState(
            message: ErrorUtils.extractMessage(
              error,
              fallback: 'Failed to load this profile.',
            ),
            onRetry: () => ref.invalidate(userProfileByIdProvider(userId)),
          ),
        ),
      ),
    );
  }
}

class _UserProfileBody extends ConsumerWidget {
  const _UserProfileBody({required this.user});

  final User user;

  List<String> get _interestTags {
    final raw = user.interests ?? '';
    return raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Future<void> _messageUser(BuildContext context, WidgetRef ref) async {
    try {
      final conversation =
          await ref.read(apiServiceProvider).getDirectChat(user.id);
      if (!context.mounted) return;
      context.push('/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorUtils.extractMessage(
              error,
              fallback: 'Could not open chat.',
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isSelf = currentUser?.id == user.id;
    final memberSince = user.createdAt != null
        ? DateFormat('MMM yyyy').format(user.createdAt!)
        : null;

    return ListView(
      padding: AppSpacing.screenPadding.copyWith(bottom: AppSpacing.xxxl),
      children: [
        AppCard(
          background: AppColors.primarySoft,
          borderColor: AppColors.primary.withValues(alpha: 0.12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        (user.fullName?.isNotEmpty ?? false)
                            ? user.fullName![0].toUpperCase()
                            : '?',
                        style: AppTypography.h1.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ?? 'Unknown user',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        StatusChip(
                          label: user.role.name.toUpperCase(),
                          variant: StatusChipVariant.primary,
                        ),
                        StatusChip(
                          label: user.networkingVisible
                              ? 'Networking visible'
                              : 'Private profile',
                          variant: user.networkingVisible
                              ? StatusChipVariant.info
                              : StatusChipVariant.neutral,
                        ),
                      ],
                    ),
                    if (memberSince != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Member since $memberSince',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                (user.bio?.trim().isNotEmpty ?? false)
                    ? user.bio!.trim()
                    : 'No bio added yet.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Interests',
                style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_interestTags.isEmpty)
                Text(
                  'No interests shared yet.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _interestTags
                      .map(
                        (interest) => StatusChip(
                          label: interest,
                          variant: StatusChipVariant.primary,
                          compact: true,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        if (!isSelf) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Message',
            icon: Icons.chat_bubble_outline_rounded,
            expanded: true,
            onPressed: () => _messageUser(context, ref),
          ),
        ],
      ],
    );
  }
}
