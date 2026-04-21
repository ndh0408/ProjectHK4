import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/widgets/app_components.dart';

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

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    if (code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    await _processCheckIn(code);

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processCheckIn(String registrationId) async {
    final l10n = AppLocalizations.of(context)!;
    final apiService = ref.read(apiServiceProvider);

    try {
      final registration = await apiService.checkInRegistration(registrationId);

      if (!mounted) return;
      _showResultDialog(
        success: true,
        title: l10n.checkInSuccess,
        message:
            '${registration.userName ?? l10n.guest}\n${l10n.checkedInSuccessfully}',
        registration: registration,
      );
    } catch (error) {
      if (!mounted) return;
      String errorMessage = l10n.checkInFailed;

      if (error is DioException) {
        final responseData = error.response?.data;
        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message']?.toString() ?? errorMessage;
        }
      }

      if (errorMessage.contains('already been checked in')) {
        errorMessage = l10n.alreadyCheckedIn;
      } else if (errorMessage.contains('not found')) {
        errorMessage = l10n.invalidQrCode;
      } else if (errorMessage.contains('Only approved')) {
        errorMessage = l10n.registrationNotApproved;
      } else if (errorMessage.contains('not available yet')) {
        errorMessage =
            'Check-in opens shortly before the event starts. Please try again closer to showtime.';
      } else if (errorMessage.contains('period has ended')) {
        errorMessage = 'The check-in window for this event has already ended.';
      }

      _showResultDialog(
        success: false,
        title: l10n.checkInFailed,
        message: errorMessage,
      );
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
      builder: (dialogContext) => AppDialog(
        title: title,
        message: message,
        icon:
            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        iconColor: success ? AppColors.success : AppColors.error,
        primaryLabel: AppLocalizations.of(context)!.scanNext,
        onPrimary: () {
          Navigator.of(dialogContext).pop();
          setState(() => _lastScannedCode = null);
        },
        children: registration == null
            ? null
            : [
                AppCard(
                  background: AppColors.surfaceVariant,
                  border: false,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      if (registration.userEmail != null)
                        _ResultInfoRow(
                          icon: Icons.email_outlined,
                          value: registration.userEmail!,
                        ),
                      if (registration.userPhone != null) ...[
                        if (registration.userEmail != null)
                          const SizedBox(height: AppSpacing.sm),
                        _ResultInfoRow(
                          icon: Icons.phone_outlined,
                          value: registration.userPhone!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
      ),
    );
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
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
        foregroundColor: Colors.white,
        title: Text(l10n.scanQrCode),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          _buildScannerOverlay(),
          Positioned(
            top: AppSpacing.xl,
            left: AppSpacing.pageX,
            right: AppSpacing.pageX,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: AppRadius.allLg,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventTitle,
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Align the attendee QR inside the frame for the fastest check-in result.',
                    style: AppTypography.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.pageX,
            right: AppSpacing.pageX,
            bottom: AppSpacing.xxxl,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: AppRadius.allXl,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isProcessing
                              ? l10n.processing
                              : l10n.pointCameraAtQr,
                          style: AppTypography.bodyLg.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: _isProcessing ? 'Processing' : 'Ready',
                        variant: _isProcessing
                            ? StatusChipVariant.warning
                            : StatusChipVariant.success,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _ScannerActionButton(
                          icon: _torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          label: l10n.toggleFlash,
                          onTap: _toggleTorch,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _ScannerActionButton(
                          icon: Icons.cameraswitch_rounded,
                          label: l10n.switchCamera,
                          onTap: _switchCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: AppRadius.allLg,
                ),
                child:
                    const CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.allLg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: AppRadius.allLg,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: AppRadius.allMd,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  const _ResultInfoRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textLight),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
