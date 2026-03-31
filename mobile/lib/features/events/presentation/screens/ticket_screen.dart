import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({
    super.key,
    required this.eventName,
    required this.ticketId,
    required this.userName,
    required this.eventTime,
    required this.eventLocation,
    this.registrationId,
    this.checkedInAt,
  });

  final String eventName;
  final String ticketId;
  final String userName;
  final String eventTime;
  final String eventLocation;
  final String? registrationId;
  final DateTime? checkedInAt;

  bool get isCheckedIn => checkedInAt != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final qrData = registrationId ?? ticketId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ticket)),
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (isCheckedIn) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.checkedIn,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.checkedInAt} ${DateFormat('MMM d, yyyy h:mm a').format(checkedInAt!)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      eventName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: isCheckedIn ? 0.3 : 1.0,
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                        ),
                        if (isCheckedIn)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ref: ${ticketId.length >= 8 ? ticketId.substring(0, 8).toUpperCase() : ticketId.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(Icons.calendar_today, eventTime),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on, eventLocation),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isCheckedIn ? l10n.youHaveCheckedIn : l10n.showQrAtEntrance,
                style: TextStyle(
                  color: isCheckedIn ? Colors.green : Colors.grey,
                  fontWeight: isCheckedIn ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
