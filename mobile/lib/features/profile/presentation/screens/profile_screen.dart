import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/user.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/providers/events_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';
import '../../../my_events/presentation/screens/my_events_screen.dart';
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

  Future<void> _verifyPhone() async {
    final user = ref.read(currentUserProvider);
    if (user?.phone == null || user!.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a phone number first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final otpController = TextEditingController();
    bool isSending = false;
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Verify Phone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('We will send an OTP to ${user.phone}'),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  hintText: '000000',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isSending
                  ? null
                  : () async {
                      setDialogState(() => isSending = true);
                      try {
                        final api = ref.read(apiServiceProvider);
                        await api.sendOtp(phone: user.phone!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('OTP sent successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorUtils.extractMessage(e)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isSending = false);
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send OTP'),
            ),
            ElevatedButton(
              onPressed: isVerifying || otpController.text.length != 6
                  ? null
                  : () async {
                      setDialogState(() => isVerifying = true);
                      try {
                        final api = ref.read(apiServiceProvider);
                        await api.verifyOtp(
                          phone: user.phone!,
                          otp: otpController.text,
                        );
                        if (context.mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Phone verified successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          ref.invalidate(currentUserProvider);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorUtils.extractMessage(e)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isVerifying = false);
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
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
            content: Text(ErrorUtils.extractMessage(e, fallback: 'Failed to update profile')),
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
            content: Text(ErrorUtils.extractMessage(e, fallback: 'Failed to upload signature')),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeSignature),
        content: const Text('Are you sure you want to remove your signature?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.removeSignature),
          ),
        ],
      ),
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

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notificationPreferences,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                value: emailNotifications,
                onChanged: (value) async {
                  setModalState(() => emailNotifications = value);
                  await _updateEmailPreference('emailNotificationsEnabled', value);
                },
                title: Text(l10n.emailNotifications),
                subtitle: Text(l10n.emailNotificationsDescription),
                secondary: const Icon(Icons.email_outlined),
              ),
              SwitchListTile(
                value: eventReminders,
                onChanged: emailNotifications
                    ? (value) async {
                        setModalState(() => eventReminders = value);
                        await _updateEmailPreference('emailEventReminders', value);
                      }
                    : null,
                title: Text(l10n.eventReminders),
                subtitle: Text(l10n.eventRemindersDescription),
                secondary: const Icon(Icons.alarm_outlined),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _initializeControllers();
                setState(() => _isEditing = false);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: user?.avatarUrl != null
                          ? CachedNetworkImageProvider(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? Text(
                              (user?.fullName?.isNotEmpty ?? false)
                                  ? user!.fullName![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 48),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            color: AppColors.textOnPrimary,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Photo upload coming soon!'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.pleaseEnterFullName;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                enabled: false,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: l10n.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: user?.phoneVerified == true
                      ? const Icon(Icons.verified, color: AppColors.success)
                      : user?.phone != null && user!.phone!.isNotEmpty
                          ? TextButton(
                              onPressed: _isEditing ? null : _verifyPhone,
                              child: const Text('Verify'),
                            )
                          : null,
                ),
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell others about yourself',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                enabled: _isEditing,
                maxLines: 3,
                maxLength: 1000,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _interestsController,
                decoration: const InputDecoration(
                  labelText: 'Interests',
                  hintText: 'tech, music, travel (comma separated)',
                  prefixIcon: Icon(Icons.favorite_outline),
                ),
                enabled: _isEditing,
                maxLength: 500,
              ),

              const SizedBox(height: 8),

              SwitchListTile(
                title: const Text('Networking Visibility'),
                subtitle: const Text('Allow others to discover and connect with you'),
                value: _networkingVisible,
                onChanged: _isEditing
                    ? (value) => setState(() => _networkingVisible = value)
                    : null,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              if (user != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (user?.role == UserRole.organiser) ...[
                const SizedBox(height: 24),
                _SignatureSection(
                  signatureUrl: user?.signatureUrl,
                  isUploading: _isUploadingSignature,
                  onUpload: _uploadSignature,
                  onRemove: _removeSignature,
                ),
              ],

              if (_isEditing) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : Text(l10n.save),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              _SettingsTile(
                icon: Icons.bookmark_outline,
                title: l10n.savedEvents,
                onTap: () => context.push('/saved-events'),
              ),
              _LanguageSettingsTile(),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: l10n.notificationPreferences,
                onTap: () => _showNotificationPreferences(user),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: Text(
                    l10n.logout,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
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
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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

    return ListTile(
      leading: const Icon(Icons.language, color: AppColors.textSecondary),
      title: Text(l10n?.language ?? 'Language'),
      subtitle: Text(currentLanguage),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(context, ref, l10n),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, AppLocalizations? l10n) {
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: signatureUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.error_outline, color: AppColors.error),
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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
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
