import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/travel_preferences_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/meal_planning_service.dart';

void main() {
  group('Daily Planner Multi-Day Scheduling Tests', () {
    final mockToday = DateTime(2026, 9, 9, 12, 0, 0); // 12:00 PM on 9 Sep 2026

    test('TEST 1: Same schedule every day - 3 days with 9:00 AM + 8h generates 9:00 AM -> 5:00 PM for all days', () {
      final tripStart = DateTime(2026, 9, 10); // Future date
      final tripEnd = DateTime(2026, 9, 12); // 3 days

      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'same',
        dailyStartMinutes: 9 * 60, // 9:00 AM
        availableHours: 8.0, // 8 hours
        interests: ['Heritage', 'Culture'],
      );

      expect(prefs.numberOfDays, equals(3));
      expect(prefs.scheduleMode, equals('same'));

      final effectiveSchedules = prefs.getEffectiveDaySchedules();
      expect(effectiveSchedules.length, equals(3));

      for (int i = 0; i < 3; i++) {
        final daySched = effectiveSchedules[i];
        expect(daySched.dayNumber, equals(i + 1));
        expect(daySched.startMinutes, equals(540));
        expect(daySched.availableHours, equals(8.0));
        expect(daySched.startTimeLabel, equals('9:00 AM'));
        expect(daySched.endTimeLabel, equals('5:00 PM'));
        expect(daySched.calculateStartDateTime().hour, equals(9));
        expect(daySched.calculateEndDateTime().hour, equals(17));
      }

      final error = prefs.validate(currentTime: mockToday);
      expect(error, isNull);
    });

    test('TEST 2: Customize each day - Day 1 (1 PM/5h), Day 2 (9 AM/8h), Day 3 (10 AM/6h)', () {
      final tripStart = DateTime(2026, 9, 9);
      final tripEnd = DateTime(2026, 9, 11);

      final customDays = [
        DaySchedulePreference(
          dayNumber: 1,
          date: DateTime(2026, 9, 9),
          startMinutes: 13 * 60, // 1:00 PM
          availableHours: 5.0, // 5 hours -> 6:00 PM
        ),
        DaySchedulePreference(
          dayNumber: 2,
          date: DateTime(2026, 9, 10),
          startMinutes: 9 * 60, // 9:00 AM
          availableHours: 8.0, // 8 hours -> 5:00 PM
        ),
        DaySchedulePreference(
          dayNumber: 3,
          date: DateTime(2026, 9, 11),
          startMinutes: 10 * 60, // 10:00 AM
          availableHours: 6.0, // 6 hours -> 4:00 PM
        ),
      ];

      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'custom',
        daySchedules: customDays,
        interests: ['Heritage'],
      );

      expect(prefs.numberOfDays, equals(3));
      expect(prefs.isCustomScheduleMode, isTrue);

      final effectiveSchedules = prefs.getEffectiveDaySchedules();
      expect(effectiveSchedules.length, equals(3));

      // Day 1 check
      expect(effectiveSchedules[0].startTimeLabel, equals('1:00 PM'));
      expect(effectiveSchedules[0].endTimeLabel, equals('6:00 PM'));
      expect(effectiveSchedules[0].availableHours, equals(5.0));

      // Day 2 check
      expect(effectiveSchedules[1].startTimeLabel, equals('9:00 AM'));
      expect(effectiveSchedules[1].endTimeLabel, equals('5:00 PM'));
      expect(effectiveSchedules[1].availableHours, equals(8.0));

      // Day 3 check
      expect(effectiveSchedules[2].startTimeLabel, equals('10:00 AM'));
      expect(effectiveSchedules[2].endTimeLabel, equals('4:00 PM'));
      expect(effectiveSchedules[2].availableHours, equals(6.0));

      // Validation passes because Day 1 is 1:00 PM (after 12:00 PM) and future days can start anytime
      final error = prefs.validate(currentTime: mockToday);
      expect(error, isNull);
    });

    test('TEST 3: Today 12 PM with 9 AM start in Same mode blocks Day 1, but Custom mode allows 1 PM for Day 1 and 9 AM for Day 2/3', () {
      final tripStart = DateTime(2026, 9, 9); // Today
      final tripEnd = DateTime(2026, 9, 11); // 3 days

      // In Same Mode with 9:00 AM:
      final samePrefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'same',
        dailyStartMinutes: 9 * 60, // 9:00 AM (past for today 12:00 PM!)
        availableHours: 8.0,
        interests: ['Heritage'],
      );

      final sameError = samePrefs.validate(currentTime: mockToday);
      expect(sameError, equals('Your Day 1 start time has already passed. Please choose a later start time for today.'));

      // In Custom Mode: User changes Day 1 to 1:00 PM while keeping Day 2 & 3 at 9:00 AM
      final customPrefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'custom',
        daySchedules: [
          DaySchedulePreference(
            dayNumber: 1,
            date: DateTime(2026, 9, 9),
            startMinutes: 13 * 60, // 1:00 PM (Valid for today!)
            availableHours: 4.0,
          ),
          DaySchedulePreference(
            dayNumber: 2,
            date: DateTime(2026, 9, 10),
            startMinutes: 9 * 60, // 9:00 AM (Valid because Day 2 is tomorrow!)
            availableHours: 8.0,
          ),
          DaySchedulePreference(
            dayNumber: 3,
            date: DateTime(2026, 9, 11),
            startMinutes: 9 * 60, // 9:00 AM (Valid because Day 3 is in future!)
            availableHours: 8.0,
          ),
        ],
        interests: ['Heritage'],
      );

      final customError = customPrefs.validate(currentTime: mockToday);
      expect(customError, isNull, reason: 'Custom schedule with 1 PM for Day 1 and 9 AM for future days must be valid.');
    });

    test('TEST 4: Switching from Same to Custom populates from common values', () {
      final tripStart = DateTime(2026, 9, 10);
      final tripEnd = DateTime(2026, 9, 12);

      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'same',
        dailyStartMinutes: 10 * 60, // 10:00 AM
        availableHours: 6.0,
        interests: ['Heritage'],
      );

      final defaultEffective = prefs.getEffectiveDaySchedules();
      expect(defaultEffective.length, equals(3));
      for (final d in defaultEffective) {
        expect(d.startMinutes, equals(600));
        expect(d.availableHours, equals(6.0));
      }
    });

    test('TEST 5: Switching from Custom to Same falls back to common schedule for all days', () {
      final tripStart = DateTime(2026, 9, 10);
      final tripEnd = DateTime(2026, 9, 12);

      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: tripStart,
        endDate: tripEnd,
        scheduleMode: 'same', // User switches back to Same
        dailyStartMinutes: 9 * 60,
        availableHours: 4.0,
        daySchedules: [
          DaySchedulePreference(dayNumber: 1, date: DateTime(2026, 9, 10), startMinutes: 14 * 60, availableHours: 2.0),
          DaySchedulePreference(dayNumber: 2, date: DateTime(2026, 9, 11), startMinutes: 15 * 60, availableHours: 3.0),
        ],
        interests: ['Heritage'],
      );

      final effective = prefs.getEffectiveDaySchedules();
      expect(effective.length, equals(3));
      for (final d in effective) {
        expect(d.startMinutes, equals(540));
        expect(d.availableHours, equals(4.0));
      }
    });

    test('TEST 6: Overnight schedule (10:00 PM + 4 hours) ends at 2:00 AM next day', () {
      final dayPref = DaySchedulePreference(
        dayNumber: 1,
        date: DateTime(2026, 9, 10),
        startMinutes: 22 * 60, // 10:00 PM
        availableHours: 4.0, // 4 hours
      );

      expect(dayPref.startTimeLabel, equals('10:00 PM'));
      expect(dayPref.endTimeLabel, equals('2:00 AM'));

      final startDt = dayPref.calculateStartDateTime();
      final endDt = dayPref.calculateEndDateTime();

      expect(startDt, equals(DateTime(2026, 9, 10, 22, 0)));
      expect(endDt, equals(DateTime(2026, 9, 11, 2, 0)));
      expect(endDt.difference(startDt).inHours, equals(4));
    });

    test('TEST 7: MealPlanningService eligible meal types per distinct day schedule window', () {
      // Day 1: 1:00 PM to 6:00 PM (13:00 -> 18:00)
      final day1Meals = MealPlanningService.getEligibleMealTypes(
        startMinutes: 13 * 60,
        availableMinutes: 5 * 60,
        foodInterestSelected: true,
      );
      expect(day1Meals.contains('Lunch'), isTrue);
      expect(day1Meals.contains('Dinner'), isTrue);
      expect(day1Meals.contains('Breakfast'), isFalse, reason: '13:00 to 18:00 does not include breakfast.');

      // Day 2: 9:00 AM to 5:00 PM (09:00 -> 17:00)
      final day2Meals = MealPlanningService.getEligibleMealTypes(
        startMinutes: 9 * 60,
        availableMinutes: 8 * 60,
        foodInterestSelected: true,
      );
      expect(day2Meals.contains('Breakfast'), isTrue);
      expect(day2Meals.contains('Lunch'), isTrue);
    });
  });
}
