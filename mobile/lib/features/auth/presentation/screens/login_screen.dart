import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/providers/events_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../domain/auth_state.dart';
import '../../providers/auth_provider.dart';

final featuredEventsProvider = FutureProvider<List<Event>>((ref) async {
  try {
    final apiService = ref.watch(apiServiceProvider);
    final events = await apiService.getFeaturedEvents(size: 3);
    return events;
  } catch (e) {
    return [];
  }
});

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoginMode = true;
  bool _showEmailForm = false;
  // Tracks which path triggered the shared AuthLoading state so we only
  // surface the spinner on the button the user actually tapped.
  bool _googleInFlight = false;
  bool _emailInFlight = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _emailInFlight = true);
    try {
      if (_isLoginMode) {
        await ref.read(authProvider.notifier).login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      } else {
        await ref.read(authProvider.notifier).register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _fullNameController.text.trim(),
            );
      }
    } finally {
      if (mounted) setState(() => _emailInFlight = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _googleInFlight = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } finally {
      if (mounted) setState(() => _googleInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final featuredEvents = ref.watch(featuredEventsProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is Authenticated) {
        ref.invalidate(myFutureRegistrationsProvider);
        ref.invalidate(myFutureEventsProvider);
        ref.invalidate(myPastRegistrationsProvider);
        ref.invalidate(pickedForYouEventsProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(selectedEventProvider);
        context.go('/home');
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 332,
                child: featuredEvents.when(
                  data: (events) => _EventCarousel(events: events),
                  loading: () => const _EventCarouselPlaceholder(),
                  error: (_, __) => const _EventCarouselPlaceholder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Padding(
                padding: AppSpacing.screenPadding.copyWith(top: 0),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LUMA',
                          style: AppTypography.overline.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${l10n.delightfulEvents}\n${l10n.startHere}',
                          style: AppTypography.display.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.loginDescription,
                          style: AppTypography.bodyLg.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: const [
                            _ValuePill(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Tickets & QR ready',
                            ),
                            _ValuePill(
                              icon: Icons.flash_on_rounded,
                              label: 'Fast booking flow',
                            ),
                            _ValuePill(
                              icon: Icons.verified_user_outlined,
                              label: 'Trusted checkout',
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
                child: _showEmailForm
                    ? _buildEmailForm(isLoading)
                    : _buildAuthButtons(isLoading),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
                child: Text.rich(
                  TextSpan(
                    text: "By continuing, you agree to Luma's ",
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Terms of Use',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButtons(bool isLoading) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose how you want to continue',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sign in to manage bookings, tickets, notifications and check-ins in one place.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.continueWithEmail,
            onPressed: isLoading
                ? null
                : () => setState(() {
                      _showEmailForm = true;
                      _isLoginMode = true;
                    }),
            size: AppButtonSize.lg,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.createAccount,
            onPressed: isLoading
                ? null
                : () => setState(() {
                      _showEmailForm = true;
                      _isLoginMode = false;
                    }),
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.lg,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Continue with Google',
            onPressed: isLoading ? null : _handleGoogleAuth,
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.lg,
            expanded: true,
            icon: Icons.g_mobiledata_rounded,
            loading: _googleInFlight,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _showEmailForm = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _isLoginMode ? l10n.signIn : l10n.createAccount,
                    style:
                        AppTypography.h2.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSegmentedControl<bool>(
              value: _isLoginMode,
              items: [
                AppSegmentItem(value: true, label: l10n.signIn),
                AppSegmentItem(value: false, label: l10n.signUp),
              ],
              onChanged: (value) => setState(() => _isLoginMode = value),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_isLoginMode) ...[
              AppTextField(
                controller: _fullNameController,
                label: l10n.fullName,
                keyboardType: TextInputType.name,
                enabled: !isLoading,
                required: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.pleaseEnterFullName;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              controller: _emailController,
              label: l10n.email,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              required: true,
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.pleaseEnterEmail;
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return l10n.pleaseEnterValidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _passwordController,
              label: l10n.password,
              enabled: !isLoading,
              obscureText: _obscurePassword,
              required: true,
              onSubmitted: (_) => _handleEmailAuth(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textLight,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.pleaseEnterPassword;
                if (!_isLoginMode && v.length < 6) return l10n.passwordTooShort;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isLoginMode ? l10n.signIn : l10n.signUp,
              onPressed: isLoading ? null : _handleEmailAuth,
              loading: _emailInFlight,
              size: AppButtonSize.lg,
              expanded: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => setState(() => _isLoginMode = !_isLoginMode),
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: _isLoginMode
                            ? 'Need an account? '
                            : 'Already have an account? ',
                      ),
                      TextSpan(
                        text: _isLoginMode ? l10n.signUp : l10n.signIn,
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCarousel extends StatelessWidget {
  const _EventCarousel({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const _EventCarouselPlaceholder();

    final displayEvents = events.take(3).toList();

    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1120), Color(0xFF123FB1)],
            ),
          ),
        ),
        PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          itemCount: displayEvents.length,
          itemBuilder: (context, index) =>
              _buildEventCard(displayEvents[index]),
        ),
      ],
    );
  }

  Widget _buildEventCard(Event event) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.allXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            event.imageUrl != null && event.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: event.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildPlaceholderCard(event),
                  )
                : _buildPlaceholderCard(event),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(
                    label: event.category?.name ?? 'Featured event',
                    variant: StatusChipVariant.primary,
                  ),
                  const Spacer(),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    event.organiserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textOnPrimary70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(Event event) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h2.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.organiserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textOnPrimary70),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCarouselPlaceholder extends StatelessWidget {
  const _EventCarouselPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      itemBuilder: (_, __) => Container(
        width: MediaQuery.of(context).size.width * 0.88,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.allXl,
          color: AppColors.shimmerBase,
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allPill,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
