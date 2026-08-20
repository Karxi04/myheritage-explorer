import 'package:flutter_test/flutter_test.dart';
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
      startsWith(
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/',
      ),
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
    expect(List<String>.from(resolved['scheduleNotes']), ['Move this earlier.']);
  });
}
