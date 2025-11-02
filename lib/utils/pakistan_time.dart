import 'package:intl/intl.dart';

class PakistanTime {
  /// Get current time in Pakistan timezone (UTC+5)
  static DateTime now() {
    final now = DateTime.now().toUtc();
    // Add 5 hours to convert to Pakistan time (PKT = UTC+5)
    return now.add(const Duration(hours: 5));
  }

  /// Convert a DateTime to Pakistan timezone
  static DateTime toPakistanTime(DateTime dateTime) {
    final utcDate = dateTime.toUtc();
    // Add 5 hours to convert to Pakistan time (PKT = UTC+5)
    return utcDate.add(const Duration(hours: 5));
  }

  /// Initialize timezone data (no-op for simplicity)
  static Future<void> initialize() async {
    // No initialization needed for simple UTC+5 offset
  }

  /// Format DateTime to Pakistan time format
  static String formatDateTime(DateTime dateTime, {String pattern = 'dd MMM yyyy, hh:mm a'}) {
    final pakistanTime = toPakistanTime(dateTime);
    
    // Create a formatter in Pakistan timezone
    final formatter = DateFormat(pattern);
    return formatter.format(pakistanTime);
  }

  /// Format date only (without time)
  static String formatDate(DateTime dateTime, {String pattern = 'dd MMM yyyy'}) {
    final pakistanTime = toPakistanTime(dateTime);
    return DateFormat(pattern).format(pakistanTime);
  }

  /// Format time only
  static String formatTime(DateTime dateTime, {String pattern = 'hh:mm a'}) {
    final pakistanTime = toPakistanTime(dateTime);
    return DateFormat(pattern).format(pakistanTime);
  }
}
