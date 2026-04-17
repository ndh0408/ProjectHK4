import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/providers/events_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';
import '../../../my_events/presentation/screens/my_events_screen.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 280,
                child: featuredEvents.when(
                  data: (events) => _EventCarousel(events: events),
                  loading: () => const _EventCarouselPlaceholder(),
                  error: (_, __) => const _EventCarouselPlaceholder(),
                ),
              ),
              AppSpacing.gapXxxl,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Column(
                      children: [
                        Text(
                          'luma',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AppSpacing.gapSm,
                        Text(
                          l10n.delightfulEvents,
                          style: AppTypography.display.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                          ).createShader(bounds),
                          child: Text(
                            l10n.startHere,
                            style: AppTypography.display.copyWith(
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        AppSpacing.gapLg,
                        Text(
                          l10n.loginDescription,
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              AppSpacing.gapXxxl,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: _showEmailForm
                    ? _buildEmailForm(isLoading)
                    : _buildAuthButtons(isLoading),
              ),
              AppSpacing.gapXxl,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text.rich(
                  TextSpan(
                    text: "By continuing, you agree to Luma's ",
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Terms of Use',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              AppSpacing.gapXxl,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButtons(bool isLoading) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
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
        AppSpacing.gapMd,
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
        AppSpacing.gapLg,
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () => ref.read(authProvider.notifier).signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.google.com/favicon.ico',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => Text(
                          'G',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      AppSpacing.hgapMd,
                      Text(
                        'Continue with Google',
                        style: AppTypography.button.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => setState(() => _showEmailForm = false),
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          AppSpacing.gapLg,
          Text(
            _isLoginMode ? l10n.signIn : l10n.createAccount,
            style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
          ),
          AppSpacing.gapXxl,
          if (!_isLoginMode) ...[
            _buildFilledInput(
              controller: _fullNameController,
              label: l10n.fullName,
              keyboardType: TextInputType.name,
              enabled: !isLoading,
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.pleaseEnterFullName;
                return null;
              },
            ),
            AppSpacing.gapLg,
          ],
          _buildFilledInput(
            controller: _emailController,
            label: l10n.email,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.pleaseEnterEmail;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return l10n.pleaseEnterValidEmail;
              }
              return null;
            },
          ),
          AppSpacing.gapLg,
          _buildFilledInput(
            controller: _passwordController,
            label: l10n.password,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            onSubmitted: (_) => _handleEmailAuth(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textLight,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.pleaseEnterPassword;
              if (!_isLoginMode && v.length < 6) return l10n.passwordTooShort;
              return null;
            },
          ),
          AppSpacing.gapXxl,
          AppButton(
            label: _isLoginMode ? l10n.signIn : l10n.signUp,
            onPressed: isLoading ? null : _handleEmailAuth,
            loading: isLoading,
            size: AppButtonSize.lg,
            expanded: true,
          ),
          AppSpacing.gapLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLoginMode ? l10n.dontHaveAccount : l10n.alreadyHaveAccount,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.hgapXs,
              GestureDetector(
                onTap: () => setState(() => _isLoginMode = !_isLoginMode),
                child: Text(
                  _isLoginMode ? l10n.signUp : l10n.signIn,
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilledInput({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool enabled = true,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      enabled: enabled,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        suffixIcon: suffixIcon,
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

    final List<Event> displayEvents = [];
    if (events.length == 1) {
      displayEvents.addAll([events[0], events[0], events[0]]);
    } else if (events.length == 2) {
      displayEvents.addAll([events[0], events[1], events[0]]);
    } else {
      displayEvents.addAll(events.take(3));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceVariant, AppColors.surface],
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildEventCard(displayEvents[0], 0),
              _buildEventCard(displayEvents[2], 2),
              _buildEventCard(displayEvents[1], 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Event event, int position) {
    final double offsetX = (position - 1) * 90.0;
    final double offsetY = position == 1 ? 0 : 25.0;
    final double rotation = (position - 1) * 0.12;
    final double scale = position == 1 ? 1.0 : 0.85;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(rotation)
        ..translate(offsetX, offsetY)
        ..scale(scale),
      child: Container(
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: AppRadius.allLg,
          boxShadow: AppShadows.lg,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.allLg,
          child: event.imageUrl != null && event.imageUrl!.isNotEmpty
              ? Image.network(
                  event.imageUrl!,
                  width: 160,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : _buildPlaceholderCard(event, position),
                  errorBuilder: (_, __, ___) => _buildPlaceholderCard(event, position),
                )
              : _buildPlaceholderCard(event, position),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(Event event, int index) {
    final colors = [
      [AppColors.primary, AppColors.secondary],
      [AppColors.primary, AppColors.primaryDark],
      [AppColors.secondary, AppColors.accent],
    ];

    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[index % colors.length],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.gapXs,
            Text(
              event.organiserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: AppColors.textOnPrimary70),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceVariant, AppColors.surface],
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++) _buildPlaceholderCard(i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard(int index) {
    final double offsetX = (index - 1) * 100.0;
    final double offsetY = index == 1 ? 0 : 30.0;
    final double rotation = (index - 1) * 0.15;
    final double scale = index == 1 ? 1.0 : 0.85;

    final colors = [
      [AppColors.primary, AppColors.secondary],
      [AppColors.primary, AppColors.primaryDark],
      [AppColors.secondary, AppColors.accent],
    ];

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(rotation)
        ..translate(offsetX, offsetY)
        ..scale(scale),
      child: Container(
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: AppRadius.allLg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors[index % colors.length],
          ),
          boxShadow: AppShadows.lg,
        ),
      ),
    );
  }
}
