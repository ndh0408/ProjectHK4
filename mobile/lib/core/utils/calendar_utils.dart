import 'package:url_launcher/url_launcher.dart';
import '../../shared/models/event.dart';

class CalendarUtils {
  static String generateGoogleCalendarUrl(Event event) {
    final startTime = _formatDateForGoogle(event.startTime);
    final endTime = _formatDateForGoogle(event.endTime);

    final location = _buildLocationString(event);

    final description = _buildDescription(event);

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

  static String _formatDateForGoogle(DateTime date) {
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

  static String _buildDescription(Event event) {
    final parts = <String>[];

    if (event.description != null && event.description!.isNotEmpty) {
      parts.add(_stripMarkdown(event.description!));
    }

    if (event.organiser != null) {
      parts.add('Organized by: ${event.organiser!.fullName}');
    }

    return parts.join('\n\n');
  }

  static String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'~~(.+?)~~'), r'$1')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        .trim();
  }

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
