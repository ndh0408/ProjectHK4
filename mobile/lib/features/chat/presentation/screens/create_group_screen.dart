import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event_buddy.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart'
    show eventBuddiesProvider;

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _selectedUsers = <EventBuddy>{};
  File? _groupImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventBuddiesProvider.notifier).loadBuddies();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _groupImage = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 member'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);

      String? imageUrl;
      if (_groupImage != null) {
        imageUrl = await api.uploadImage(_groupImage!, folder: 'groups');
      }

      final conversation = await api.createGroupChat(
        name: _nameController.text.trim(),
        participantIds: _selectedUsers.map((user) => user.userId).toList(),
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
      context.push('/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create group: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buddiesState = ref.watch(eventBuddiesProvider);
    ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.section),
              borderColor: AppColors.borderLight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.allLg,
                        image: _groupImage != null
                            ? DecorationImage(
                                image: FileImage(_groupImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _groupImage == null
                          ? const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                              size: 30,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AppTextField(
                      controller: _nameController,
                      label: 'Group name',
                      hint: 'Weekend planners, VIP crew, check-in team...',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a group name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedUsers.isNotEmpty) ...[
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.section),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Selected members',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusChip(
                          label: '${_selectedUsers.length}',
                          variant: StatusChipVariant.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 78,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _selectedUsers.elementAt(index);
                          return Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.md),
                            child: _SelectedUserChip(
                              user: user,
                              onRemove: () {
                                setState(() => _selectedUsers.remove(user));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SectionHeader(
              title: 'Add members from Event Buddies',
              subtitle:
                  'Start with people you already share events with to improve chat relevance from day one.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (buddiesState.isLoading && buddiesState.buddies.isEmpty)
              const LoadingState(message: 'Loading buddies...')
            else if (buddiesState.buddies.isEmpty)
              const EmptyState(
                icon: Icons.people_outline_rounded,
                compact: true,
                title: 'No event buddies',
                subtitle:
                    'Register for more events to unlock suggested members for group chat.',
              )
            else
              ...buddiesState.buddies.map(
                (buddy) => _SelectableBuddyCard(
                  buddy: buddy,
                  isSelected: _selectedUsers.contains(buddy),
                  onToggle: () {
                    setState(() {
                      if (_selectedUsers.contains(buddy)) {
                        _selectedUsers.remove(buddy);
                      } else {
                        _selectedUsers.add(buddy);
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.md,
            AppSpacing.pageX,
            AppSpacing.md,
          ),
          child: AppButton(
            label: 'Create Group',
            icon: Icons.group_add_rounded,
            expanded: true,
            loading: _isLoading,
            onPressed: _isLoading ? null : _createGroup,
          ),
        ),
      ),
    );
  }
}

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({
    required this.user,
    required this.onRemove,
  });

  final EventBuddy user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primarySoft,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.fullName.isNotEmpty
                          ? user.fullName.substring(0, 1).toUpperCase()
                          : '?',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 64,
          child: Text(
            user.fullName.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectableBuddyCard extends StatelessWidget {
  const _SelectableBuddyCard({
    required this.buddy,
    required this.isSelected,
    required this.onToggle,
  });

  final EventBuddy buddy;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      background: isSelected ? AppColors.primarySoft : AppColors.surface,
      onTap: onToggle,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySoft,
            backgroundImage:
                buddy.avatarUrl != null ? NetworkImage(buddy.avatarUrl!) : null,
            child: buddy.avatarUrl == null
                ? Text(
                    buddy.fullName.isNotEmpty
                        ? buddy.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buddy.fullName,
                  style: AppTypography.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${buddy.sharedEventsCount} shared event${buddy.sharedEventsCount > 1 ? 's' : ''}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: isSelected ? AppColors.primary : AppColors.textLight,
          ),
        ],
      ),
    );
  }
}
