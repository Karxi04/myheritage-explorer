import 'package:flutter/material.dart';

/// Comprehensive date and time validation service for the Daily Planner.
class DailyPlannerDateValidator {
  /// Check if a date is today or in the future compared to [now].
  /// Uses local device time and compares date components only.
  static bool isDateValid(DateTime selectedDate, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return !target.isBefore(today);
  }

  /// Check if two dates represent the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Check if end date is on or after start date.
  static bool isDateRangeValid(DateTime startDate, DateTime endDate) {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !e.isBefore(s);
  }

  /// Construct a complete local DateTime for the start of the trip / day.
  static DateTime constructStartDateTime({
    required DateTime date,
    required int hour,
    required int minute,
  }) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Construct a complete local DateTime for the end of the day based on available hours.
  /// Correctly handles cross-midnight day rollover (e.g. 10 PM + 4 hrs = 2 AM next day).
  static DateTime calculateEndDateTime({
    required DateTime startDateTime,
    required double availableHours,
  }) {
    final totalMinutes = (availableHours * 60).round();
    return startDateTime.add(Duration(minutes: totalMinutes));
  }

  /// Validates start date and time against current local time.
  /// - If date is in the past: returns past date error.
  /// - If date is future: all times are allowed (returns null).
  /// - If date is today: checks if selected time is before current minute.
  ///   Uses minute precision so a few seconds delay is never rejected.
  /// - If [isFromGenerateButton] is true, returns the specific generate error message.
  static String? validateStartDateTime({
    required DateTime startDate,
    required int startHour,
    required int startMinute,
    DateTime? now,
    bool isFromGenerateButton = false,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final sDateOnly = DateTime(startDate.year, startDate.month, startDate.day);

    if (sDateOnly.isBefore(today)) {
      return 'Start date cannot be in the past. Please select today or a future date.';
    }

    final isToday = sDateOnly.isAtSameMomentAs(today);
    if (!isToday) {
      // Future date: all times allowed!
      return null;
    }

    // Today: compare against current minute
    final selectedStartDt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startHour,
      startMinute,
    );
    final nowMinute = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    );

    if (selectedStartDt.isBefore(nowMinute)) {
      if (isFromGenerateButton) {
        return 'Your selected start time has already passed. Please choose a new start time.';
      } else {
        return 'Please select a time later than the current time.';
      }
    }

    return null;
  }

  /// Check whether a selected time is in the past for the given target date.
  /// Returns true ONLY if target date is today AND time is before current minute.
  static bool isTimeInPastForDate({
    required DateTime targetDate,
    required int startHour,
    required int startMinute,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (!targetDateOnly.isAtSameMomentAs(today)) {
      return false; // Future dates are never past
    }

    final selectedDt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      startHour,
      startMinute,
    );
    final nowMinute = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    );
    return selectedDt.isBefore(nowMinute);
  }

  /// Given the current local time, get a suggested initial valid start time for today.
  static TimeOfDay getSuggestedStartTimeForToday({DateTime? now}) {
    final current = now ?? DateTime.now();
    var nextHour = current.hour;
    var nextMinute = current.minute < 30 ? 30 : 0;
    if (current.minute >= 30) {
      nextHour = (nextHour + 1) % 24;
    }
    return TimeOfDay(hour: nextHour, minute: nextMinute);
  }
}
