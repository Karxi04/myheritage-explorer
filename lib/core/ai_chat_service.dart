import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

class AiChatService {
  AiChatService._();

  static final _model =
  FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.7-flash',
  );

  // ============================================================
  // GENERAL AI CHAT
  // ============================================================

  static Future<String> ask(String prompt) async {
    return _generateText(prompt);
  }

  // ============================================================
  // ITINERARY INTENT + SLOT EXTRACTION
  // ============================================================

  static Future<Map<String, dynamic>>
  analyseItineraryMessage({
    required String message,
    required Map<String, dynamic> currentDraft,
    String? expectedField,
  }) async {
    final today =
        DateTime.now().toIso8601String().split('T').first;

    final prompt = '''
You are the intent and travel-preference extractor for
MyHeritage Explorer, a Malaysian sustainable tourism app.

Today's date is:
$today

The user may want the chatbot to create an itinerary by
collaborating with the application's Daily Planner module.

The Daily Planner requires these fields:

1. area
   Example: George Town, Penang

2. date
   Convert dates such as:
   "tomorrow"
   "this Saturday"
   "30 August"
   into YYYY-MM-DD.

3. interests
   ONLY use these official categories:
   - Heritage
   - Food
   - Art
   - Culture
   - Nature

4. budgetLevel
   ONLY:
   - Low
   - Medium
   - High

5. travelPace
   ONLY:
   - Relaxed
   - Balanced
   - Fast

   If the user says "moderate", use Balanced.
   If the user says "packed", use Fast.

6. availableHours
   Number of hours available for the itinerary.

Current itinerary draft:
${jsonEncode(currentDraft)}

The field the application is currently expecting is:
${expectedField ?? 'none'}

Latest user message:
$message

IMPORTANT RULES:

- Never invent a preference the user did not provide.
- If a current itinerary draft exists, short replies such as
  "George Town", "Medium", "Relaxed", "6 hours", or
  "Food and Heritage" should be interpreted according to the
  expected field.
- If the user asks to create, make, generate, prepare or plan an
  itinerary, use intent "create_itinerary".
- If they are answering an itinerary question already in progress,
  use intent "continue_itinerary".
- If they clearly say yes, confirm, generate it, create it now,
  proceed, go ahead, etc., use intent "confirm".
- If they say cancel, stop, never mind, reset, etc.,
  use intent "cancel".
- Otherwise use intent "other".

Return ONLY one valid JSON object.

Use exactly this structure:

{
  "intent": "create_itinerary",
  "area": null,
  "date": null,
  "interests": [],
  "budgetLevel": null,
  "travelPace": null,
  "availableHours": null
}

Do not include Markdown.
Do not include ```json.
Do not explain the JSON.
''';

    final raw = await _generateText(prompt);

    return _extractJsonObject(raw);
  }

  // ============================================================
  // INTERNAL MODEL CALL WITH RETRY
  // ============================================================

  static Future<Map<String, dynamic>>
  analyseAppAction({
    required String message,
    required Map<String, dynamic> appContext,
  }) async {
    final prompt = '''
You are the intent router for MyHeritage Explorer.

The chatbot is connected to REAL application modules.

Available modules:

1. daily_planner
2. companion
3. safety
4. rewards
5. cultural
6. notifications
7. profile

Current real application context:

${jsonEncode(appContext)}

Latest user message:

$message

Your job is ONLY to determine what application action the user wants.

Possible actions:

general_chat
show_reward_points
show_rewards
open_rewards
open_voucher_wallet
show_groups
open_companion
open_group_chat
show_group_members
show_hazards
open_safety
report_hazard
show_cultural_tasks
open_cultural_tasks
show_notifications
open_notifications
show_profile
open_profile
show_itineraries
open_itineraries

For open_group_chat:
- targetName should contain the requested group name if supplied.

IMPORTANT:

- Never claim an action was completed.
- You only select an action.
- Flutter code performs the actual action.
- SOS must NEVER be automatically triggered.
- Voucher claims must NEVER be automatically performed.
- Hazard reports must NEVER be automatically submitted.
- If unsure, use general_chat.

Return ONLY JSON:

{
  "action": "general_chat",
  "module": null,
  "targetName": null,
  "confidence": 0.0
}
''';

    final raw =
    await _generateText(prompt);

    return _extractJsonObject(raw);
  }



  static Future<String> _generateText(
      String prompt,
      ) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response =
        await _model.generateContent(
          [
            Content.text(prompt),
          ],
        ).timeout(
          const Duration(seconds: 45),
        );

        final text = response.text?.trim();

        if (text == null || text.isEmpty) {
          throw Exception(
            'The AI assistant returned an empty response.',
          );
        }

        return text;
      } on TimeoutException {
        lastError = Exception(
          'The AI assistant took too long to respond.',
        );
      } catch (error) {
        lastError = error;
      }

      if (attempt < 3) {
        await Future.delayed(
          Duration(
            milliseconds: 900 * attempt,
          ),
        );
      }
    }

    final message =
        lastError?.toString() ?? '';

    if (message.contains('500') ||
        message.contains('INTERNAL') ||
        message.toLowerCase().contains('high demand')) {
      throw Exception(
        'The AI service is temporarily busy because of high '
            'demand. Please try again in a moment.',
      );
    }

    throw Exception(
      message
          .replaceFirst('Exception: ', '')
          .trim()
          .isEmpty
          ? 'Unable to contact the AI assistant.'
          : message.replaceFirst('Exception: ', ''),
    );
  }

  // ============================================================
  // SAFE JSON EXTRACTION
  // ============================================================

  static Map<String, dynamic> _extractJsonObject(
      String raw,
      ) {
    var text = raw.trim();

    text = text
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace >= 0 &&
        lastBrace > firstBrace) {
      text = text.substring(
        firstBrace,
        lastBrace + 1,
      );
    }

    final decoded = jsonDecode(text);

    if (decoded is! Map) {
      throw const FormatException(
        'AI response was not a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }
}