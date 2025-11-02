import 'package:flutter/material.dart';
import 'pakistan_time.dart';

enum DateGroup {
  today,
  yesterday,
  dayBeforeYesterday,
  lastWeek,
  lastMonth,
  older,
}

class DateGroupingUtils {
  static DateGroup getDateGroup(DateTime date) {
    // Use PakistanTime for consistent timezone handling
    final now = PakistanTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBeforeYesterday = today.subtract(const Duration(days: 2));
    final lastWeekStart = today.subtract(const Duration(days: 7));
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    
    // Convert date to Pakistan time for comparison
    final dateInPakistanTime = PakistanTime.toPakistanTime(date);
    final dateOnly = DateTime(dateInPakistanTime.year, dateInPakistanTime.month, dateInPakistanTime.day);
    
    if (dateOnly == today) {
      return DateGroup.today;
    } else if (dateOnly == yesterday) {
      return DateGroup.yesterday;
    } else if (dateOnly == dayBeforeYesterday) {
      return DateGroup.dayBeforeYesterday;
    } else if (dateOnly.isAfter(lastWeekStart) && dateOnly.isBefore(today)) {
      return DateGroup.lastWeek;
    } else if (dateOnly.isAfter(lastMonthStart) && dateOnly.isBefore(lastWeekStart)) {
      return DateGroup.lastMonth;
    } else {
      return DateGroup.older;
    }
  }
  
  static String getDateGroupTitle(DateGroup group) {
    switch (group) {
      case DateGroup.today:
        return 'Today';
      case DateGroup.yesterday:
        return 'Yesterday';
      case DateGroup.dayBeforeYesterday:
        return 'Day Before Yesterday';
      case DateGroup.lastWeek:
        return 'Last Week';
      case DateGroup.lastMonth:
        return 'Last Month';
      case DateGroup.older:
        return 'Older';
    }
  }
  
  static Color getDateGroupColor(DateGroup group) {
    switch (group) {
      case DateGroup.today:
        return Colors.green;
      case DateGroup.yesterday:
        return Colors.blue;
      case DateGroup.dayBeforeYesterday:
        return Colors.orange;
      case DateGroup.lastWeek:
        return Colors.purple;
      case DateGroup.lastMonth:
        return Colors.brown;
      case DateGroup.older:
        return Colors.grey;
    }
  }
  
  static String formatDate(DateTime date) {
    // Use PakistanTime for consistent timezone handling
    final now = PakistanTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBeforeYesterday = today.subtract(const Duration(days: 2));
    
    // Convert date to Pakistan time for display
    final dateInPakistanTime = PakistanTime.toPakistanTime(date);
    final dateOnly = DateTime(dateInPakistanTime.year, dateInPakistanTime.month, dateInPakistanTime.day);
    
    if (dateOnly == today) {
      return 'Today, ${_formatTime(dateInPakistanTime)}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, ${_formatTime(dateInPakistanTime)}';
    } else if (dateOnly == dayBeforeYesterday) {
      return 'Day Before Yesterday, ${_formatTime(dateInPakistanTime)}';
    } else {
      return '${_formatDate(dateInPakistanTime)}, ${_formatTime(dateInPakistanTime)}';
    }
  }
  
  static String _formatTime(DateTime date) {
    // Use PakistanTime for formatting
    final pakistanDate = PakistanTime.toPakistanTime(date);
    final hour = pakistanDate.hour;
    final minute = pakistanDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
  
  static String _formatDate(DateTime date) {
    // Use PakistanTime for formatting
    final pakistanDate = PakistanTime.toPakistanTime(date);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${pakistanDate.day} ${months[pakistanDate.month - 1]} ${pakistanDate.year}';
  }
  
  static Map<DateGroup, List<T>> groupItemsByDate<T>(
    List<T> items,
    DateTime Function(T) getDate,
  ) {
    final Map<DateGroup, List<T>> grouped = {};
    
    // Initialize all groups
    for (final group in DateGroup.values) {
      grouped[group] = [];
    }
    
    // Group items
    for (final item in items) {
      final date = getDate(item);
      final group = getDateGroup(date);
      grouped[group]!.add(item);
    }
    
    // Sort items within each group by date (newest first - recently added at top)
    for (final group in DateGroup.values) {
      grouped[group]!.sort((a, b) {
        final dateA = getDate(a);
        final dateB = getDate(b);
        // Convert to Pakistan time for consistent comparison
        final pakistanDateA = PakistanTime.toPakistanTime(dateA);
        final pakistanDateB = PakistanTime.toPakistanTime(dateB);
        // Sort newest first (descending order)
        return pakistanDateB.compareTo(pakistanDateA);
      });
    }
    
    return grouped;
  }
  
  static List<DateGroup> getOrderedGroups() {
    return [
      DateGroup.today,
      DateGroup.yesterday,
      DateGroup.dayBeforeYesterday,
      DateGroup.lastWeek,
      DateGroup.lastMonth,
      DateGroup.older,
    ];
  }
}
