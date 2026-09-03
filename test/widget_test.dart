import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';

void main() {
  test('basic Flutter test environment works', () {
    expect(1 + 1, 2);
  });

  test('review model flags negative text with a high star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Terrible experience, dirty display, rude service and not recommended.',
      rating: 5,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });

  test('review model flags positive text with a low star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Excellent cultural stop with friendly staff and a wonderful visit.',
      rating: 1,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });

  test('itinerary schedule recalculates when stops are reordered', () {
    final stops = [
      {
        'name': 'First Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4141, 'longitude': 100.3288},
      },
      {
        'name': 'Second Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4160, 'longitude': 100.3310},
      },
      {
        'name': 'Third Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4200, 'longitude': 100.3380},
      },
    ];

    final original = ItinerarySchedulePlanner.plan(
      stops: stops,
      pace: 'Balanced',
      availableHours: 4,
    );
    final reordered = ItinerarySchedulePlanner.plan(
      stops: [stops[2], stops[0], stops[1]],
      pace: 'Balanced',
      availableHours: 4,
    );

    expect(original.stops.first['name'], 'First Stop');
    expect(original.stops.first['suggestedTimeLabel'], '9:00 AM - 10:00 AM');
    expect(reordered.stops.first['name'], 'Third Stop');
    expect(reordered.stops.first['suggestedTimeLabel'], '9:00 AM - 10:00 AM');
    expect(reordered.stops[1]['sequence'], 2);
    expect((reordered.stops[1]['travelMinutesBefore'] as num) > 0, isTrue);
  });

  test('itinerary schedule warns when visit runs past closing', () {
    final schedule = ItinerarySchedulePlanner.plan(
      stops: [
        {
          'name': 'Early Closing Stop',
          'durationMinutes': 90,
          'openingHours': '9:00-10:00',
          'location': {'latitude': 5.4141, 'longitude': 100.3288},
        },
      ],
      pace: 'Balanced',
      availableHours: 2,
    );

    final notes = List<String>.from(schedule.stops.first['scheduleNotes']);
    expect(notes, isNotEmpty);
    expect(notes.first, contains('closing'));
  });

  test('itinerary image candidates keep online fallback urls', () {
    final candidates = ItineraryImageResolver.imageCandidatesFor({
      'imageUrl': 'https://example.com/broken.jpg',
      'imageCandidates': [
        'https://example.com/broken.jpg',
        'https://commons.wikimedia.org/wiki/File:Khoo_Kongsi.jpg',
      ],
      'fallbackImageUrl': 'https://maps.geoapify.com/v1/staticmap?x=1',
    });

    expect(candidates, hasLength(3));
    expect(candidates.first, 'https://example.com/broken.jpg');
    expect(
      candidates[1],
      startsWith('https://commons.wikimedia.org/wiki/Special:Redirect/file/'),
    );
  });

  test('cached image resolution keeps latest timeline fields', () async {
    ItineraryImageResolver.clearCache();
    await ItineraryImageResolver.resolveStop({
      'name': 'Cache Timeline Stop',
      'imageUrl': 'https://example.com/photo.jpg',
      'photoUrl': 'https://example.com/photo-2.jpg',
      'thumbnailUrl': 'https://example.com/photo-3.jpg',
    });

    final resolved = await ItineraryImageResolver.resolveStop({
      'name': 'Cache Timeline Stop',
      'imageUrl': 'https://example.com/photo.jpg',
      'photoUrl': 'https://example.com/photo-2.jpg',
      'thumbnailUrl': 'https://example.com/photo-3.jpg',
      'suggestedTimeLabel': '10:00 AM - 11:00 AM',
      'suggestedStartMinutes': 600,
      'suggestedEndMinutes': 660,
      'scheduleNotes': ['Move this earlier.'],
    });

    expect(resolved['suggestedTimeLabel'], '10:00 AM - 11:00 AM');
    expect(resolved['suggestedStartMinutes'], 600);
    expect(List<String>.from(resolved['scheduleNotes']), [
      'Move this earlier.',
    ]);
  });

  test(
    'named itinerary destinations do not accept another same-state area',
    () {
      final destination = MalaysianAreaSearchEngine.findSpecificSubArea(
        'Bukit Mertajam, Pulau Pinang',
      );

      expect(destination?.name, 'Bukit Mertajam');
      expect(
        MalaysianAreaSearchEngine.matchesSpecificDestination(
          selectedArea: 'Bukit Mertajam, Pulau Pinang',
          vendorAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang',
        ),
        isTrue,
      );
      expect(
        MalaysianAreaSearchEngine.matchesSpecificDestination(
          selectedArea: 'Bukit Mertajam, Pulau Pinang',
          vendorAddress: 'Armenian Street, George Town, Penang',
        ),
        isFalse,
      );
    },
  );

  test('destination aliases resolve while a state-wide choice stays broad', () {
    expect(
      MalaysianAreaSearchEngine.findSpecificSubArea(
        'Georgetown, Pulau Pinang',
      )?.name,
      'George Town',
    );
    expect(
      MalaysianAreaSearchEngine.findSpecificSubArea('Penang, Malaysia'),
      isNull,
    );
  });

  test('trip reminders prefer 3 days before and fall back to 2 days', () {
    final tripStart = DateTime(2026, 9, 10, 9);

    final threeDayReminder = AppServices.nextTripReminderTime(
      tripStartDate: tripStart,
      now: DateTime(2026, 9, 1, 12),
    );
    expect(threeDayReminder, DateTime(2026, 9, 7, 8));
    expect(
      AppServices.tripReminderLeadDays(
        tripStartDate: tripStart,
        reminderTime: threeDayReminder!,
      ),
      3,
    );

    final twoDayReminder = AppServices.nextTripReminderTime(
      tripStartDate: tripStart,
      now: DateTime(2026, 9, 7, 9),
    );
    expect(twoDayReminder, DateTime(2026, 9, 8, 8));
    expect(
      AppServices.tripReminderLeadDays(
        tripStartDate: tripStart,
        reminderTime: twoDayReminder!,
      ),
      2,
    );
  });

  test('curated place image resolver assigns unique distinct photos', () async {
    final stop1 = await ItineraryImageResolver.resolveStop({
      'name': 'Mengkuang Dam Lakeside Park',
      'category': 'Nature',
    });
    final stop2 = await ItineraryImageResolver.resolveStop({
      'name': 'Chew Jetty',
      'category': 'Heritage',
    });
    final stop3 = await ItineraryImageResolver.resolveStop({
      'name': 'Restoran BM Yam Rice',
      'category': 'Food',
    });

    expect(stop1['imageUrl'], isNotEmpty);
    expect(stop2['imageUrl'], isNotEmpty);
    expect(stop3['imageUrl'], isNotEmpty);

    // Verify all 3 stops have different, distinct images
    expect(stop1['imageUrl'], isNot(equals(stop2['imageUrl'])));
    expect(stop1['imageUrl'], isNot(equals(stop3['imageUrl'])));
    expect(stop2['imageUrl'], isNot(equals(stop3['imageUrl'])));
  });
}
