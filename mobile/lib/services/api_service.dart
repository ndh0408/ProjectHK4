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

  /// Get VIP boosted events for home page banner (PREMIUM and VIP packages)
  Future<List<Event>> getBoostedFeaturedEvents() async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/events/boosted/featured',
    );
    final data = response.data!['data'] as List<dynamic>? ?? [];
    return data.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Get VIP only boosted events for home page banner carousel
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

  Future<Map<String, dynamic>> initiatePayment(String registrationId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/payment-intent',
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

  Future<Map<String, dynamic>> createCheckoutSession(String registrationId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/payments/registrations/$registrationId/checkout-session',
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

  Future<Event> createEvent({
    required String title,
    String? description,
    String? imageUrl,
    required DateTime startTime,
    required DateTime endTime,
    String? venue,
    String? address,
    double? latitude,
    double? longitude,
    int? cityId,
    int? categoryId,
    bool isFree = true,
    double? ticketPrice,
    int? capacity,
    String visibility = 'PUBLIC',
    bool requiresApproval = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/user/events',
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        if (venue != null) 'venue': venue,
        if (address != null) 'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (cityId != null) 'cityId': cityId,
        if (categoryId != null) 'categoryId': categoryId,
        'isFree': isFree,
        if (ticketPrice != null) 'ticketPrice': ticketPrice,
        if (capacity != null) 'capacity': capacity,
        'visibility': visibility,
        'requiresApproval': requiresApproval,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Event.fromJson(data);
  }

  Future<PaginatedResponse<Event>> getMyCreatedEvents({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/my-events',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Event.fromJson);
  }

  Future<void> deleteMyEvent(String eventId) async {
    await _client.delete('/user/events/$eventId');
  }

  Future<Event> updateMyEvent(String eventId, Map<String, dynamic> data) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/events/$eventId',
      data: data,
    );
    final responseData = response['data'] as Map<String, dynamic>? ?? response;
    return Event.fromJson(responseData);
  }

  Future<PaginatedResponse<Registration>> getEventRegistrations(
    String eventId, {
    int page = 0,
    int size = 50,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'size': size};
    if (status != null) queryParams['status'] = status;

    final response = await _client.getRaw<Map<String, dynamic>>(
      '/user/events/$eventId/registrations',
      queryParameters: queryParams,
    );
    final data = response.data!['data'] as Map<String, dynamic>? ?? response.data!;
    return PaginatedResponse.fromJson(data, Registration.fromJson);
  }

  Future<Registration> approveRegistration(String registrationId) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/events/registrations/$registrationId/approve',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
  }

  Future<Registration> rejectRegistration(String registrationId, {String? reason}) async {
    final queryParams = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) {
      queryParams['reason'] = reason;
    }
    final response = await _client.put<Map<String, dynamic>>(
      '/user/events/registrations/$registrationId/reject',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
  }

  Future<Registration> checkInRegistration(String registrationId) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/user/events/registrations/$registrationId/check-in',
    );
    final data = response['data'] as Map<String, dynamic>? ?? response;
    return Registration.fromJson(data);
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

  Future<Certificate> getCertificateByRegistration(String registrationId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/user/certificates/registration/$registrationId',
    );
    return Certificate.fromJson(response);
  }

  Future<List<int>> downloadCertificate(String certificateId) async {
    return _client.downloadBytes('/user/certificates/$certificateId/download');
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

  // ==================== Google Calendar API ====================

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
}

// ==================== Google Calendar Models ====================

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
