import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/providers/events_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _interestsController = TextEditingController();
  bool _networkingVisible = true;
  bool _isSaving = false;
  bool _isUploadingSignature = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.fullName ?? '';
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _bioController.text = user.bio ?? '';
      _interestsController.text = user.interests ?? '';
      _networkingVisible = user.networkingVisible;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateProfile({
        'fullName': _nameController.text,
        if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text,
        'bio': _bioController.text,
        'interests': _interestsController.text,
        'networkingVisible': _networkingVisible,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e,
                fallback: 'Failed to update profile')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _uploadSignature() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploadingSignature = true);

    try {
      final api = ref.read(apiServiceProvider);
      final signatureUrl = await api.uploadImage(
        File(image.path),
        folder: 'signatures',
      );

      await api.updateProfile({
        'signatureUrl': signatureUrl,
      });

      ref.invalidate(currentUserProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.signatureUploaded),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e,
                fallback: 'Failed to upload signature')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingSignature = false);
      }
    }
  }

  Future<void> _removeSignature() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.removeSignature,
      message: 'Are you sure you want to remove your signature?',
      primaryLabel: l10n.removeSignature,
      secondaryLabel: l10n.cancel,
      destructive: true,
      icon: Icons.draw_outlined,
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateProfile({
        'signatureUrl': null,
      });

      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showNotificationPreferences(User? user) async {
    if (user == null) return;

    final l10n = AppLocalizations.of(context)!;
    bool emailNotifications = user.emailNotificationsEnabled;
    bool eventReminders = user.emailEventReminders;

    await AppBottomSheet.show(
      context: context,
      title: l10n.notificationPreferences,
      subtitle: 'Control how reminders and updates reach you.',
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.allMd,
              ),
              child: SwitchListTile(
                value: emailNotifications,
                onChanged: (value) async {
                  setModalState(() => emailNotifications = value);
                  await _updateEmailPreference(
                      'emailNotificationsEnabled', value);
                },
                title: Text(l10n.emailNotifications),
                subtitle: Text(l10n.emailNotificationsDescription),
                secondary: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.allMd,
              ),
              child: SwitchListTile(
                value: eventReminders,
                onChanged: emailNotifications
                    ? (value) async {
                        setModalState(() => eventReminders = value);
                        await _updateEmailPreference(
                            'emailEventReminders', value);
                      }
                    : null,
                title: Text(l10n.eventReminders),
                subtitle: Text(l10n.eventRemindersDescription),
                secondary: const Icon(Icons.alarm_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateEmailPreference(String key, bool value) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateProfile({key: value});
      ref.invalidate(currentUserProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.emailPreferencesUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      primaryLabel: 'Logout',
      secondaryLabel: 'Cancel',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true) {
      ref.invalidate(myFutureRegistrationsProvider);
      ref.invalidate(myFutureEventsProvider);
      ref.invalidate(myPastRegistrationsProvider);
      ref.invalidate(pickedForYouEventsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(eventsProvider);
      ref.invalidate(selectedEventProvider);

      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        backgroundColor: AppColors.background,
        body: Padding(
          padding: AppSpacing.screenPadding,
          child: EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Profile unavailable',
            subtitle:
                'Sign in again to manage your account, tickets and notification preferences.',
            actionLabel: 'Login',
            onAction: () => context.go('/login'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _initializeControllers();
                setState(() => _isEditing = false);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildProfileHero(user),
            const SizedBox(height: AppSpacing.lg),
            _buildProfileFormCard(user, l10n),
            if (user.role == UserRole.organiser) ...[
              const SizedBox(height: AppSpacing.lg),
              _SignatureSection(
                signatureUrl: user.signatureUrl,
                isUploading: _isUploadingSignature,
                onUpload: _uploadSignature,
                onRemove: _removeSignature,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildSettingsCard(user, l10n),
            const SizedBox(height: AppSpacing.xxxl),
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
            AppSpacing.pageY,
          ),
          child: AppCard(
            shadow: AppShadows.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isEditing)
                  AppButton(
                    label: l10n.save,
                    icon: Icons.check_rounded,
                    loading: _isSaving,
                    size: AppButtonSize.lg,
                    expanded: true,
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                if (_isEditing) const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: l10n.logout,
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(User user) {
    return AppCard(
      background: AppColors.primarySoft,
      borderColor: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
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
              if (_isEditing)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Photo upload coming soon!'),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? user.email,
                  style:
                      AppTypography.h2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusChip(
                      label: user.role.name.toUpperCase(),
                      variant: StatusChipVariant.primary,
                    ),
                    if (user.phoneVerified)
                      const StatusChip(
                        label: 'Phone verified',
                        variant: StatusChipVariant.success,
                      ),
                    StatusChip(
                      label: _networkingVisible
                          ? 'Networking visible'
                          : 'Private profile',
                      variant: _networkingVisible
                          ? StatusChipVariant.info
                          : StatusChipVariant.neutral,
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

  Widget _buildProfileFormCard(User user, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal information',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Keep your attendee details accurate so tickets, notifications and networking work correctly.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _nameController,
            label: l10n.fullName,
            prefixIcon: Icons.person_outline_rounded,
            enabled: _isEditing,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterFullName;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _emailController,
            label: l10n.email,
            prefixIcon: Icons.email_outlined,
            enabled: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _phoneController,
            label: l10n.phone,
            prefixIcon: Icons.phone_outlined,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
            suffix: user.phoneVerified
                ? const Icon(Icons.verified_rounded, color: AppColors.success)
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _bioController,
            label: 'Bio',
            hint: 'Tell attendees and organisers a bit about you',
            prefixIcon: Icons.info_outline_rounded,
            enabled: _isEditing,
            maxLines: 4,
            maxLength: 1000,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _interestsController,
            label: 'Interests',
            hint: 'Tech, music, travel, startup, design',
            prefixIcon: Icons.favorite_outline_rounded,
            enabled: _isEditing,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.allMd,
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              title: Text(
                'Networking visibility',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Allow other attendees to discover and connect with you.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              value: _networkingVisible,
              onChanged: _isEditing
                  ? (value) => setState(() => _networkingVisible = value)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(User user, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences & tools',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Access saved items, coupons, waitlist updates and account preferences.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsTile(
            icon: Icons.bookmark_outline_rounded,
            title: l10n.savedEvents,
            onTap: () => context.push('/saved-events'),
          ),
          _SettingsTile(
            icon: Icons.local_offer_outlined,
            title: l10n.myCoupons,
            onTap: () => context.push('/my-coupons'),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: l10n.myQuestions,
            onTap: () => context.push('/my-questions'),
          ),
          _SettingsTile(
            icon: Icons.hourglass_bottom_outlined,
            title: l10n.waitlistOffers,
            onTap: () => context.push('/waitlist-offers'),
          ),
          _LanguageSettingsTile(),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: l10n.notificationPreferences,
            onTap: () => _showNotificationPreferences(user),
          ),
          if (!kIsWeb)
            _SettingsTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan web login QR',
              onTap: () => context.push('/scan-web-login-qr'),
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          borderRadius: AppRadius.allMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.allMd,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: AppColors.textSecondary, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSettingsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);

    String currentLanguage = 'English';
    if (locale?.languageCode == 'vi') {
      currentLanguage = 'Tieng Viet';
    }

    return _SettingsTile(
      icon: Icons.language_rounded,
      title: '${l10n?.language ?? 'Language'} · $currentLanguage',
      onTap: () => _showLanguageDialog(context, ref, l10n),
    );
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, AppLocalizations? l10n) {
    final locale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.language ?? 'Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(l10n?.english ?? 'English'),
              value: 'en',
              groupValue: locale?.languageCode ?? 'en',
              onChanged: (value) {
                ref.read(localeProvider.notifier).setEnglish();
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: Text(l10n?.vietnamese ?? 'Tieng Viet'),
              value: 'vi',
              groupValue: locale?.languageCode ?? 'en',
              onChanged: (value) {
                ref.read(localeProvider.notifier).setVietnamese();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SignatureSection extends StatelessWidget {
  const _SignatureSection({
    required this.signatureUrl,
    required this.isUploading,
    required this.onUpload,
    required this.onRemove,
  });

  final String? signatureUrl;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.draw_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.signature,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.signatureDescription,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (signatureUrl != null)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CachedNetworkImage(
                        imageUrl: signatureUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child:
                              Icon(Icons.error_outline, color: AppColors.error),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.textOnPrimary,
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: onRemove,
                    ),
                  ),
                ],
              )
            else
              InkWell(
                onTap: isUploading ? null : onUpload,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.divider,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: isUploading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 36,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.tapToUploadSignature,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            if (signatureUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onUpload,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 18),
                  label: Text(l10n.uploadSignature),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
