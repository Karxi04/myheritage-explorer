import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

class AiChatService {
  AiChatService._();

  static final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.5-flash-lite',
  );

  // ============================================================
  // GENERAL AI CHAT
  // ============================================================

  static Future<String> ask(String prompt) async {
    return _generateText(prompt);
  }

  // ============================================================
  // DAILY PLANNER INTENT + SLOT EXTRACTION
  // ============================================================

  static Future<Map<String, dynamic>> analyseItineraryMessage({
    required String message,
    required Map<String, dynamic> currentDraft,
    String? expectedField,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final prompt = '''
You are the intelligent Daily Planner conversation controller for
MyHeritage Explorer, a Malaysian sustainable tourism application.

Today's date is:
$today

The Flutter application performs the real itinerary generation.
Your job is ONLY to understand the user's intent and extract planner
preferences from natural language.

============================================================
REAL DAILY PLANNER FIELDS
============================================================

1. area
Examples:
- George Town
- Batu Ferringhi
- Melaka City
- Bukit Bintang
- Ipoh Old Town

Normalize obvious names when useful:
- Georgetown -> George Town
- KL -> Kuala Lumpur / requested KL area only when the user is clear

2. date
This is the trip START date.
Return YYYY-MM-DD.
Understand:
- today
- tomorrow
- this Saturday
- next Monday
- 30 August
- 8 September 2026

3. dayCount
Number of travel days.
Examples:
- one day -> 1
- 2-day trip -> 2
- weekend trip -> 2 when explicitly described as two days
Do not invent a multi-day trip if the user did not indicate it.

4. interests
ONLY use these official values:
- Heritage
- Food
- Art
- Culture
- Nature

Mappings:
- history, historical -> Heritage
- restaurants, cafe, local cuisine -> Food
- street art, gallery -> Art
- traditional, cultural -> Culture
- park, beach, hiking -> Nature

5. budgetLevel
ONLY:
- Low
- Medium
- High

Mappings:
- cheap, budget -> Low
- moderate, normal -> Medium
- premium, expensive -> High

6. travelPace
ONLY:
- Relaxed
- Balanced
- Fast

Mappings:
- slow, easy -> Relaxed
- moderate, normal -> Balanced
- packed, quick -> Fast

7. availableHours
Number of available hours PER DAY.
Examples:
- 4 hours -> 4
- 6.5 hours -> 6.5

8. preferredStartMinutes
Minutes after midnight.
Examples:
- 9:00 AM -> 540
- 10 AM -> 600
- 1:30 PM -> 810

9. foodExplorationEnabled
Boolean.
Use true when the user explicitly asks for stronger food exploration,
food hunting, local food discovery, food crawl, or extra food stops.
Use false only when the user explicitly turns it off.
Otherwise return null.

10. interestsMode
Only relevant when interests are changed during an existing draft.
Return:
- "replace" when the user says change/switch interests to something
- "add" when the user says add/include another interest
- null otherwise

============================================================
CURRENT ITINERARY DRAFT
============================================================

${jsonEncode(currentDraft)}

The application is currently expecting:
${expectedField ?? 'none'}

Latest user message:
$message

============================================================
VALID INTENTS
============================================================

Use ONLY:

create_itinerary
continue_itinerary
update_itinerary
confirm
cancel
suggest_area
other

============================================================
INTENT RULES
============================================================

create_itinerary:
Use when the user wants to create, make, generate, prepare or plan a
trip/itinerary.

continue_itinerary:
Use when an itinerary draft is active and the user is answering the
currently requested field.

update_itinerary:
Use when the user changes ANY existing preference, even while waiting
for final confirmation.
Examples:
- change location to Georgetown
- location give me Georgetown
- actually use Batu Ferringhi
- change budget to Medium
- make the pace faster
- use 8 hours instead
- make it 2 days
- start at 10am instead
- change interests to Food and Heritage
- also add Nature
- enable food exploration

confirm:
ONLY when the user clearly approves generation without changing a
preference.
Examples:
- yes
- confirm
- looks good
- go ahead
- generate it now

If the user says "yes but change location to George Town", use
update_itinerary, not confirm.

cancel:
Use for cancel, stop, never mind, reset itinerary, forget it.

suggest_area:
Use when the user asks the assistant to recommend a destination instead
of giving an area.
Examples:
- what do you suggest?
- recommend somewhere
- where should I go?
- you choose a location
Do NOT save those sentences as the area.

other:
Use when the message is not part of itinerary planning.

============================================================
EXTRACTION RULES
============================================================

- Never invent a user preference.
- Do NOT copy unchanged fields from currentDraft into your response.
- Return only values actually supplied or changed in the latest message.
- Multiple fields may be extracted from one message.
- Short replies should be interpreted according to expectedField.
- Imperfect grammar and casual English should still be understood.
- When expectedField is "confirmation", changes take priority over yes/no.
- If the user asks for a suggestion, area must remain null until the user
  actually chooses a destination.

============================================================
OUTPUT
============================================================

Return ONLY one JSON object in exactly this structure:

{
  "intent": "other",
  "area": null,
  "date": null,
  "dayCount": null,
  "interests": [],
  "interestsMode": null,
  "budgetLevel": null,
  "travelPace": null,
  "availableHours": null,
  "preferredStartMinutes": null,
  "foodExplorationEnabled": null
}

Do not include Markdown.
Do not include ```json.
Do not explain the JSON.
''';

    final raw = await _generateText(prompt);
    return _extractJsonObject(raw);
  }

  // ============================================================
  // APP MODULE ACTION ROUTER
  // ============================================================

  static Future<Map<String, dynamic>> analyseAppAction({
    required String message,
    required Map<String, dynamic> appContext,
  }) async {
    final prompt = '''
You are the action router for the MyHeritage Explorer AI assistant.

The assistant can READ real module data and OPEN real module screens.
Flutter performs the actual actions.

============================================================
AVAILABLE MODULES
============================================================

Daily Planner:
- saved itineraries
- latest itinerary
- itinerary day/stops
- itinerary editing
- itinerary rewards/cultural tasks
- safety checking around itinerary stops

Rewards:
- reward points
- available vouchers
- rewards screen
- voucher wallet

Cultural:
- active cultural tasks
- cultural tasks screen

Safety:
- verified hazards
- safety screen
- hazard report form

Companion:
- active travel groups
- group members
- group chat
- companion screen

Notifications:
- unread count
- notifications screen

Profile:
- traveler profile

============================================================
REAL APP CONTEXT
============================================================

${jsonEncode(appContext)}

Latest user message:
$message

============================================================
POSSIBLE ACTIONS
============================================================

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
describe_latest_itinerary
open_latest_itinerary
edit_latest_itinerary
show_itinerary_rewards
show_itinerary_cultural_tasks
check_itinerary_safety

============================================================
TARGET RULES
============================================================

For open_group_chat or show_group_members:
- targetName = requested group name if supplied
- otherwise null

For itinerary-day questions:
- use describe_latest_itinerary
- targetNumber = requested day number, e.g. 2 for "what is on day 2?"

For all other actions targetName and targetNumber can be null.

============================================================
SAFETY RULES
============================================================

Never claim that Flutter already performed an action.
Never automatically:
- trigger SOS
- share GPS
- claim a voucher
- submit a hazard report
- remove a group member
- quit a group
- delete user data

For a request to send SOS, route to open_companion so the user can use
the existing explicit-confirmation SOS flow.

If unsure, use general_chat.

============================================================
OUTPUT
============================================================

Return ONLY JSON:

{
  "action": "general_chat",
  "module": null,
  "targetName": null,
  "targetNumber": null,
  "confidence": 0.0
}

Do not include Markdown.
Do not explain the answer.
''';

    final raw = await _generateText(prompt);
    return _extractJsonObject(raw);
  }

  // ============================================================
  // INTERNAL MODEL CALL WITH RETRY
  // ============================================================

  static Future<String> _generateText(String prompt) async {
    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await _model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 45));

        final text = response.text?.trim();
        if (text == null || text.isEmpty) {
          throw Exception('The AI assistant returned an empty response.');
        }
        return text;
      } on TimeoutException {
        lastError = Exception('The AI assistant took too long to respond.');
      } catch (error) {
        final lower = error.toString().toLowerCase();

        // Do not hammer App Check when Firebase is already throttling it.
        if (lower.contains('firebase_app_check') ||
            lower.contains('too many attempts') ||
            lower.contains('app check')) {
          throw Exception(
            'Firebase App Check is rejecting the AI request. Make sure this '
                'device debug token is registered in Firebase Console, then '
                'restart the app and try again.',
          );
        }

        if (lower.contains('permission-denied') ||
            lower.contains('permission denied') ||
            lower.contains('unauthenticated')) {
          throw Exception(
            'The AI request was rejected because the app does not currently '
                'have permission to access the AI service.',
          );
        }

        lastError = error;
      }

      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 900 * attempt));
      }
    }

    final message = (lastError?.toString() ?? '')
        .replaceFirst('Exception: ', '')
        .trim();
    final lower = message.toLowerCase();

    if (message.contains('500') ||
        lower.contains('internal') ||
        lower.contains('high demand') ||
        lower.contains('overloaded') ||
        lower.contains('unavailable')) {
      throw Exception(
        'The AI service is temporarily busy. Please try again in a moment.',
      );
    }

    if (message.contains('429') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource_exhausted')) {
      throw Exception(
        'The AI service is receiving too many requests. Please wait a moment '
            'before trying again.',
      );
    }

    if (message.isEmpty) {
      throw Exception('Unable to contact the AI assistant.');
    }

    throw Exception(message);
  }

  // ============================================================
  // SAFE JSON EXTRACTION
  // ============================================================

  static Map<String, dynamic> _extractJsonObject(String raw) {
    var text = raw
        .trim()
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');

    if (firstBrace >= 0 && lastBrace > firstBrace) {
      text = text.substring(firstBrace, lastBrace + 1);
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('AI response was not a JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }
}
