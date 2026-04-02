import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
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
    debugPrint('Fetched ${events.length} featured events');
    for (final e in events) {
      debugPrint('Event: ${e.title}, imageUrl: ${e.imageUrl}');
    }
    return events;
  } catch (e, stack) {
    debugPrint('Error fetching featured events: $e');
    debugPrint('Stack: $stack');
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
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: Colors.white,
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

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Column(
                      children: [
                        Text(
                          'luma',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.delightfulEvents,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.2,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF1744)],
                          ).createShader(bounds),
                          child: Text(
                            l10n.startHere,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.loginDescription,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _showEmailForm
                    ? _buildEmailForm(isLoading)
                    : _buildAuthButtons(isLoading),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text.rich(
                  TextSpan(
                    text: "By continuing, you agree to Luma's ",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    children: const [
                      TextSpan(
                        text: 'Terms of Use',
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),
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
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _showEmailForm = true;
                      _isLoginMode = true;
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              l10n.continueWithEmail,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _showEmailForm = true;
                      _isLoginMode = false;
                    });
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.createAccount,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () {
                    ref.read(authProvider.notifier).signInWithGoogle();
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.grey[300]!, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.google.com/favicon.ico',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
              onPressed: () {
                setState(() {
                  _showEmailForm = false;
                });
              },
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _isLoginMode ? l10n.signIn : l10n.createAccount,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          if (!_isLoginMode) ...[
            TextFormField(
              controller: _fullNameController,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: l10n.fullName,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterFullName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: l10n.email,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterEmail;
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return l10n.pleaseEnterValidEmail;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: l10n.password,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterPassword;
              }
              if (!_isLoginMode) {
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (!RegExp(r'[A-Z]').hasMatch(value)) {
                  return 'Must contain at least one uppercase letter';
                }
                if (!RegExp(r'[a-z]').hasMatch(value)) {
                  return 'Must contain at least one lowercase letter';
                }
                if (!RegExp(r'[0-9]').hasMatch(value)) {
                  return 'Must contain at least one digit';
                }
                if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"|\\,.<>/?]').hasMatch(value)) {
                  return 'Must contain at least one special character (!@#\$%...)';
                }
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleEmailAuth(),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleEmailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isLoginMode ? l10n.signIn : l10n.signUp,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLoginMode
                    ? l10n.dontHaveAccount
                    : l10n.alreadyHaveAccount,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: Text(
                  _isLoginMode ? l10n.signUp : l10n.signIn,
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
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
}

class _EventCarousel extends StatelessWidget {
  const _EventCarousel({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EventCarouselPlaceholder();
    }

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
              colors: [
                Colors.grey[100]!,
                Colors.white,
              ],
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: event.imageUrl != null && event.imageUrl!.isNotEmpty
              ? Image.network(
                  event.imageUrl!,
                  width: 160,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildPlaceholderCard(event, position);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Image load error: $error');
                    return _buildPlaceholderCard(event, position);
                  },
                )
              : _buildPlaceholderCard(event, position),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(Event event, int index) {
    final colors = [
      [const Color(0xFFFF6B9D), const Color(0xFFC44569)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFFFA726), const Color(0xFFFF7043)],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.organiserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
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
              colors: [
                Colors.grey[100]!,
                Colors.white,
              ],
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
      [const Color(0xFFFF6B9D), const Color(0xFFC44569)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFFFA726), const Color(0xFFFF7043)],
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
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors[index % colors.length],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}
