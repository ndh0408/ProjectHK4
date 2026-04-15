import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    if (code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    await _processCheckIn(code);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCheckIn(String registrationId) async {
    final l10n = AppLocalizations.of(context)!;
    final apiService = ref.read(apiServiceProvider);

    try {
      final registration = await apiService.checkInRegistration(registrationId);

      if (mounted) {
        _showResultDialog(
          success: true,
          title: l10n.checkInSuccess,
          message: '${registration.userName ?? l10n.guest}\n${l10n.checkedInSuccessfully}',
          registration: registration,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = l10n.checkInFailed;

        if (e is DioException) {
          final responseData = e.response?.data;
          if (responseData is Map<String, dynamic>) {
            errorMessage = responseData['message'] ?? errorMessage;
          }
        }

        if (errorMessage.contains('already been checked in')) {
          errorMessage = l10n.alreadyCheckedIn;
        } else if (errorMessage.contains('not found')) {
          errorMessage = l10n.invalidQrCode;
        } else if (errorMessage.contains('Only approved')) {
          errorMessage = l10n.registrationNotApproved;
        } else if (errorMessage.contains('not available yet')) {
          errorMessage = 'Check-in is not available yet. Check-in opens 2 hours before the event starts.';
        } else if (errorMessage.contains('period has ended')) {
          errorMessage = 'Check-in period has ended for this event.';
        }

        _showResultDialog(
          success: false,
          title: l10n.checkInFailed,
          message: errorMessage,
        );
      }
    }
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required String message,
    Registration? registration,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              size: 64,
              color: success ? AppColors.success : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: success ? AppColors.success : AppColors.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (registration != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (registration.userEmail != null)
                      _buildInfoRow(Icons.email, registration.userEmail!),
                    if (registration.userPhone != null) ...[
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.phone, registration.userPhone!),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _lastScannedCode = null;
              });
            },
            child: Text(AppLocalizations.of(context)!.scanNext),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textLight),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  void _switchCamera() {
    _scannerController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.textOnPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.scanQrCode),
            Text(
              widget.eventTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
            tooltip: l10n.toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
            tooltip: l10n.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          _buildScannerOverlay(),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _isProcessing ? l10n.processing : l10n.pointCameraAtQr,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        AppColors.textPrimary.withValues(alpha: 0.54),
        BlendMode.srcOut,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
