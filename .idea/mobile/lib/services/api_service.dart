import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/client.dart';
import '../shared/models/category.dart';
import '../shared/models/chat_message.dart';
import '../shared/models/city.dart';
import '../shared/models/conversation.dart';
import '../shared/models/event.dart';
import '../shared/models/notification.dart';
import '../shared/models/organiser_profile.dart';
import '../shared/models/certificate.dart';
import '../shared/models/question.dart';
import '../shared/models/registration.dart';
import '../shared/models/review.dart';
import '../shared/models/registration_question.dart';
import '../shared/models/user.dart';
import '../shared/models/event_image.dart';
import '../shared/models/event_buddy.dart';
import '../shared/models/blocked_user.dart';
import '../shared/models/coupon.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiService(client);
});

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PaginatedResponse<T>(
      content: (json['content'] as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      number: json['page'] as int? ?? json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 10,
    );
  }

  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;

  bool get hasMore => number < totalPages - 1;
}

class ApiService {
  ApiService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
  }

  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    return _client.post<Map<String, dynamic>>(
      '/auth/send-otp',
      queryParameters: {'phone': phone},
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return _client.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      queryParameters: {'phone': phone, 'otp': otp},
    );
  }

  Future<User> getCurrentUser() async {
    final response = await _client.getRaw<Map<String, dynamic>>('/user/profile');
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return User.fromJson(data);
  }

  Future<List<Event>> getFeaturedEvents({int size = 3}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/events/featured',
      queryParameters: {'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Event>> getBoostedFeaturedEvents() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/events/boosted/featured',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Event>> getHomeBannerEvents() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/events/boosted/banner',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PaginatedResponse<Event>> getEvents({
    int page = 0,
    int size = 10,
    String? categoryId,
    String? cityId,
    String? search,
    bool? upcoming,
  }) async {
    String endpoint = '/user/events/upcoming';
    if (search != null && search.isNotEmpty) {
      endpoint = '/user/events/search';
    } else if (cityId != null) {
      endpoint = '/user/events/by-city/$cityId';
    } else if (categoryId != null) {
      endpoint = '/user/events/by-category/$categoryId';
    }

    final response = await _client.getRaw<Map<String, dynamic>>(
      endpoint,
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<PaginatedResponse<Event>> getSuggestedEvents({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/upcoming',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<PaginatedResponse<Event>> getUpcomingEvents({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/upcoming',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<PaginatedResponse<Event>> getPickedForYouEvents({
    int page = 0,
    int size = 50,
    String? country,
  }) async {
    String endpoint = '/user/events/upcoming';
    if (country != null) {
      endpoint = '/user/events/by-country/$country';
    }
    final response = await _client.getRaw<Map<String, dynamic>>(
      endpoint,
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<Event> getEventById(String id) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$id',
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return Event.fromJson(data);
  }

  Future<PaginatedResponse<Registration>> getMyRegistrations({
    int page = 0,
    int size = 20,
    required bool upcoming,
  }) async {
    final endpoint = upcoming
        ? '/user/events/my-registrations/upcoming'
        : '/user/events/my-registrations/past';
    final response = await _client.getRaw<Map<String, dynamic>>(
      endpoint,
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Registration.fromJson);
  }

  Future<Registration> registerForEvent(String eventId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/events/$eventId/register',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
  }

  Future<RegistrationStatus> getRegistrationStatus(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$eventId/registration-status',
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? {};
    return RegistrationStatus.fromJson(data);
  }

  Future<List<RegistrationQuestion>> getRegistrationQuestions(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$eventId/registration-questions',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => RegistrationQuestion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Registration> registerForEventWithAnswers(
    String eventId,
    List<RegistrationAnswer> answers,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/events/$eventId/register-with-answers',
      data: {
        'answers': answers.map((a) => a.toJson()).toList(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
  }

  Future<void> cancelRegistration(String registrationId) async {
    await _client.delete('/user/events/registrations/$registrationId');
  }

  Future<void> trackEventView(String eventId) async {
    try {
      await _client.post<Map<String, dynamic>>('/user/events/$eventId/track-view');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getEventPolls(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/polls/event/$eventId/all',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getActiveEventPolls(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/polls/event/$eventId',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> votePoll(String pollId, {List<String>? optionIds, int? ratingValue}) async {
    final body = <String, dynamic>{};
    if (optionIds != null) body['optionIds'] = optionIds;
    if (ratingValue != null) body['ratingValue'] = ratingValue;
    final response = await _client.post<Map<String, dynamic>>(
      '/user/polls/$pollId/vote',
      data: body,
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<List<Map<String, dynamic>>> discoverNetworking({int page = 0, int size = 20}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/networking/discover',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendConnectionRequest(String userId, {String? message}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/networking/connect/$userId',
      data: message != null ? {'message': message} : {},
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> acceptConnectionRequest(String requestId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/networking/requests/$requestId/accept',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> declineConnectionRequest(String requestId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/networking/requests/$requestId/decline',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> getPendingConnectionRequests({int page = 0}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/networking/requests/pending',
      queryParameters: {'page': page, 'size': 20},
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getConnections({int page = 0}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/networking/connections',
      queryParameters: {'page': page, 'size': 20},
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> validateCoupon(String code, double amount, String registrationId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/coupons/validate',
      queryParameters: {'code': code, 'amount': amount, 'registrationId': registrationId},
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<Coupon>> getUserCoupons({String? eventId}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/coupons',
      queryParameters: eventId != null ? {'eventId': eventId} : null,
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((json) => Coupon.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> compareEvents(List<String> eventIds) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/event-comparison/compare',
      queryParameters: {'eventIds': eventIds},
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> getSeatMap(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/seat-map/event/$eventId',
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> lockSeats(List<String> seatIds) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/seat-map/lock',
      data: {'seatIds': seatIds},
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> getEventSchedule(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/schedule/event/$eventId',
    );
    return response.data!['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> registerForSession(String sessionId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/schedule/sessions/$sessionId/register',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<List<Map<String, dynamic>>> getMyEventSchedule(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/schedule/event/$eventId/my-schedule',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> transferTicket(String registrationId, String toEmail) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/transfers/$registrationId/transfer',
      data: {'toEmail': toEmail},
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<List<Map<String, dynamic>>> getResaleListings(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/transfers/event/$eventId/resale',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getWaitlistOffers() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/waitlist/offers',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acceptWaitlistOffer(String offerId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/waitlist/offers/$offerId/accept',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> declineWaitlistOffer(String offerId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/waitlist/offers/$offerId/decline',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> initiatePayment(String registrationId, {String? couponCode}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/payment-intent',
      queryParameters: couponCode != null && couponCode.isNotEmpty
          ? {'couponCode': couponCode}
          : null,
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> confirmPayment(String registrationId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/confirm-payment',
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> getPaymentStatus(String registrationId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/payment-status',
    );
    return response.data!['data'] as Map<String, dynamic>? ?? response.data!;
  }

  Future<Map<String, dynamic>> createCheckoutSession(String registrationId, {String? couponCode}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/checkout-session',
      queryParameters: couponCode != null && couponCode.isNotEmpty
          ? {'couponCode': couponCode}
          : null,
    );
    return response['data'] as Map<String, dynamic>? ?? response;
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String registrationId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/payment-status',
    );
    return response.data!['data'] as Map<String, dynamic>? ?? response.data!;
  }

  Future<List<Category>> getCategories() async {
    final response = await _client.getRaw<Map<String, dynamic>>('/categories');
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => Category.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _client.getRaw<Map<String, dynamic>>('/cities/with-events');
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => City.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Map<String, List<City>>> getCitiesByContinent() async {
    final response = await _client.getRaw<Map<String, dynamic>>('/cities/by-continent');
    final data = response.data!['data'] as Map<String, dynamic>? ?? {};
    return data.map((key, value) {
      final cities = (value as List<dynamic>)
          .map((item) => City.fromJson(item as Map<String, dynamic>))
          .toList();
      return MapEntry(key, cities);
    });
  }

  Future<List<OrganiserProfile>> getFeaturedOrganisers() async {
    final response = await _client.getRaw<Map<String, dynamic>>('/user/follow/featured');
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => OrganiserProfile.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<OrganiserProfile> getOrganiserProfile(String id) async {
    final response = await _client.getRaw<Map<String, dynamic>>('/user/organisers/$id');
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return OrganiserProfile.fromJson(data);
  }

  Future<PaginatedResponse<Event>> getOrganiserEvents(String organiserId, {int page = 0, int size = 50}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/organisers/$organiserId/events',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<void> followOrganiser(String organiserId) async {
    await _client.post<void>('/user/follow/$organiserId');
  }

  Future<void> unfollowOrganiser(String organiserId) async {
    await _client.delete('/user/follow/$organiserId');
  }

  Future<bool> isFollowingOrganiser(String organiserId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/follow/check/$organiserId',
    );
    return response.data!['data'] as bool? ?? false;
  }

  Future<PaginatedResponse<AppNotification>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/notifications',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, AppNotification.fromJson);
  }

  Future<void> markNotificationAsRead(String id) async {
    await _client.patch<void>('/user/notifications/$id/read');
  }

  Future<void> markAllNotificationsAsRead() async {
    await _client.patch<void>('/user/notifications/read-all');
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/notifications/unread-count',
    );
    return response.data!['data'] as int? ?? 0;
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/profile',
      data: data,
    );
    final responseData = response['data'] as Map<String, dynamic>? ?? response;
    return User.fromJson(responseData);
  }

  Future<void> askQuestion(String eventId, String question) async {
    await _client.post<void>(
      '/user/events/$eventId/questions',
      data: {'question': question},
    );
  }

  Future<PaginatedResponse<Event>> getEventsBySpeaker({
    required String speakerName,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/by-speaker',
      queryParameters: {
        'name': speakerName,
        'page': page,
        'size': size,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<String> uploadImageBytes(List<int> bytes, String filename, {String folder = 'events'}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
      'folder': folder,
    });

    final response = await _client.postMultipart<Map<String, dynamic>>(
      '/upload',
      data: formData,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return data['url'] as String;
  }

  Future<String> uploadImage(File file, {String folder = 'events'}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'folder': folder,
    });

    final response = await _client.postMultipart<Map<String, dynamic>>(
      '/upload',
      data: formData,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return data['url'] as String;
  }

  Future<PaginatedResponse<Conversation>> getConversations({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/chat/conversations',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Conversation.fromJson);
  }

  Future<Conversation> getEventChat(String eventId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/conversations/event/$eventId',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Conversation.fromJson(data);
  }

  Future<Conversation> getDirectChat(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/conversations/direct/$userId',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Conversation.fromJson(data);
  }

  Future<PaginatedResponse<ChatMessage>> getMessages(
    String conversationId, {
    int page = 0,
    int size = 50,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, ChatMessage.fromJson);
  }

  Future<ChatMessage> sendMessage(
    String conversationId,
    String content, {
    String type = 'TEXT',
    String? mediaUrl,
    String? replyToId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/messages',
      data: {
        'content': content,
        'type': type,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ChatMessage.fromJson(data);
  }

  Future<void> markConversationAsRead(String conversationId) async {
    await _client.post<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/read',
      data: {},
    );
  }

  Future<void> muteConversation(String conversationId, bool mute) async {
    await _client.put<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/mute',
      data: {'muted': mute},
    );
  }

  Future<void> pinConversation(String conversationId, bool pin) async {
    await _client.put<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/pin',
      data: {'pinned': pin},
    );
  }

  Future<void> archiveConversation(String conversationId, bool archive) async {
    await _client.put<Map<String, dynamic>>(
      '/user/chat/conversations/$conversationId/archive',
      data: {'archived': archive},
    );
  }

  Future<int> getUnreadMessageCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/unread-count',
    );
    final data = response['data'];
    return (data as num?)?.toInt() ?? 0;
  }

  Future<List<ChatParticipant>> getEventAttendees(String eventId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/events/$eventId/attendees',
    );
    final data = response['data'] as List<dynamic>? ?? [];
    return data.map((e) => ChatParticipant.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.delete('/user/chat/messages/$messageId');
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client.delete('/user/chat/conversations/$conversationId');
  }

  Future<void> blockUser(String userId, {String? reason}) async {
    await _client.post<Map<String, dynamic>>(
      '/user/chat/block/$userId',
      data: reason != null ? {'reason': reason} : {},
    );
  }

  Future<void> unblockUser(String userId) async {
    await _client.delete('/user/chat/block/$userId');
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/blocked',
    );
    final data = response['data'] as List<dynamic>? ?? [];
    return data.map((e) => BlockedUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> isUserBlocked(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/block/$userId/status',
    );
    return response['data'] as bool? ?? false;
  }

  Future<ChatMessage> sendImageMessage(
    String conversationId,
    File imageFile, {
    String? replyToId,
  }) async {
    final imageUrl = await uploadImage(imageFile, folder: 'chat');
    return sendMessage(
      conversationId,
      'Sent an image',
      type: 'IMAGE',
      mediaUrl: imageUrl,
      replyToId: replyToId,
    );
  }

  Future<void> sendReplyNotification({
    required String recipientId,
    required String message,
    String? eventId,
  }) async {
    await _client.post<void>(
      '/user/notifications/reply',
      data: {
        'recipientId': recipientId,
        'message': message,
        if (eventId != null) 'eventId': eventId,
      },
    );
  }

  Future<List<EventBuddy>> getEventBuddies({int page = 0, int size = 20}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/chat/buddies',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>?;
    final content = data?['content'] as List<dynamic>? ?? [];
    return content.map((e) => EventBuddy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<EventBuddy>> getEventBuddiesByEvent(String eventId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/chat/events/$eventId/buddies',
    );
    final data = response['data'] as List<dynamic>? ?? [];
    return data.map((e) => EventBuddy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Conversation> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? imageUrl,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/chat/conversations/group',
      data: {
        'name': name,
        'participantIds': participantIds,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Conversation.fromJson(data);
  }

  Future<void> addGroupParticipants(String conversationId, List<String> userIds) async {
    await _client.post<void>(
      '/user/chat/conversations/$conversationId/participants',
      data: {'userIds': userIds},
    );
  }

  Future<void> removeGroupParticipant(String conversationId, String userId) async {
    await _client.delete('/user/chat/conversations/$conversationId/participants/$userId');
  }

  Future<Certificate> getCertificateByRegistration(String registrationId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/certificates/registration/$registrationId',
    );
    return Certificate.fromJson(response);
  }

  Future<List<int>> downloadCertificate(String certificateId) async {
    return _client.downloadBytes('/user/certificates/$certificateId/download');
  }

  Future<Certificate> sendCertificateByEmail(String registrationId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/certificates/registration/$registrationId/send-email',
    );
    return Certificate.fromJson(response);
  }

  Future<Registration> checkInRegistration(String registrationId) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/organiser/registrations/$registrationId/check-in',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
  }

  Future<List<Event>> getPersonalizedRecommendations({int limit = 10}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/recommendations/personalized',
      queryParameters: {'limit': limit},
    );
    final recommendedEvents = response['recommendedEvents'] as List<dynamic>? ?? [];
    return recommendedEvents
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Event>> getSimilarEvents(String eventId, {int limit = 5}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/recommendations/similar/$eventId',
      queryParameters: {'limit': limit},
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Event>> getTrendingEvents({int limit = 10}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/recommendations/trending',
      queryParameters: {'limit': limit},
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaginatedResponse<Review>> getEventReviews(
    String eventId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$eventId/reviews',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Review.fromJson);
  }

  Future<Review> createReview(
    String eventId, {
    required int rating,
    String? comment,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/events/$eventId/reviews',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Review.fromJson(data);
  }

  Future<bool> canReview(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$eventId/can-review',
    );
    final data = response.data!['data'] as Map<String, dynamic>?;
    return data?['canReview'] as bool? ?? false;
  }

  Future<PaginatedResponse<Review>> getMyReviews({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/my-reviews',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Review.fromJson);
  }

  Future<void> reportReview(
    String reviewId, {
    required String reason,
    String? description,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/user/reviews/$reviewId/report',
      data: {
        'reason': reason,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
  }

  Future<bool> toggleBookmark(String eventId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/bookmarks/$eventId',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return data['bookmarked'] as bool? ?? false;
  }

  Future<void> addBookmark(String eventId) async {
    await _client.post<Map<String, dynamic>>(
      '/user/bookmarks/$eventId/add',
    );
  }

  Future<void> removeBookmark(String eventId) async {
    await _client.delete('/user/bookmarks/$eventId');
  }

  Future<bool> isBookmarked(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/bookmarks/$eventId/status',
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return data['bookmarked'] as bool? ?? false;
  }

  Future<PaginatedResponse<Event>> getBookmarkedEvents({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/bookmarks',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<List<String>> getBookmarkedEventIds() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/bookmarks/ids',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((id) => id.toString()).toList();
  }

  Future<PaginatedResponse<Question>> getMyQuestions({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/my-questions',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Question.fromJson);
  }

  Future<String> getGoogleCalendarAuthUrl({String? redirectUri}) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/calendar/auth-url',
      queryParameters: redirectUri != null ? {'redirectUri': redirectUri} : null,
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return data['authUrl'] as String;
  }

  Future<void> connectGoogleCalendar({
    required String code,
    String? redirectUri,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/user/calendar/connect',
      data: {
        'code': code,
        if (redirectUri != null) 'redirectUri': redirectUri,
      },
    );
  }

  Future<void> disconnectGoogleCalendar() async {
    await _client.delete('/user/calendar/disconnect');
  }

  Future<GoogleCalendarStatus> getGoogleCalendarStatus() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/calendar/status',
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return GoogleCalendarStatus.fromJson(data);
  }

  Future<CalendarSyncResult> syncEventToCalendar(String registrationId, {String? calendarId}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/calendar/sync',
      data: {
        'registrationId': registrationId,
        if (calendarId != null) 'calendarId': calendarId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return CalendarSyncResult.fromJson(data);
  }

  Future<void> unsyncEventFromCalendar(String registrationId) async {
    await _client.delete('/user/calendar/sync/$registrationId');
  }

  Future<List<CalendarSyncResult>> getSyncedEvents() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/calendar/synced-events',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => CalendarSyncResult.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<int> syncAllEventsToCalendar() async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/calendar/sync-all',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return data['syncedCount'] as int? ?? 0;
  }

  Future<EventImage?> getEventImage(String eventId) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/gallery/event/$eventId',
    );
    final data = response.data!['data'];
    if (data == null) return null;
    return EventImage.fromJson(data as Map<String, dynamic>);
  }

  Future<PaginatedResponse<EventImage>> getGalleryImages({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/gallery',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, EventImage.fromJson);
  }

  Future<PaginatedResponse<EventImage>> getGalleryImagesByCategory(
    int categoryId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/gallery/category/$categoryId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, EventImage.fromJson);
  }

  /// Chat with AI Assistant
  /// Returns: {response, intent, data, dataPointsUsed}
  Future<Map<String, dynamic>> askChatbot(String message) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/assistant/chat',
      data: {'message': message},
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return data;
  }
}

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  final DateTime? connectedAt;
  final DateTime? expiresAt;
  final int syncedEventsCount;

  GoogleCalendarStatus({
    required this.connected,
    this.email,
    this.connectedAt,
    this.expiresAt,
    required this.syncedEventsCount,
  });

  factory GoogleCalendarStatus.fromJson(Map<String, dynamic> json) {
    return GoogleCalendarStatus(
      connected: json['connected'] as bool? ?? false,
      email: json['email'] as String?,
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      syncedEventsCount: json['syncedEventsCount'] as int? ?? 0,
    );
  }
}

class CalendarSyncResult {
  final String id;
  final String registrationId;
  final String eventId;
  final String eventTitle;
  final DateTime eventStartTime;
  final DateTime eventEndTime;
  final String googleEventId;
  final String? calendarId;
  final bool isSynced;
  final DateTime? lastSyncedAt;

  CalendarSyncResult({
    required this.id,
    required this.registrationId,
    required this.eventId,
    required this.eventTitle,
    required this.eventStartTime,
    required this.eventEndTime,
    required this.googleEventId,
    this.calendarId,
    required this.isSynced,
    this.lastSyncedAt,
  });

  factory CalendarSyncResult.fromJson(Map<String, dynamic> json) {
    return CalendarSyncResult(
      id: json['id'] as String,
      registrationId: json['registrationId'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String,
      eventStartTime: DateTime.parse(json['eventStartTime'] as String),
      eventEndTime: DateTime.parse(json['eventEndTime'] as String),
      googleEventId: json['googleEventId'] as String,
      calendarId: json['calendarId'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
    );
  }
}
