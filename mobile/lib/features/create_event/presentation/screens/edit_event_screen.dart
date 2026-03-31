import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../providers/create_event_provider.dart';
import 'my_created_events_screen.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  const EditEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _imageUrl;
  DateTime? _startTime;
  DateTime? _endTime;
  double? _latitude;
  double? _longitude;
  int? _cityId;
  int? _categoryId;
  bool _isFree = true;
  String _visibility = 'PUBLIC';
  bool _isLoading = false;
  bool _isSaving = false;
  Event? _event;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final event = await api.getEventById(widget.eventId);
      _populateFields(event);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFields(Event event) {
    _event = event;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _venueController.text = event.venue ?? event.address ?? '';
    _imageUrl = event.imageUrl;
    _startTime = event.startTime;
    _endTime = event.endTime;
    _latitude = event.latitude;
    _longitude = event.longitude;
    _cityId = event.city?.id;
    _categoryId = event.category?.id;
    _isFree = event.isFree;
    if (!_isFree && event.ticketPrice != null) {
      _priceController.text = event.ticketPrice!.toStringAsFixed(0);
    }
    if (event.capacity != null) {
      _capacityController.text = event.capacity.toString();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startTime ?? now.add(const Duration(days: 1)))
        : (_endTime ?? (_startTime?.add(const Duration(hours: 1)) ?? now.add(const Duration(days: 1, hours: 1))));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null || !mounted) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startTime = dateTime;
        if (_endTime == null || _endTime!.isBefore(dateTime)) {
          _endTime = dateTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = dateTime;
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });

      try {
        final api = ref.read(apiServiceProvider);
        final url = await api.uploadImageBytes(bytes, picked.name);
        setState(() {
          _imageUrl = url;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)!.failedToUploadImage}: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterEventTitle)),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectStartAndEndTime)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'imageUrl': _imageUrl,
        'startTime': _startTime!.toIso8601String(),
        'endTime': _endTime!.toIso8601String(),
        'venue': _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'cityId': _cityId,
        'categoryId': _categoryId,
        'isFree': _isFree,
        'ticketPrice': _isFree ? null : double.tryParse(_priceController.text),
        'capacity': int.tryParse(_capacityController.text),
        'visibility': _visibility,
        'requiresApproval': false,
      };

      await api.updateMyEvent(widget.eventId, data);

      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(myCreatedEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_event?.status == EventStatus.rejected
                ? AppLocalizations.of(context)!.eventUpdatedAndResubmitted
                : AppLocalizations.of(context)!.eventUpdatedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final citiesAsync = ref.watch(citiesProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.editEvent)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editEvent),
        actions: [
          if (_event?.status == EventStatus.rejected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, size: 16, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.rejected.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_event?.status == EventStatus.rejected) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.eventWasRejected,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.pleaseUpdateAndResubmit,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                _buildImagePicker(),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.eventName,
                      border: InputBorder.none,
                      hintStyle: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Divider(height: 32),

                _buildDateTimeRow(
                  icon: Icons.circle,
                  iconColor: Colors.green,
                  label: AppLocalizations.of(context)!.start,
                  dateTime: _startTime,
                  onTap: () => _selectDateTime(isStart: true),
                ),
                _buildDateTimeRow(
                  icon: Icons.circle_outlined,
                  iconColor: Colors.red,
                  label: AppLocalizations.of(context)!.end,
                  dateTime: _endTime,
                  onTap: () => _selectDateTime(isStart: false),
                ),

                const SizedBox(height: 16),

                _buildLocationRow(),

                const SizedBox(height: 12),

                _buildDescriptionRow(),

                const Divider(height: 32),

                _buildCategorySelector(categoriesAsync),

                const SizedBox(height: 12),

                _buildCitySelector(citiesAsync),

                const Divider(height: 32),

                _buildSectionHeader(AppLocalizations.of(context)!.ticketing),
                _buildPriceRow(),

                const Divider(height: 32),

                _buildSectionHeader(AppLocalizations.of(context)!.options),
                _buildVisibilityRow(),
                const SizedBox(height: 8),
                _buildCapacityRow(),

                const SizedBox(height: 24),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: _event?.status == EventStatus.rejected
                    ? AppColors.primary
                    : Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _event?.status == EventStatus.rejected
                          ? AppLocalizations.of(context)!.saveResubmit
                          : AppLocalizations.of(context)!.saveChanges,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          image: _selectedImageBytes != null
              ? DecorationImage(
                  image: MemoryImage(_selectedImageBytes!),
                  fit: BoxFit.cover,
                )
              : _imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: _selectedImageBytes == null && _imageUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.addCoverImage,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDateTimeRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required DateTime? dateTime,
    required VoidCallback onTap,
  }) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const Spacer(),
            if (dateTime != null) ...[
              Text(
                dateFormat.format(dateTime),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Text(
                timeFormat.format(dateTime),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ] else
              Text(
                AppLocalizations.of(context)!.selectDate,
                style: TextStyle(color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow() {
    return InkWell(
      onTap: _showLocationDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _venueController.text.isEmpty ? AppLocalizations.of(context)!.chooseLocation : _venueController.text,
                style: TextStyle(
                  color: _venueController.text.isEmpty ? Colors.grey[600] : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog() {
    LatLng selectedLocation = LatLng(
      _latitude ?? 10.8231,
      _longitude ?? 106.6297,
    );

    final latController = TextEditingController(
      text: selectedLocation.latitude.toStringAsFixed(6),
    );
    final lngController = TextEditingController(
      text: selectedLocation.longitude.toStringAsFixed(6),
    );
    final mapController = MapController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.chooseLocation,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.venueName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.latitude,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.my_location, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (value) {
                          final lat = double.tryParse(value);
                          if (lat != null && lat >= -90 && lat <= 90) {
                            setDialogState(() {
                              selectedLocation = LatLng(lat, selectedLocation.longitude);
                              mapController.move(selectedLocation, mapController.camera.zoom);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.longitude,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.my_location, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (value) {
                          final lng = double.tryParse(value);
                          if (lng != null && lng >= -180 && lng <= 180) {
                            setDialogState(() {
                              selectedLocation = LatLng(selectedLocation.latitude, lng);
                              mapController.move(selectedLocation, mapController.camera.zoom);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final lat = double.tryParse(latController.text);
                        final lng = double.tryParse(lngController.text);
                        if (lat != null && lng != null &&
                            lat >= -90 && lat <= 90 &&
                            lng >= -180 && lng <= 180) {
                          setDialogState(() {
                            selectedLocation = LatLng(lat, lng);
                            mapController.move(selectedLocation, mapController.camera.zoom);
                          });
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: AppColors.primary),
                      tooltip: 'Apply coordinates',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            initialCenter: selectedLocation,
                            initialZoom: 15,
                            onTap: (tapPosition, point) {
                              setDialogState(() {
                                selectedLocation = point;
                                latController.text = point.latitude.toStringAsFixed(6);
                                lngController.text = point.longitude.toStringAsFixed(6);
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.luma.mobile',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: selectedLocation,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.tapOnMapOrEnterCoordinates,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final lat = double.tryParse(latController.text) ?? selectedLocation.latitude;
                      final lng = double.tryParse(lngController.text) ?? selectedLocation.longitude;

                      setState(() {
                        _latitude = lat;
                        _longitude = lng;
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.saveLocation),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionRow() {
    final hasDescription = _descriptionController.text.isNotEmpty;

    return InkWell(
      onTap: () => _openDescriptionEditor(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.notes_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDescription ? AppLocalizations.of(context)!.description : AppLocalizations.of(context)!.addDescription,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: hasDescription ? 12 : 15,
                    ),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 2),
                    Text(
                      _descriptionController.text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _openDescriptionEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.description,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.describeYourEvent,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text(AppLocalizations.of(context)!.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCategorySelector(AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) => InkWell(
        onTap: () => _showCategoryPicker(categories),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _categoryId != null
                      ? categories.firstWhere((c) => c.id == _categoryId, orElse: () => categories.first).name
                      : AppLocalizations.of(context)!.selectCategory,
                  style: TextStyle(
                    color: _categoryId != null ? AppColors.textPrimary : Colors.grey[600],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            leading: Icon(
              Icons.category,
              color: _categoryId == category.id ? AppColors.primary : Colors.grey,
            ),
            title: Text(category.name),
            trailing: _categoryId == category.id ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _categoryId = category.id);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildCitySelector(AsyncValue<List<City>> citiesAsync) {
    return citiesAsync.when(
      data: (cities) => InkWell(
        onTap: () => _showCityPicker(cities),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.location_city_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _cityId != null
                      ? cities.firstWhere((c) => c.id == _cityId, orElse: () => cities.first).name
                      : AppLocalizations.of(context)!.selectCity,
                  style: TextStyle(
                    color: _cityId != null ? AppColors.textPrimary : Colors.grey[600],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showCityPicker(List<City> cities) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: cities.length,
        itemBuilder: (context, index) {
          final city = cities[index];
          return ListTile(
            leading: Icon(
              Icons.location_city,
              color: _cityId == city.id ? AppColors.primary : Colors.grey,
            ),
            title: Text(city.name),
            trailing: _cityId == city.id ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _cityId = city.id);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildPriceRow() {
    return InkWell(
      onTap: () => _showPriceDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.attach_money, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.price),
            const Spacer(),
            Text(
              _isFree ? AppLocalizations.of(context)!.free : '\$${_priceController.text}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.freeEvent),
                value: _isFree,
                onChanged: (value) {
                  setDialogState(() => _isFree = value);
                  setState(() => _isFree = value);
                },
              ),
              if (!_isFree) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.ticketPrice,
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text(AppLocalizations.of(context)!.done),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityRow() {
    return InkWell(
      onTap: () => _showVisibilityDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.visibility),
            const Spacer(),
            Text(
              _visibility == 'PUBLIC' ? AppLocalizations.of(context)!.public : AppLocalizations.of(context)!.private,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showVisibilityDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(AppLocalizations.of(context)!.public),
            subtitle: Text(AppLocalizations.of(context)!.anyoneCanSeeAndJoin),
            trailing: _visibility == 'PUBLIC' ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _visibility = 'PUBLIC');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(AppLocalizations.of(context)!.private),
            subtitle: Text(AppLocalizations.of(context)!.onlyInvitedCanSee),
            trailing: _visibility == 'PRIVATE' ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () {
              setState(() => _visibility = 'PRIVATE');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityRow() {
    return InkWell(
      onTap: () => _showCapacityDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.capacity),
            const Spacer(),
            Text(
              _capacityController.text.isEmpty ? AppLocalizations.of(context)!.unlimited : _capacityController.text,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showCapacityDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.maximumAttendees,
                hintText: AppLocalizations.of(context)!.leaveEmptyForUnlimited,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text(AppLocalizations.of(context)!.done),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
