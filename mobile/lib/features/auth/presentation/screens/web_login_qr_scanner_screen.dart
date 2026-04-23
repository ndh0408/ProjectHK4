import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../data/auth_repository.dart';

class WebLoginQrScannerScreen extends ConsumerStatefulWidget {
  const WebLoginQrScannerScreen({super.key});

  @override
  ConsumerState<WebLoginQrScannerScreen> createState() =>
      _WebLoginQrScannerScreenState();
}

class _WebLoginQrScannerScreenState
    extends ConsumerState<WebLoginQrScannerScreen> {
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

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty || raw == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = raw;
    });

    await _approveWebLogin(raw);

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  Future<void> _approveWebLogin(String rawCode) async {
    final parsed = _parseQrPayload(rawCode);
    if (parsed == null) {
      _showResultDialog(
        success: false,
        title: 'Invalid QR code',
        message:
            'This code is not a LUMA web login QR. Open the QR login card on Flutter web and scan that code instead.',
      );
      return;
    }

    try {
      await ref.read(authRepositoryProvider).approveQrLoginChallenge(
            challengeId: parsed.challengeId,
            approvalCode: parsed.approvalCode,
          );

      if (!mounted) return;
      _showResultDialog(
        success: true,
        title: 'Web login approved',
        message:
            'The browser will sign in automatically in a moment. You can close this scanner after the web screen finishes loading.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showResultDialog(
        success: false,
        title: 'Approval failed',
        message: e.message,
      );
    }
  }

  _QrPayload? _parseQrPayload(String rawCode) {
    final uri = Uri.tryParse(rawCode);
    if (uri == null || uri.scheme != 'luma' || uri.host != 'qr-login') {
      return null;
    }

    final challengeId = uri.queryParameters['challengeId'];
    final approvalCode = uri.queryParameters['approvalCode'];
    if (challengeId == null ||
        challengeId.isEmpty ||
        approvalCode == null ||
        approvalCode.isEmpty) {
      return null;
    }

    return _QrPayload(
      challengeId: challengeId,
      approvalCode: approvalCode,
    );
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppDialog(
        title: title,
        message: message,
        icon:
            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        iconColor: success ? AppColors.success : AppColors.error,
        primaryLabel: 'Scan next',
        onPrimary: () {
          Navigator.of(dialogContext).pop();
          setState(() => _lastScannedCode = null);
        },
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
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        title: const Text('Scan web login QR'),
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
                    'Approve web login',
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Scan the QR shown on Flutter web to sign that browser in with your current mobile account.',
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
                              ? 'Approving request...'
                              : 'Point the camera at the web login QR.',
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
                          label: 'Toggle flash',
                          onTap: _toggleTorch,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _ScannerActionButton(
                          icon: Icons.cameraswitch_rounded,
                          label: 'Switch camera',
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

class _QrPayload {
  const _QrPayload({
    required this.challengeId,
    required this.approvalCode,
  });

  final String challengeId;
  final String approvalCode;
}
