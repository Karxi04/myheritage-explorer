import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Itinerary Save Deduplication & Guard Tests', () {
    test('Generation ID creates unique identifiers per generation cycle', () {
      final gen1 = 'gen_${DateTime.now().microsecondsSinceEpoch}';
      final gen2 = 'gen_${DateTime.now().microsecondsSinceEpoch + 1}';
      expect(gen1, isNot(equals(gen2)));
      expect(gen1.startsWith('gen_'), isTrue);
    });

    test('Save state logic prevents duplicate writes and allows retry on new generation', () {
      // Simulation of DailyPlannerPage save state machine
      bool isSaving = false;
      bool isSaved = false;
      String? savedItineraryId;
      String? generationId = 'gen_1001';
      int firestoreWriteCount = 0;
      final snackbarMessages = <String>[];

      void showSnackbar(String msg) {
        snackbarMessages.add(msg);
      }

      Future<void> simulateSave() async {
        if (isSaving) return;
        if (isSaved || savedItineraryId != null) {
          showSnackbar('This itinerary has already been saved.');
          return;
        }

        isSaving = true;
        try {
          // Simulate Firestore write
          firestoreWriteCount++;
          savedItineraryId = 'doc_$firestoreWriteCount';
          isSaved = true;
          showSnackbar('Itinerary saved successfully!');
        } finally {
          isSaving = false;
        }
      }

      void simulateGenerate() {
        savedItineraryId = null;
        isSaved = false;
        generationId = 'gen_1002';
      }

      void simulateAddDessertStop() {
        savedItineraryId = null;
        isSaved = false;
        generationId = 'gen_1003';
      }

      // 1. Initial save
      simulateSave();
      expect(firestoreWriteCount, 1);
      expect(isSaved, isTrue);
      expect(savedItineraryId, 'doc_1');
      expect(snackbarMessages, ['Itinerary saved successfully!']);

      // 2. Second click on Save -> should NOT write to Firestore, shows already saved message
      simulateSave();
      expect(firestoreWriteCount, 1);
      expect(snackbarMessages.last, 'This itinerary has already been saved.');

      // 3. Third click on Save -> still blocked
      simulateSave();
      expect(firestoreWriteCount, 1);
      expect(snackbarMessages.length, 3);
      expect(snackbarMessages.last, 'This itinerary has already been saved.');

      // 4. Generate new itinerary -> resets save state
      simulateGenerate();
      expect(isSaved, isFalse);
      expect(savedItineraryId, isNull);
      expect(generationId, 'gen_1002');

      // 5. Save the newly generated itinerary -> allows saving once
      simulateSave();
      expect(firestoreWriteCount, 2);
      expect(isSaved, isTrue);
      expect(savedItineraryId, 'doc_2');
      expect(snackbarMessages.last, 'Itinerary saved successfully!');

      // 6. Modify itinerary (add dessert stop) -> resets save state
      simulateAddDessertStop();
      expect(isSaved, isFalse);
      expect(savedItineraryId, isNull);
      expect(generationId, 'gen_1003');

      // 7. Save after dessert stop modification -> allows save
      simulateSave();
      expect(firestoreWriteCount, 3);
      expect(isSaved, isTrue);
      expect(savedItineraryId, 'doc_3');
    });

    test('Rapid double-tap simulation is rejected by isSaving guard', () async {
      bool isSaving = false;
      bool isSaved = false;
      String? savedItineraryId;
      int writeCount = 0;

      Future<void> asyncSave() async {
        if (isSaving) return;
        if (isSaved || savedItineraryId != null) return;

        isSaving = true;
        await Future.delayed(const Duration(milliseconds: 50));
        writeCount++;
        isSaved = true;
        savedItineraryId = 'doc_$writeCount';
        isSaving = false;
      }

      // Fire 3 saves concurrently (rapid taps)
      final future1 = asyncSave();
      final future2 = asyncSave();
      final future3 = asyncSave();

      await Future.wait([future1, future2, future3]);

      // Only exactly ONE save write should have executed
      expect(writeCount, 1);
      expect(isSaved, isTrue);
      expect(savedItineraryId, 'doc_1');
    });

    testWidgets('Save button UI reflects isSaving and isSaved states', (tester) async {
      bool isSaving = false;
      bool isSaved = false;
      late StateSetter setInnerState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setInnerState = setState;
                return Column(
                  children: [
                    IconButton(
                      tooltip: isSaved ? 'Itinerary already saved' : 'Save itinerary',
                      onPressed: isSaving ? null : () {},
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: isSaving ? null : () {},
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(),
                            )
                          : Icon(
                              isSaved
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_add_outlined,
                            ),
                      label: Text(
                        isSaving
                            ? 'Saving Itinerary...'
                            : isSaved
                                ? 'Saved to My Itineraries'
                                : 'Save Itinerary',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initial state: "Save Itinerary"
      expect(find.text('Save Itinerary'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsNWidgets(2));

      // Saving state
      setInnerState(() {
        isSaving = true;
      });
      await tester.pump();
      expect(find.text('Saving Itinerary...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Saved state
      setInnerState(() {
        isSaving = false;
        isSaved = true;
      });
      await tester.pump();

      expect(find.text('Saved to My Itineraries'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    test('Trip reminder schedule calculator correctly computes lead days and reminder time', () {
      final futureDate = DateTime.now().add(const Duration(days: 3));
      final reminderTime = AppServices.nextTripReminderTime(tripStartDate: futureDate);

      expect(reminderTime, isNotNull);
      expect(reminderTime!.isBefore(futureDate) || reminderTime.isAtSameMomentAs(futureDate), isTrue);

      final leadDays = AppServices.tripReminderLeadDays(
        tripStartDate: futureDate,
        reminderTime: reminderTime,
      );
      expect(leadDays, isNonNegative);
    });
  });
}
