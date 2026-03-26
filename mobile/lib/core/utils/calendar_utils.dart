import 'package:url_launcher/url_launcher.dart';
import '../../shared/models/event.dart';

class CalendarUtils {
  /// Generates a Google Calendar URL for the given event
  static String generateGoogleCalendarUrl(Event event) {
    // Format dates for Google Calendar (YYYYMMDDTHHmmssZ)
    final startTime = _formatDateForGoogle(event.startTime);
    final endTime = _formatDateForGoogle(event.endTime);

    // Build location string
    final location = _buildLocationString(event);

    // Build description
    final description = _buildDescription(event);

    // Build Google Calendar URL
    final params = {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '$startTime/$endTime',
      'details': description,
      'location': location,
      'sf': 'true',
      'output': 'xml',
    };

    final queryString = params.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://www.google.com/calendar/render?$queryString';
  }

  /// Formats DateTime to Google Calendar format (YYYYMMDDTHHmmssZ)
  static String _formatDateForGoogle(DateTime date) {
    // Convert to UTC for Google Calendar
    final utc = date.toUtc();
    return '${utc.year}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }

  /// Builds location string from event data
  static String _buildLocationString(Event event) {
    final parts = <String>[];

    if (event.venue != null && event.venue!.isNotEmpty) {
      parts.add(event.venue!);
    }

    if (event.address != null && event.address!.isNotEmpty) {
      parts.add(event.address!);
    }

    if (event.city != null) {
      parts.add(event.city!.name);
    }

    return parts.join(', ');
  }

  /// Builds description for calendar event
  static String _buildDescription(Event event) {
    final parts = <String>[];

    if (event.description != null && event.description!.isNotEmpty) {
      // Strip markdown for cleaner calendar description
      parts.add(_stripMarkdown(event.description!));
    }

    if (event.organiser != null) {
      parts.add('Organized by: ${event.organiser!.fullName}');
    }

    return parts.join('\n\n');
  }

  /// Simple markdown stripper for calendar description
  static String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'~~(.+?)~~'), r'$1') // Strikethrough
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Headers
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1') // Links
        .replaceAll(RegExp(r'`(.+?)`'), r'$1') // Inline code
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '• ') // Bullet lists
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '') // Numbered lists
        .trim();
  }

  /// Opens Google Calendar with event details
  static Future<bool> addToGoogleCalendar(Event event) async {
    final url = generateGoogleCalendarUrl(event);
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
