import '../services/malaysia_location_service.dart';

class DaySchedulePreference {
  const DaySchedulePreference({
    required this.dayNumber,
    required this.date,
    required this.startMinutes,
    required this.availableHours,
  });

  final int dayNumber;
  final DateTime date;
  final int startMinutes; // minutes from midnight, e.g. 9 * 60 = 540
  final double availableHours; // e.g. 4.0, 5.0, 6.0, 8.0

  int get startHour => (startMinutes ~/ 60) % 24;
  int get startMinute => startMinutes % 60;
  int get availableMinutes => (availableHours * 60).round();

  String get startTimeLabel {
    final h = startHour;
    final m = startMinute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  String get endTimeLabel {
    final endMinutes = startMinutes + availableMinutes;
    final h = (endMinutes ~/ 60) % 24;
    final m = endMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  DateTime calculateStartDateTime() {
    return DateTime(date.year, date.month, date.day, startHour, startMinute);
  }

  DateTime calculateEndDateTime() {
    final startDt = calculateStartDateTime();
    return startDt.add(Duration(minutes: availableMinutes));
  }

  DaySchedulePreference copyWith({
    int? dayNumber,
    DateTime? date,
    int? startMinutes,
    double? availableHours,
  }) {
    return DaySchedulePreference(
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      startMinutes: startMinutes ?? this.startMinutes,
      availableHours: availableHours ?? this.availableHours,
    );
  }

  Map<String, dynamic> toMap() => {
    'dayNumber': dayNumber,
    'date': date.toIso8601String(),
    'startMinutes': startMinutes,
    'availableHours': availableHours,
    'availableMinutes': availableMinutes,
    'startTimeLabel': startTimeLabel,
    'endTimeLabel': endTimeLabel,
  };

  factory DaySchedulePreference.fromMap(Map<String, dynamic> map) {
    final dVal = map['date'];
    DateTime d = DateTime.now();
    if (dVal is String) {
      d = DateTime.tryParse(dVal) ?? DateTime.now();
    }
    return DaySchedulePreference(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 1,
      date: d,
      startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 540,
      availableHours: (map['availableHours'] as num?)?.toDouble() ?? 4.0,
    );
  }
}

class TravelPreferences {
  TravelPreferences({
    required this.stateId,
    String? stateName,
    String selectedArea = 'All Areas',
    List<String>? selectedAreas,
    this.travelAreaMode = 'single',
    DateTime? startDate,
    DateTime? endDate,
    this.dailyStartMinutes = 540,
    this.availableHours = 4.0,
    this.interests = const ['Heritage', 'Culture', 'Food'],
    this.budget = 'Medium',
    this.pace = 'Balanced',
    this.foodExplorationEnabled = false,
    this.scheduleMode = 'same', // 'same' or 'custom'
    List<DaySchedulePreference>? daySchedules,
  })  : stateName = stateName ?? MalaysiaLocationService.getStateName(stateId),
        selectedAreas = travelAreaMode == 'multiple'
            ? (selectedAreas ?? const <String>[])
            : (selectedAreas != null && selectedAreas.isNotEmpty
                ? selectedAreas
                : (selectedArea.isNotEmpty && selectedArea != 'All Areas' ? [selectedArea] : const <String>[])),
        selectedArea = travelAreaMode == 'multiple'
            ? ((selectedAreas != null && selectedAreas.isNotEmpty)
                ? selectedAreas.join(', ')
                : '')
            : selectedArea,
        startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? (startDate ?? DateTime.now()),
        daySchedules = daySchedules ?? const <DaySchedulePreference>[];

  final String stateId;
  final String stateName;
  final String selectedArea;
  final List<String> selectedAreas;
  final String travelAreaMode; // 'single' or 'multiple'
  final DateTime startDate;
  final DateTime endDate;
  final int dailyStartMinutes; // e.g. 9 * 60 = 540
  final double availableHours;
  final List<String> interests;
  final String budget; // 'Low', 'Medium', 'High'
  final String pace; // 'Relaxed', 'Balanced', 'Fast'
  final bool foodExplorationEnabled;
  final String scheduleMode; // 'same' or 'custom'
  final List<DaySchedulePreference> daySchedules;

  bool get isMultiAreaMode => travelAreaMode == 'multiple';
  bool get isCustomScheduleMode => scheduleMode == 'custom';
  bool get isValid => validate(allowPastDates: true) == null;

  static double calculateAvailableHoursFromTimes({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    final startM = startHour * 60 + startMinute;
    var endM = endHour * 60 + endMinute;
    if (endM <= startM) {
      endM += 24 * 60; // Crosses midnight to next day
    }
    return (endM - startM) / 60.0;
  }

  int get numberOfDays {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = e.difference(s).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  int get dayCount => numberOfDays;

  int get maxSelectableAreas => numberOfDays * 5;

  List<DaySchedulePreference> getEffectiveDaySchedules() {
    final totalDays = numberOfDays;
    final list = <DaySchedulePreference>[];
    for (int i = 0; i < totalDays; i++) {
      final dayDate = DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: i));
      if (isCustomScheduleMode && i < daySchedules.length) {
        list.add(daySchedules[i]);
      } else {
        list.add(DaySchedulePreference(
          dayNumber: i + 1,
          date: dayDate,
          startMinutes: dailyStartMinutes,
          availableHours: availableHours,
        ));
      }
    }
    return list;
  }

  String get dailyStartTimeLabel {
    final h = (dailyStartMinutes ~/ 60) % 24;
    final m = dailyStartMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  String get dailyEndTimeLabel {
    final endMinutes = dailyStartMinutes + (availableHours * 60).round();
    final h = (endMinutes ~/ 60) % 24;
    final m = endMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  DateTime calculateStartDateTime({DateTime? date}) {
    final baseDate = date ?? startDate;
    final h = (dailyStartMinutes ~/ 60) % 24;
    final m = dailyStartMinutes % 60;
    return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
  }

  DateTime calculateEndDateTime({DateTime? date}) {
    final startDt = calculateStartDateTime(date: date);
    final totalMinutes = (availableHours * 60).round();
    return startDt.add(Duration(minutes: totalMinutes));
  }

  String? validate({DateTime? currentTime, bool allowPastDates = false}) {
    if (stateId.trim().isEmpty || stateName.trim().isEmpty) {
      return 'Please select a Malaysian state.';
    }
    if (isMultiAreaMode) {
      if (selectedAreas.isEmpty) {
        return 'Please select at least one area in $stateName.';
      }
      final maxAllowedAreas = maxSelectableAreas;
      if (selectedAreas.length > maxAllowedAreas) {
        return 'You can select up to $maxAllowedAreas areas for this $numberOfDays-day trip.';
      }
      for (final a in selectedAreas) {
        if (!MalaysiaLocationService.isAreaInState(a, stateId)) {
          return 'Selected area "$a" does not belong to $stateName. Cross-state itineraries are not permitted.';
        }
      }
    } else {
      if (selectedArea.trim().isEmpty) {
        return 'Please select an area or city in $stateName.';
      }
      if (!MalaysiaLocationService.isAreaInState(selectedArea, stateId)) {
        return 'Selected area "$selectedArea" does not belong to $stateName.';
      }
    }
    if (interests.isEmpty) {
      return 'Please select at least one travel interest.';
    }
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    if (e.isBefore(s)) {
      return 'End date cannot be before start date.';
    }
    if (numberOfDays < 1) {
      return 'Itinerary duration must be at least 1 day.';
    }

    final dayConfigs = getEffectiveDaySchedules();
    final now = currentTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    for (int i = 0; i < dayConfigs.length; i++) {
      final d = dayConfigs[i];
      final dDateOnly = DateTime(d.date.year, d.date.month, d.date.day);
      if (dDateOnly.isBefore(today) && !allowPastDates) {
        return 'Start date cannot be in the past. Please select today or a future date.';
      }
      final isToday = dDateOnly.isAtSameMomentAs(today);
      if (isToday && !allowPastDates) {
        final dayStartDt = DateTime(d.date.year, d.date.month, d.date.day, d.startHour, d.startMinute);
        if (dayStartDt.isBefore(nowMinute)) {
          if (i == 0) {
            return 'Your Day 1 start time has already passed. Please choose a later start time for today.';
          } else {
            return 'Your selected start time for Day ${i + 1} has already passed. Please choose a new start time.';
          }
        }
      }
      if (d.availableHours <= 0 || d.availableHours > 24) {
        return 'Daily available hours for Day ${i + 1} must be between 1 and 24 hours.';
      }
    }

    return null;
  }
}
