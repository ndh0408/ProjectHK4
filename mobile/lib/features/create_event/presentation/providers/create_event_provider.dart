import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';

class CreateEventState {
  const CreateEventState({
    this.title = '',
    this.description = '',
    this.imageUrl,
    this.startTime,
    this.endTime,
    this.venue = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.cityId,
    this.categoryId,
    this.isFree = true,
    this.ticketPrice,
    this.capacity,
    this.visibility = 'PUBLIC',
    this.requiresApproval = false,
    this.isLoading = false,
    this.error,
    this.createdEvent,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final String venue;
  final String address;
  final double? latitude;
  final double? longitude;
  final int? cityId;
  final int? categoryId;
  final bool isFree;
  final double? ticketPrice;
  final int? capacity;
  final String visibility;
  final bool requiresApproval;
  final bool isLoading;
  final String? error;
  final Event? createdEvent;

  CreateEventState copyWith({
    String? title,
    String? description,
    String? imageUrl,
    DateTime? startTime,
    DateTime? endTime,
    String? venue,
    String? address,
    double? latitude,
    double? longitude,
    int? cityId,
    int? categoryId,
    bool? isFree,
    double? ticketPrice,
    int? capacity,
    String? visibility,
    bool? requiresApproval,
    bool? isLoading,
    String? error,
    Event? createdEvent,
    bool clearImageUrl = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearCityId = false,
    bool clearCategoryId = false,
    bool clearTicketPrice = false,
    bool clearCapacity = false,
    bool clearError = false,
  }) {
    return CreateEventState(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      address: address ?? this.address,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      isFree: isFree ?? this.isFree,
      ticketPrice: clearTicketPrice ? null : (ticketPrice ?? this.ticketPrice),
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      visibility: visibility ?? this.visibility,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      createdEvent: createdEvent ?? this.createdEvent,
    );
  }

  bool get isValid {
    return title.trim().isNotEmpty &&
        startTime != null &&
        endTime != null &&
        startTime!.isBefore(endTime!);
  }
}

class CreateEventNotifier extends StateNotifier<CreateEventState> {
  CreateEventNotifier(this._apiService) : super(const CreateEventState());

  final ApiService _apiService;

  void updateTitle(String value) {
    state = state.copyWith(title: value);
  }

  void updateDescription(String value) {
    state = state.copyWith(description: value);
  }

  void updateImageUrl(String? value) {
    if (value == null) {
      state = state.copyWith(clearImageUrl: true);
    } else {
      state = state.copyWith(imageUrl: value);
    }
  }

  void updateStartTime(DateTime value) {
    state = state.copyWith(startTime: value);
    if (state.endTime == null || state.endTime!.isBefore(value)) {
      state = state.copyWith(endTime: value.add(const Duration(hours: 1)));
    }
  }

  void updateEndTime(DateTime value) {
    state = state.copyWith(endTime: value);
  }

  void updateVenue(String value) {
    state = state.copyWith(venue: value);
  }

  void updateAddress(String value) {
    state = state.copyWith(address: value);
  }

  void updateLatitude(double? value) {
    if (value == null) {
      state = state.copyWith(clearLatitude: true);
    } else {
      state = state.copyWith(latitude: value);
    }
  }

  void updateLongitude(double? value) {
    if (value == null) {
      state = state.copyWith(clearLongitude: true);
    } else {
      state = state.copyWith(longitude: value);
    }
  }

  void updateLocation({
    required String venue,
    required String address,
    double? latitude,
    double? longitude,
    int? cityId,
  }) {
    state = state.copyWith(
      venue: venue,
      address: address,
      latitude: latitude,
      longitude: longitude,
      cityId: cityId,
    );
  }

  void updateCityId(int? value) {
    if (value == null) {
      state = state.copyWith(clearCityId: true);
    } else {
      state = state.copyWith(cityId: value);
    }
  }

  void updateCategoryId(int? value) {
    if (value == null) {
      state = state.copyWith(clearCategoryId: true);
    } else {
      state = state.copyWith(categoryId: value);
    }
  }

  void updateIsFree(bool value) {
    state = state.copyWith(isFree: value);
    if (value) {
      state = state.copyWith(clearTicketPrice: true);
    }
  }

  void updateTicketPrice(double? value) {
    if (value == null) {
      state = state.copyWith(clearTicketPrice: true);
    } else {
      state = state.copyWith(ticketPrice: value);
    }
  }

  void updateCapacity(int? value) {
    if (value == null) {
      state = state.copyWith(clearCapacity: true);
    } else {
      state = state.copyWith(capacity: value);
    }
  }

  void updateVisibility(String value) {
    state = state.copyWith(visibility: value);
  }

  void updateRequiresApproval(bool value) {
    state = state.copyWith(requiresApproval: value);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = const CreateEventState();
  }

  Future<bool> createEvent() async {
    if (!state.isValid) {
      state = state.copyWith(error: 'Please fill in all required fields');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final event = await _apiService.createEvent(
        title: state.title,
        description: state.description.isEmpty ? null : state.description,
        imageUrl: state.imageUrl,
        startTime: state.startTime!,
        endTime: state.endTime!,
        venue: state.venue.isEmpty ? null : state.venue,
        address: state.address.isEmpty ? null : state.address,
        latitude: state.latitude,
        longitude: state.longitude,
        cityId: state.cityId,
        categoryId: state.categoryId,
        isFree: state.isFree,
        ticketPrice: state.isFree ? null : state.ticketPrice,
        capacity: state.capacity,
        visibility: state.visibility,
        requiresApproval: state.requiresApproval,
      );

      state = state.copyWith(isLoading: false, createdEvent: event);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final createEventProvider =
    StateNotifierProvider.autoDispose<CreateEventNotifier, CreateEventState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return CreateEventNotifier(apiService);
  },
);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getCategories();
});

final citiesProvider = FutureProvider.autoDispose<List<City>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getCities();
});
