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
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../providers/create_event_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      // Read bytes from XFile (works on all platforms)
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = filename;
        _isUploadingImage = true;
      });

      try {
        // Upload image to Cloudinary using bytes
        final apiService = ref.read(apiServiceProvider);
        final imageUrl = await apiService.uploadImageBytes(bytes, filename, folder: 'events');

        // Update state with uploaded image URL
        ref.read(createEventProvider.notifier).updateImageUrl(imageUrl);

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.imageUploadedSuccessfully),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }
    }
  }

  Future<void> _selectDateTime({
    required bool isStart,
  }) async {
    final state = ref.read(createEventProvider);
    final now = DateTime.now();
    final initialDate = isStart
        ? (state.startTime ?? now.add(const Duration(days: 1)))
        : (state.endTime ?? state.startTime?.add(const Duration(hours: 1)) ?? now.add(const Duration(days: 1, hours: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        final notifier = ref.read(createEventProvider.notifier);
        if (isStart) {
          notifier.updateStartTime(dateTime);
        } else {
          notifier.updateEndTime(dateTime);
        }
      }
    }
  }

  Future<void> _createEvent() async {
    final notifier = ref.read(createEventProvider.notifier);

    // Update from controllers
    notifier.updateTitle(_titleController.text);
    notifier.updateDescription(_descriptionController.text);
    notifier.updateVenue(_venueController.text);

    if (!ref.read(createEventProvider).isFree) {
      final price = double.tryParse(_priceController.text);
      notifier.updateTicketPrice(price);
    }

    final capacity = int.tryParse(_capacityController.text);
    notifier.updateCapacity(capacity);

    final success = await notifier.createEvent();

    if (success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.eventCreatedSuccessfully),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final citiesAsync = ref.watch(citiesProvider);

    // Show error snackbar
    ref.listen<CreateEventState>(createEventProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.createEvent,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.orange[100],
              child: const Text('😊', style: TextStyle(fontSize: 16)),
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
                // Progress bar
                Container(
                  height: 3,
                  color: Colors.grey[200],
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _calculateProgress(),
                    child: Container(color: Colors.pink[300]),
                  ),
                ),

                // Cover Image
                _buildCoverImage(context),

                const SizedBox(height: 16),

                // Event Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.eventName,
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                const Divider(height: 32),

                // Start Date/Time
                _buildDateTimeRow(
                  context: context,
                  icon: Icons.circle_outlined,
                  iconColor: Colors.green,
                  label: l10n.start,
                  dateTime: state.startTime,
                  onTap: () => _selectDateTime(isStart: true),
                ),

                const SizedBox(height: 12),

                // End Date/Time
                _buildDateTimeRow(
                  context: context,
                  icon: Icons.circle_outlined,
                  iconColor: Colors.red,
                  label: l10n.end,
                  dateTime: state.endTime,
                  onTap: () => _selectDateTime(isStart: false),
                ),

                const SizedBox(height: 16),

                // Location
                _buildLocationRow(context),

                const SizedBox(height: 12),

                // Description
                _buildDescriptionRow(context),

                const Divider(height: 32),

                // Category Selection
                _buildCategorySelector(context, categoriesAsync),

                const SizedBox(height: 12),

                // City Selection
                _buildCitySelector(context, citiesAsync),

                const Divider(height: 32),

                // Ticketing Section
                _buildSectionHeader(l10n.ticketing),

                // Price
                _buildPriceRow(context),

                const Divider(height: 32),

                // Options Section
                _buildSectionHeader(l10n.options),

                // Visibility
                _buildVisibilityRow(context),

                const SizedBox(height: 8),

                // Capacity
                _buildCapacityRow(context),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Create Button
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _createEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.create,
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

  double _calculateProgress() {
    final state = ref.read(createEventProvider);
    int filled = 0;
    int total = 5;

    if (_titleController.text.isNotEmpty) filled++;
    if (state.startTime != null) filled++;
    if (state.endTime != null) filled++;
    if (_venueController.text.isNotEmpty) filled++;
    if (state.categoryId != null) filled++;

    return filled / total;
  }

  Widget _buildCoverImage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _isUploadingImage ? null : _pickImage,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.pink[100],
            borderRadius: BorderRadius.circular(16),
            image: _selectedImageBytes != null
                ? DecorationImage(
                    image: MemoryImage(_selectedImageBytes!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _selectedImageBytes == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Colors.pink[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.addCoverImage,
                        style: TextStyle(
                          color: Colors.pink[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Upload indicator overlay
                    if (_isUploadingImage)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.uploading,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Edit button
                    if (!_isUploadingImage)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    // Upload success indicator
                    if (!_isUploadingImage && ref.read(createEventProvider).imageUrl != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_done, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                l10n.uploaded,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDateTimeRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required DateTime? dateTime,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Text(
              dateTime != null ? dateFormat.format(dateTime) : l10n.selectDate,
              style: TextStyle(
                color: dateTime != null ? AppColors.textPrimary : Colors.grey[400],
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              dateTime != null ? timeFormat.format(dateTime) : l10n.time,
              style: TextStyle(
                color: dateTime != null ? AppColors.textPrimary : Colors.grey[400],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () {
        // TODO: Navigate to location picker
        _showLocationDialog();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _venueController.text.isEmpty ? l10n.chooseLocation : _venueController.text,
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
    final l10n = AppLocalizations.of(context)!;
    // Default to Ho Chi Minh City center
    LatLng selectedLocation = const LatLng(10.8231, 106.6297);
    final state = ref.read(createEventProvider);
    if (state.latitude != null && state.longitude != null) {
      selectedLocation = LatLng(state.latitude!, state.longitude!);
    }

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
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.chooseLocation,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Venue name input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText: l10n.venueName,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Latitude & Longitude inputs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: l10n.latitude,
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
                          labelText: l10n.longitude,
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
                    // Apply coordinates button
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

              // Map
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
                        // Coordinates display
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
                l10n.tapOnMapOrEnterCoordinates,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Get values from text fields in case user typed but didn't submit
                      final lat = double.tryParse(latController.text) ?? selectedLocation.latitude;
                      final lng = double.tryParse(lngController.text) ?? selectedLocation.longitude;

                      final notifier = ref.read(createEventProvider.notifier);
                      notifier.updateVenue(_venueController.text);
                      notifier.updateLatitude(lat);
                      notifier.updateLongitude(lng);
                      Navigator.pop(context);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.saveLocation),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    hasDescription ? l10n.description : l10n.addDescription,
                    style: TextStyle(
                      color: hasDescription ? Colors.grey[600] : Colors.grey[600],
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
            if (hasDescription)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MD',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _openDescriptionEditor() async {
    final result = await context.push<String>(
      '/description-editor',
      extra: _descriptionController.text,
    );

    if (result != null && mounted) {
      setState(() {
        _descriptionController.text = result;
      });
      ref.read(createEventProvider.notifier).updateDescription(result);
    }
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

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);

    return InkWell(
      onTap: () => _showPriceDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.attach_money, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.price,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              state.isFree ? l10n.freeEvent : '\$${state.ticketPrice?.toStringAsFixed(0) ?? '0'}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog() {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(createEventProvider);
    bool isFree = state.isFree;
    _priceController.text = state.ticketPrice?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.ticketPrice),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(l10n.freeEvent),
                value: isFree,
                onChanged: (v) {
                  setDialogState(() => isFree = v);
                },
              ),
              if (!isFree)
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.price,
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final notifier = ref.read(createEventProvider.notifier);
                notifier.updateIsFree(isFree);
                if (!isFree) {
                  notifier.updateTicketPrice(double.tryParse(_priceController.text));
                }
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);

    return InkWell(
      onTap: () => _showVisibilityDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.visibility,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              state.visibility == 'PUBLIC' ? l10n.public : l10n.private,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showVisibilityDialog() {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(createEventProvider);
    String visibility = state.visibility;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.eventVisibility),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(l10n.public),
                subtitle: Text(l10n.anyoneCanDiscover),
                value: 'PUBLIC',
                groupValue: visibility,
                onChanged: (v) => setDialogState(() => visibility = v!),
              ),
              RadioListTile<String>(
                title: Text(l10n.private),
                subtitle: Text(l10n.onlyPeopleWithLink),
                value: 'PRIVATE',
                groupValue: visibility,
                onChanged: (v) => setDialogState(() => visibility = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(createEventProvider.notifier).updateVisibility(visibility);
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);

    return InkWell(
      onTap: () => _showCapacityDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.people_outline, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.capacity,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              state.capacity == null ? l10n.unlimited : '${state.capacity}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showCapacityDialog() {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(createEventProvider);
    bool unlimited = state.capacity == null;
    _capacityController.text = state.capacity?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.eventCapacity),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(l10n.unlimited),
                value: unlimited,
                onChanged: (v) {
                  setDialogState(() => unlimited = v);
                },
              ),
              if (!unlimited)
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.maximumAttendees,
                    border: const OutlineInputBorder(),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final notifier = ref.read(createEventProvider.notifier);
                if (unlimited) {
                  notifier.updateCapacity(null);
                } else {
                  notifier.updateCapacity(int.tryParse(_capacityController.text));
                }
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context, AsyncValue<List<Category>> categoriesAsync) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);

    return categoriesAsync.when(
      data: (categories) {
        final selectedCategory = state.categoryId != null
            ? categories.where((c) => c.id == state.categoryId).firstOrNull
            : null;

        return InkWell(
          onTap: () => _showCategoryDialog(categories),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.category_outlined, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCategory?.name ?? l10n.selectCategory,
                    style: TextStyle(
                      color: selectedCategory != null ? AppColors.textPrimary : Colors.grey[600],
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l10n.loadingCategories),
          ],
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  void _showCategoryDialog(List<Category> categories) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectCategory),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                onTap: () {
                  ref.read(createEventProvider.notifier).updateCategoryId(category.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCitySelector(BuildContext context, AsyncValue<List<City>> citiesAsync) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(createEventProvider);

    return citiesAsync.when(
      data: (cities) {
        final selectedCity = state.cityId != null
            ? cities.where((c) => c.id == state.cityId).firstOrNull
            : null;

        return InkWell(
          onTap: () => _showCityDialog(cities),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCity?.name ?? l10n.selectCity,
                    style: TextStyle(
                      color: selectedCity != null ? AppColors.textPrimary : Colors.grey[600],
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l10n.loadingCities),
          ],
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  void _showCityDialog(List<City> cities) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectCity),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: cities.length,
            itemBuilder: (context, index) {
              final city = cities[index];
              return ListTile(
                title: Text(city.name),
                subtitle: city.country != null ? Text(city.country!) : null,
                onTap: () {
                  ref.read(createEventProvider.notifier).updateCityId(city.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
