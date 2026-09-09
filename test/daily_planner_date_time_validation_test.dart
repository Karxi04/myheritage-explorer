import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/travel_preferences_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/daily_planner_date_validator.dart';

void main() {
  group('Daily Planner Date & Time Validation Tests (TEST 1 - TEST 7)', () {
    // Reference local simulated time: 9 Sep 2026, 12:00:35 PM
    final mockToday = DateTime(2026, 9, 9, 12, 0, 35);

    test('TEST 1: Date Validation - Date before today cannot be selected', () {
      final pastDate = DateTime(2026, 9, 8);
      final todayDate = DateTime(2026, 9, 9);
      final futureDate = DateTime(2026, 9, 10);

      expect(DailyPlannerDateValidator.isDateValid(pastDate, now: mockToday), isFalse,
          reason: '8 Sep 2026 is in the past and must not be selectable.');
      expect(DailyPlannerDateValidator.isDateValid(todayDate, now: mockToday), isTrue,
          reason: '9 Sep 2026 (Today) must be selectable.');
      expect(DailyPlannerDateValidator.isDateValid(futureDate, now: mockToday), isTrue,
          reason: '10 Sep 2026 (Future) must be selectable.');
    });

    test('TEST 2: Today + Past Time - 9 Sep + 10:00 AM is blocked when local time is 12:00 PM', () {
      final error = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 9),
        startHour: 10,
        startMinute: 0,
        now: mockToday,
        isFromGenerateButton: false,
      );

      expect(error, isNotNull);
      expect(error, equals('Please select a time later than the current time.'));
    });

    test('TEST 3: Today + Future Time - 9 Sep + 1:00 PM is allowed when local time is 12:00 PM', () {
      final error = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 9),
        startHour: 13,
        startMinute: 0,
        now: mockToday,
        isFromGenerateButton: false,
      );

      expect(error, isNull, reason: '1:00 PM is after 12:00 PM today and should be allowed.');
    });

    test('TEST 4: Future Date - 10 Sep + 9:00 AM is allowed without current time restriction', () {
      final error = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 10),
        startHour: 9,
        startMinute: 0,
        now: mockToday,
        isFromGenerateButton: false,
      );

      expect(error, isNull, reason: 'Future dates should allow morning times like 9:00 AM.');
    });

    test('TEST 5: Date change to Today triggers revalidation and detects past time', () {
      // User initially picked 10 Sep + 9:00 AM
      const selectedHour = 9;
      const selectedMinute = 0;

      // When date is 10 Sep (future), it is not in the past
      final isPastOn10th = DailyPlannerDateValidator.isTimeInPastForDate(
        targetDate: DateTime(2026, 9, 10),
        startHour: selectedHour,
        startMinute: selectedMinute,
        now: mockToday,
      );
      expect(isPastOn10th, isFalse);

      // When user changes date to 9 Sep (today, 12 PM), 9:00 AM is in the past
      final isPastOn9th = DailyPlannerDateValidator.isTimeInPastForDate(
        targetDate: DateTime(2026, 9, 9),
        startHour: selectedHour,
        startMinute: selectedMinute,
        now: mockToday,
      );
      expect(isPastOn9th, isTrue, reason: '9:00 AM on today (12:00 PM) must be flagged as in the past.');

      // Auto-suggested start time for today should be in the future
      final suggested = DailyPlannerDateValidator.getSuggestedStartTimeForToday(now: mockToday);
      final suggestedStartDt = DateTime(2026, 9, 9, suggested.hour, suggested.minute);
      expect(suggestedStartDt.isAfter(mockToday) || suggestedStartDt.isAtSameMomentAs(DateTime(2026, 9, 9, 12, 0)), isTrue);
    });

    test('TEST 6: Start today 10 PM + 4 hours ends tomorrow at 2 AM', () {
      final startDt = DateTime(2026, 9, 9, 22, 0); // 10:00 PM
      final endDt = DailyPlannerDateValidator.calculateEndDateTime(
        startDateTime: startDt,
        availableHours: 4.0,
      );

      expect(endDt.day, equals(10), reason: 'Crosses midnight to the 10th of September.');
      expect(endDt.hour, equals(2), reason: '22:00 + 4h = 02:00 AM.');
      expect(endDt.minute, equals(0));

      final pref = TravelPreferences(
        stateId: 'penang',
        startDate: DateTime(2026, 9, 9),
        endDate: DateTime(2026, 9, 9),
        dailyStartMinutes: 22 * 60, // 10:00 PM
        availableHours: 4.0,
      );

      expect(pref.dailyStartTimeLabel, equals('10:00 PM'));
      expect(pref.dailyEndTimeLabel, equals('2:00 AM'));
      final calculatedEnd = pref.calculateEndDateTime();
      expect(calculatedEnd.day, equals(10));
      expect(calculatedEnd.hour, equals(2));
    });

    test('TEST 7: Generate button revalidates and blocks if start time passed while staying on page', () {
      // User picked 12:00 PM start time when arriving at 11:58 AM
      const startHour = 12;
      const startMinute = 0;

      // User leaves page open until 12:05 PM
      final timeLater = DateTime(2026, 9, 9, 12, 5, 0);

      final generateError = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 9),
        startHour: startHour,
        startMinute: startMinute,
        now: timeLater,
        isFromGenerateButton: true,
      );

      expect(generateError, isNotNull);
      expect(generateError, equals('Your selected start time has already passed. Please choose a new start time.'));
    });

    test('Requirement 5: Small clock delay / minute precision allows current minute', () {
      // Now is 12:00:35 PM. Selecting 12:00 PM or 12:01 PM should be valid!
      final errorSameMinute = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 9),
        startHour: 12,
        startMinute: 0,
        now: mockToday, // 12:00:35
      );
      expect(errorSameMinute, isNull, reason: 'Current minute is valid and not rejected by few seconds delay.');

      final errorNextMinute = DailyPlannerDateValidator.validateStartDateTime(
        startDate: DateTime(2026, 9, 9),
        startHour: 12,
        startMinute: 1,
        now: mockToday, // 12:00:35
      );
      expect(errorNextMinute, isNull, reason: 'Next minute 12:01 PM is valid.');
    });

    test('Requirement 1: Date range validation blocks end date before start date', () {
      final validRange = DailyPlannerDateValidator.isDateRangeValid(
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 11),
      );
      expect(validRange, isTrue);

      final invalidRange = DailyPlannerDateValidator.isDateRangeValid(
        DateTime(2026, 9, 11),
        DateTime(2026, 9, 9),
      );
      expect(invalidRange, isFalse);
    });
  });
}
