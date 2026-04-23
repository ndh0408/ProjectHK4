import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/web_login_qr_scanner_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/bookmarks/presentation/screens/saved_events_screen.dart';
import '../../features/coupons/presentation/screens/my_coupons_screen.dart';
import '../../features/questions/presentation/screens/my_questions_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/payment_cancelled_screen.dart';
import '../../features/events/presentation/screens/payment_success_screen.dart';
import '../../features/events/presentation/screens/speaker_events_screen.dart';
import '../../features/events/presentation/screens/ticket_screen.dart';
import '../../features/events/presentation/screens/write_review_screen.dart';
import '../../features/events/presentation/screens/qr_scanner_screen.dart';
import '../../features/events/presentation/screens/registration_form_screen.dart';
import '../../features/explore/presentation/screens/categories_screen.dart';
import '../../features/explore/presentation/screens/cities_screen.dart';
import '../../features/explore/presentation/screens/events_list_screen.dart';
import '../../features/explore/presentation/screens/explore_screen.dart';
import '../../features/explore/presentation/screens/organiser_profile_screen.dart';
import '../../features/explore/presentation/screens/organisers_screen.dart';
import '../../features/explore/presentation/screens/search_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/main/presentation/screens/main_shell.dart';
import '../../features/my_events/presentation/screens/my_events_screen.dart';
import '../../features/notifications/presentation/screens/luma_notifications_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/chatbot_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/event_buddies_screen.dart';
import '../../features/chat/presentation/screens/create_group_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/chat/presentation/screens/discover_networking_screen.dart';
import '../../features/events/presentation/screens/event_polls_screen.dart';
import '../../features/events/presentation/screens/event_schedule_screen.dart';
import '../../features/explore/presentation/screens/event_comparison_screen.dart';
import '../../features/gallery/presentation/screens/gallery_screen.dart';
import '../../features/notifications/presentation/screens/waitlist_offers_screen.dart';
import '../../shared/models/conversation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState is Authenticated;
      final isPending = authState is PendingEmailVerification;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isOnOtp = location == '/verify-otp';

      // Transient states — don't reshuffle the user mid-flight. AuthError in
      // particular flashes briefly before clearError resolves it, and
      // redirecting on that flash boots the OTP screen to /login.
      if (authState is AuthInitial ||
          authState is AuthLoading ||
          authState is AuthError) {
        return null;
      }

      if (isPending && !isOnOtp) {
        return '/verify-otp';
      }

      if (!isPending && isOnOtp) {
        return isAuthenticated ? '/home' : '/login';
      }

      if (!isAuthenticated && !isLoggingIn && !isOnOtp) {
        return '/login';
      }

      if (isAuthenticated && isLoggingIn) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/scan-web-login-qr',
        name: 'scan-web-login-qr',
        builder: (context, state) => const WebLoginQrScannerScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) {
              final auth = authState;
              final userId = auth is Authenticated ? auth.user.id : '';
              return HomeScreen(key: ValueKey('home_$userId'));
            },
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/my-events',
            name: 'my-events',
            builder: (context, state) {
              final auth = authState;
              final userId = auth is Authenticated ? auth.user.id : '';
              return MyEventsScreen(key: ValueKey('my_events_$userId'));
            },
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) {
              final auth = authState;
              final userId = auth is Authenticated ? auth.user.id : '';
              return LumaNotificationsScreen(
                key: ValueKey('notifications_$userId'),
              );
            },
          ),
          GoRoute(
            path: '/luma-notifications',
            name: 'luma-notifications',
            builder: (context, state) => const LumaNotificationsScreen(),
          ),
          GoRoute(
            path: '/conversations',
            name: 'conversations',
            builder: (context, state) => const ConversationsScreen(),
          ),
          GoRoute(
            path: '/chat/:id',
            name: 'chat',
            builder: (context, state) {
              final conversationId = state.pathParameters['id'] ?? '';
              final conversation = state.extra as Conversation?;
              return ChatScreen(
                conversationId: conversationId,
                conversation: conversation,
              );
            },
          ),
          GoRoute(
            path: '/chatbot',
            name: 'chatbot',
            builder: (context, state) => const ChatbotScreen(),
          ),
          GoRoute(
            path: '/event-buddies',
            name: 'event-buddies',
            builder: (context, state) => const EventBuddiesScreen(),
          ),
          GoRoute(
            path: '/networking',
            name: 'networking',
            builder: (context, state) => const DiscoverNetworkingScreen(),
          ),
          GoRoute(
            path: '/create-group',
            name: 'create-group',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) {
              final auth = authState;
              final userId = auth is Authenticated ? auth.user.id : '';
              return ProfileScreen(key: ValueKey('profile_$userId'));
            },
          ),
          GoRoute(
            path: '/profile/:userId',
            name: 'user-profile',
            builder: (context, state) {
              final requestedUserId = state.pathParameters['userId'] ?? '';
              final auth = authState;
              final currentUserId = auth is Authenticated ? auth.user.id : '';
              if (requestedUserId.isEmpty || requestedUserId == currentUserId) {
                return ProfileScreen(key: ValueKey('profile_$currentUserId'));
              }
              return UserProfileScreen(
                key: ValueKey('user_profile_$requestedUserId'),
                userId: requestedUserId,
              );
            },
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              return SearchScreen(query: query);
            },
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/cities',
            name: 'cities',
            builder: (context, state) => const CitiesScreen(),
          ),
          GoRoute(
            path: '/organisers',
            name: 'organisers',
            builder: (context, state) => const OrganisersScreen(),
          ),
          GoRoute(
            path: '/gallery',
            name: 'gallery',
            builder: (context, state) => const GalleryScreen(),
          ),
          GoRoute(
            path: '/event/:id',
            name: 'event-detail',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              return EventDetailScreen(eventId: eventId);
            },
          ),
          GoRoute(
            path: '/event/:id/register',
            name: 'event-register',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final isFree = extra['isFree'] as bool? ?? true;
              final ticketPrice = extra['ticketPrice'] as double?;
              final ticketTypeId = extra['ticketTypeId'] as String?;
              final ticketTypeName = extra['ticketTypeName'] as String?;
              final quantity = extra['quantity'] as int? ?? 1;
              final eventTitle = extra['eventTitle'] as String? ?? 'Event';
              return RegistrationFormScreen(
                eventId: eventId,
                eventTitle: eventTitle,
                isFree: isFree,
                ticketPrice: ticketPrice,
                ticketTypeId: ticketTypeId,
                ticketTypeName: ticketTypeName,
                quantity: quantity,
              );
            },
          ),
          GoRoute(
            path: '/ticket',
            name: 'ticket',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return TicketScreen(
                eventName: extra['eventName'] ?? 'Event',
                ticketId: extra['ticketId'] ?? '',
                userName: extra['userName'] ?? '',
                eventTime: extra['eventTime'] ?? '',
                eventLocation: extra['eventLocation'] ?? '',
                registrationId: extra['registrationId'] as String?,
                checkedInAt: extra['checkedInAt'] as DateTime?,
                isTransferable: extra['isTransferable'] as bool? ?? false,
              );
            },
          ),
          GoRoute(
            path: '/events',
            name: 'events',
            builder: (context, state) {
              final categoryId =
                  int.tryParse(state.uri.queryParameters['categoryId'] ?? '');
              final cityId =
                  int.tryParse(state.uri.queryParameters['cityId'] ?? '');
              return EventsListScreen(categoryId: categoryId, cityId: cityId);
            },
          ),
          GoRoute(
            path: '/organiser/:id',
            name: 'organiser-profile',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return OrganiserProfileScreen(organiserId: id);
            },
          ),
          GoRoute(
            path: '/speaker-events',
            name: 'speaker-events',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return SpeakerEventsScreen(
                speakerName: extra['speakerName'] ?? '',
                speakerTitle: extra['speakerTitle'],
                speakerImageUrl: extra['speakerImageUrl'],
                speakerBio: extra['speakerBio'],
              );
            },
          ),
          GoRoute(
            path: '/payment-success',
            name: 'payment-success',
            builder: (context, state) {
              final registrationId =
                  state.uri.queryParameters['registration_id'];
              return PaymentSuccessScreen(registrationId: registrationId);
            },
          ),
          GoRoute(
            path: '/payment-cancelled',
            name: 'payment-cancelled',
            builder: (context, state) {
              final registrationId =
                  state.uri.queryParameters['registration_id'];
              return PaymentCancelledScreen(registrationId: registrationId);
            },
          ),
          GoRoute(
            path: '/event/:id/write-review',
            name: 'write-review',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final eventTitle = extra['eventTitle'] as String? ?? 'Event';
              return WriteReviewScreen(
                eventId: eventId,
                eventTitle: eventTitle,
              );
            },
          ),
          GoRoute(
            path: '/event/:id/scan-checkin',
            name: 'scan-checkin',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final eventTitle = extra['eventTitle'] as String? ?? 'Event';
              return QrScannerScreen(
                eventId: eventId,
                eventTitle: eventTitle,
              );
            },
          ),
          GoRoute(
            path: '/saved-events',
            name: 'saved-events',
            builder: (context, state) => const SavedEventsScreen(),
          ),
          GoRoute(
            path: '/my-questions',
            name: 'my-questions',
            builder: (context, state) => const MyQuestionsScreen(),
          ),
          GoRoute(
            path: '/waitlist-offers',
            name: 'waitlist-offers',
            builder: (context, state) => const WaitlistOffersScreen(),
          ),
          GoRoute(
            path: '/my-coupons',
            name: 'my-coupons',
            builder: (context, state) => const MyCouponsScreen(),
          ),
          GoRoute(
            path: '/event/:id/schedule',
            name: 'event-schedule',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return EventScheduleScreen(
                  eventId: eventId,
                  eventTitle: extra['eventTitle'] as String? ?? 'Event');
            },
          ),
          GoRoute(
            path: '/compare-events',
            name: 'compare-events',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final ids = (extra['eventIds'] as List<dynamic>?)?.cast<String>();
              return EventComparisonScreen(eventIds: ids);
            },
          ),
          GoRoute(
            path: '/event/:id/polls',
            name: 'event-polls',
            builder: (context, state) {
              final eventId = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final eventTitle = extra['eventTitle'] as String? ?? 'Event';
              return EventPollsScreen(eventId: eventId, eventTitle: eventTitle);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
