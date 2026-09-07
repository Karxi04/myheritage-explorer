part of '../traveler_pages.dart';

// ================================================================
// ITINERARY CONVERSATION DRAFT
// ================================================================

class _ItineraryChatDraft {
  String? area;
  DateTime? date;
  final Set<String> interests = <String>{};
  String? budgetLevel;
  String? travelPace;
  double? availableHours;

  bool get isComplete =>
      area != null &&
          area!.trim().isNotEmpty &&
          date != null &&
          interests.isNotEmpty &&
          budgetLevel != null &&
          travelPace != null &&
          availableHours != null;

  String? get nextMissingField {
    if (area == null || area!.trim().isEmpty) {
      return 'area';
    }

    if (date == null) {
      return 'date';
    }

    if (interests.isEmpty) {
      return 'interests';
    }

    if (budgetLevel == null) {
      return 'budgetLevel';
    }

    if (travelPace == null) {
      return 'travelPace';
    }

    if (availableHours == null) {
      return 'availableHours';
    }

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'active': true,
      'area': area,
      'date': date == null
          ? null
          : DateFormat(
        'yyyy-MM-dd',
      ).format(date!),
      'interests': interests.toList(),
      'budgetLevel': budgetLevel,
      'travelPace': travelPace,
      'availableHours': availableHours,
    };
  }
}

// ================================================================
// CHATBOT PAGE
// ================================================================

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() =>
      _ChatbotPageState();
}

class _ChatbotPageState
    extends State<ChatbotPage> {
  final TextEditingController input =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  final List<Map<String, String>> messages =
  <Map<String, String>>[
    {
      'role': 'assistant',
      'text':
      'Hi! I’m your MyHeritage intelligent travel assistant. '
          'I can help you plan trips and work together with '
          'MyHeritage modules such as Daily Planner, safety, '
          'cultural experiences, rewards and companion features.\n\n'
          'For example, try asking:\n'
          '"Create an itinerary plan for me."',
    },
  ];

  final List<String> _suggestions = const [
    'Create an itinerary plan for me',
    'Plan a heritage trip',
    'Plan a food trip in George Town',
  ];

  bool sending = false;

  _ItineraryChatDraft? _itineraryDraft;

  bool _awaitingGenerationConfirmation = false;

  String? _lastCreatedItineraryId;

  // ==============================================================
  // SEND
  // ==============================================================

  Future<void> send([
    String? suggestedText,
  ]) async {
    if (sending) return;

    final text =
    (suggestedText ?? input.text).trim();

    if (text.isEmpty) return;

    final user =
        AppServices.auth.currentUser;

    if (user == null) {
      showMessage(
        context,
        'Please sign in before using the chatbot.',
        error: true,
      );
      return;
    }

    setState(() {
      messages.add({
        'role': 'user',
        'text': text,
      });

      input.clear();
      sending = true;
    });

    _scrollToBottom();

    try {
      // ----------------------------------------------------------
      // User already completed all preferences.
      // We are waiting for Yes / No.
      // ----------------------------------------------------------

      if (_awaitingGenerationConfirmation) {
        await _handleConfirmation(text);
        return;
      }

      // ----------------------------------------------------------
      // Existing itinerary conversation
      // ----------------------------------------------------------

      if (_itineraryDraft != null) {
        await _continueItineraryConversation(
          text,
        );

        return;
      }

      // ----------------------------------------------------------
      // No active itinerary.
      // Ask Gemini what the user intends.
      // ----------------------------------------------------------

      Map<String, dynamic>? analysis;

      try {
        analysis =
        await AiChatService
            .analyseItineraryMessage(
          message: text,
          currentDraft: const {
            'active': false,
          },
        );
      } catch (_) {
        // AI high-demand fallback.
        // This fallback only starts itinerary collection.
        if (_looksLikeItineraryRequest(text)) {
          _itineraryDraft =
              _ItineraryChatDraft();

          _addAssistantMessage(
            _questionForField('area'),
          );

          return;
        }

        rethrow;
      }

      final intent =
      '${analysis['intent'] ?? 'other'}'
          .toLowerCase();

      if (intent == 'create_itinerary') {
        _itineraryDraft =
            _ItineraryChatDraft();

        _mergeDraftFromAi(analysis);

        _askNextItineraryQuestion();

        return;
      }

      // ----------------------------------------------------------
      // Normal intelligent conversation
      // ----------------------------------------------------------

      await _answerGeneralQuestion(text);
    } catch (error) {
      _addAssistantMessage(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ==============================================================
  // ITINERARY CONVERSATION
  // ==============================================================

  Future<void>
  _continueItineraryConversation(
      String text,
      ) async {
    final draft = _itineraryDraft;

    if (draft == null) return;

    final expectedField =
        draft.nextMissingField;

    Map<String, dynamic>? analysis;

    try {
      analysis =
      await AiChatService
          .analyseItineraryMessage(
        message: text,
        currentDraft: draft.toMap(),
        expectedField: expectedField,
      );

      final intent =
      '${analysis['intent'] ?? ''}'
          .toLowerCase();

      if (intent == 'cancel') {
        _cancelItinerary();
        return;
      }

      _mergeDraftFromAi(analysis);
    } catch (_) {
      // Gemini may temporarily return 500/high-demand.
      // The conversation can still continue because we know which
      // particular preference we are waiting for.
      _applyLocalFallback(
        expectedField,
        text,
      );
    }

    _askNextItineraryQuestion();
  }

  // ==============================================================
  // ASK NEXT REQUIRED FIELD
  // ==============================================================

  void _askNextItineraryQuestion() {
    final draft = _itineraryDraft;

    if (draft == null) return;

    if (draft.isComplete) {
      _awaitingGenerationConfirmation =
      true;

      _addAssistantMessage(
        _buildConfirmationSummary(),
      );

      return;
    }

    final field =
        draft.nextMissingField;

    if (field != null) {
      _addAssistantMessage(
        _questionForField(field),
      );
    }
  }

  String _questionForField(
      String field,
      ) {
    switch (field) {
      case 'area':
        return 'Sure! I can create the itinerary using the '
            'Daily Planner module.\n\n'
            'First, where would you like to explore?\n'
            'For example: George Town, Penang.';

      case 'date':
        return 'What date are you planning to go?\n\n'
            'You can say something like:\n'
            '• Tomorrow\n'
            '• This Saturday\n'
            '• 30 August';

      case 'interests':
        return 'What are you interested in?\n\n'
            'You can choose one or more:\n'
            '• Heritage\n'
            '• Food\n'
            '• Art\n'
            '• Culture\n'
            '• Nature';

      case 'budgetLevel':
        return 'What is your preferred budget level?\n\n'
            '• Low\n'
            '• Medium\n'
            '• High';

      case 'travelPace':
        return 'What travel pace do you prefer?\n\n'
            '• Relaxed\n'
            '• Balanced\n'
            '• Fast';

      case 'availableHours':
        return 'Finally, how many hours do you have for the trip?\n\n'
            'For example: 2 hours, 4 hours, 6 hours or 8 hours.';

      default:
        return 'Please provide the remaining travel information.';
    }
  }

  // ==============================================================
  // MERGE GEMINI EXTRACTION INTO DRAFT
  // ==============================================================

  void _mergeDraftFromAi(
      Map<String, dynamic> data,
      ) {
    final draft = _itineraryDraft;

    if (draft == null) return;

    final rawArea =
    '${data['area'] ?? ''}'.trim();

    if (rawArea.isNotEmpty &&
        rawArea.toLowerCase() != 'null') {
      draft.area = rawArea;
    }

    final rawDate =
    '${data['date'] ?? ''}'.trim();

    if (rawDate.isNotEmpty &&
        rawDate.toLowerCase() != 'null') {
      final parsedDate =
      DateTime.tryParse(rawDate);

      if (parsedDate != null) {
        draft.date = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
        );
      }
    }

    final rawInterests =
    data['interests'];

    if (rawInterests is List) {
      for (final item
      in rawInterests) {
        final interest =
        _normaliseInterest(
          '$item',
        );

        if (interest != null) {
          draft.interests.add(
            interest,
          );
        }
      }
    }

    final budget =
    _normaliseBudget(
      '${data['budgetLevel'] ?? ''}',
    );

    if (budget != null) {
      draft.budgetLevel = budget;
    }

    final pace =
    _normalisePace(
      '${data['travelPace'] ?? ''}',
    );

    if (pace != null) {
      draft.travelPace = pace;
    }

    final rawHours =
    data['availableHours'];

    if (rawHours is num &&
        rawHours.toDouble() > 0) {
      draft.availableHours =
          rawHours.toDouble();
    } else if (rawHours != null) {
      final parsed =
      double.tryParse(
        '$rawHours',
      );

      if (parsed != null &&
          parsed > 0) {
        draft.availableHours =
            parsed;
      }
    }
  }

  // ==============================================================
  // FALLBACK EXTRACTION
  // ==============================================================

  void _applyLocalFallback(
      String? expectedField,
      String text,
      ) {
    final draft = _itineraryDraft;

    if (draft == null) return;

    switch (expectedField) {
      case 'area':
        if (text.trim().isNotEmpty) {
          draft.area =
              text.trim();
        }
        break;

      case 'date':
        final date =
        _parseDateLocally(text);

        if (date != null) {
          draft.date = date;
        }
        break;

      case 'interests':
        final lower =
        text.toLowerCase();

        for (final value in const [
          'Heritage',
          'Food',
          'Art',
          'Culture',
          'Nature',
        ]) {
          if (lower.contains(
            value.toLowerCase(),
          )) {
            draft.interests.add(
              value,
            );
          }
        }
        break;

      case 'budgetLevel':
        final value =
        _normaliseBudget(text);

        if (value != null) {
          draft.budgetLevel =
              value;
        }
        break;

      case 'travelPace':
        final value =
        _normalisePace(text);

        if (value != null) {
          draft.travelPace =
              value;
        }
        break;

      case 'availableHours':
        final match =
        RegExp(
          r'(\d+(?:\.\d+)?)',
        ).firstMatch(text);

        if (match != null) {
          final value =
          double.tryParse(
            match.group(1)!,
          );

          if (value != null &&
              value > 0) {
            draft.availableHours =
                value;
          }
        }
        break;
    }
  }

  // ==============================================================
  // DATE FALLBACK
  // ==============================================================

  DateTime? _parseDateLocally(
      String value,
      ) {
    final text =
    value.trim().toLowerCase();

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (text == 'today') {
      return today;
    }

    if (text == 'tomorrow') {
      return today.add(
        const Duration(days: 1),
      );
    }

    final iso =
    DateTime.tryParse(value);

    if (iso != null) {
      return DateTime(
        iso.year,
        iso.month,
        iso.day,
      );
    }

    final formats = [
      DateFormat('d MMMM yyyy'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
    ];

    for (final format in formats) {
      try {
        final parsed =
        format.parseStrict(
          value,
        );

        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
        );
      } catch (_) {}
    }

    // Example: "30 August"
    try {
      final parsed =
      DateFormat(
        'd MMMM',
      ).parseStrict(value);

      var date = DateTime(
        now.year,
        parsed.month,
        parsed.day,
      );

      if (date.isBefore(today)) {
        date = DateTime(
          now.year + 1,
          parsed.month,
          parsed.day,
        );
      }

      return date;
    } catch (_) {}

    return null;
  }

  // ==============================================================
  // NORMALISATION
  // ==============================================================

  String? _normaliseInterest(
      String raw,
      ) {
    final value =
    raw.trim().toLowerCase();

    switch (value) {
      case 'heritage':
      case 'history':
      case 'historical':
        return 'Heritage';

      case 'food':
      case 'foods':
      case 'restaurant':
      case 'restaurants':
      case 'cafe':
      case 'cafes':
        return 'Food';

      case 'art':
      case 'arts':
        return 'Art';

      case 'culture':
      case 'cultural':
        return 'Culture';

      case 'nature':
      case 'natural':
      case 'park':
      case 'parks':
        return 'Nature';
    }

    return null;
  }

  String? _normaliseBudget(
      String raw,
      ) {
    final value =
    raw.trim().toLowerCase();

    if (value.contains('low') ||
        value.contains('cheap') ||
        value.contains('budget')) {
      return 'Low';
    }

    if (value.contains('medium') ||
        value.contains('moderate')) {
      return 'Medium';
    }

    if (value.contains('high') ||
        value.contains('premium') ||
        value.contains('expensive')) {
      return 'High';
    }

    return null;
  }

  String? _normalisePace(
      String raw,
      ) {
    final value =
    raw.trim().toLowerCase();

    if (value.contains('relax') ||
        value.contains('slow')) {
      return 'Relaxed';
    }

    if (value.contains('balance') ||
        value.contains('moderate') ||
        value.contains('normal')) {
      return 'Balanced';
    }

    if (value.contains('fast') ||
        value.contains('packed') ||
        value.contains('quick')) {
      return 'Fast';
    }

    return null;
  }

  // ==============================================================
  // CONFIRMATION
  // ==============================================================

  String _buildConfirmationSummary() {
    final draft =
    _itineraryDraft!;

    final dateText =
    DateFormat(
      'd MMMM yyyy',
    ).format(draft.date!);

    final hours =
    _formatHours(
      draft.availableHours!,
    );

    return '''
Great! I have everything I need.

📍 Location: ${draft.area}
📅 Date: $dateText
🎯 Interests: ${draft.interests.join(', ')}
💰 Budget: ${draft.budgetLevel}
🚶 Pace: ${draft.travelPace}
⏰ Available time: $hours

I will use the MyHeritage Daily Planner module to find suitable places and build the route.

Would you like me to generate and save this itinerary now?
''';
  }

  Future<void> _handleConfirmation(
      String text,
      ) async {
    final value =
    text.trim().toLowerCase();

    if (_isPositiveConfirmation(
      value,
    )) {
      await _generateAndSaveItinerary();
      return;
    }

    if (_isNegativeConfirmation(
      value,
    )) {
      _awaitingGenerationConfirmation =
      false;

      _addAssistantMessage(
        'No problem. Tell me which preference you want to change, '
            'or type "cancel itinerary" to start over.',
      );

      return;
    }

    try {
      final result =
      await AiChatService
          .analyseItineraryMessage(
        message: text,
        currentDraft:
        _itineraryDraft?.toMap() ??
            const {},
        expectedField: 'confirmation',
      );

      final intent =
      '${result['intent'] ?? ''}'
          .toLowerCase();

      if (intent == 'confirm') {
        await _generateAndSaveItinerary();
        return;
      }

      if (intent == 'cancel') {
        _cancelItinerary();
        return;
      }

      // User may have changed one of the values.
      _mergeDraftFromAi(result);

      _awaitingGenerationConfirmation =
      false;

      _askNextItineraryQuestion();
    } catch (_) {
      _addAssistantMessage(
        'Please reply "Yes" to generate the itinerary, '
            'or "No" if you want to change something.',
      );
    }
  }

  bool _isPositiveConfirmation(
      String value,
      ) {
    return value == 'yes' ||
        value == 'y' ||
        value == 'sure' ||
        value == 'ok' ||
        value == 'okay' ||
        value == 'confirm' ||
        value.contains('go ahead') ||
        value.contains('generate') ||
        value.contains('create it') ||
        value.contains('proceed');
  }

  bool _isNegativeConfirmation(
      String value,
      ) {
    return value == 'no' ||
        value == 'n' ||
        value.contains('change') ||
        value.contains('not yet');
  }

  // ==============================================================
  // GENERATE USING DAILY PLANNER
  // ==============================================================

  Future<void>
  _generateAndSaveItinerary() async {
    final draft =
        _itineraryDraft;

    final user =
        AppServices.auth.currentUser;

    if (draft == null ||
        !draft.isComplete ||
        user == null) {
      _addAssistantMessage(
        'Some itinerary information is missing. '
            'Please start the itinerary again.',
      );

      _resetItineraryState();

      return;
    }

    _addAssistantMessage(
      'Generating your itinerary using the Daily Planner module...',
    );

    try {
      // ----------------------------------------------------------
      // THIS IS THE ACTUAL COLLABORATION WITH DAILY PLANNER.
      // ----------------------------------------------------------

      final generated =
      await GeoapifyPlanner.generate(
        area: draft.area!,
        availableHours:
        draft.availableHours!,
        interests:
        draft.interests.toList(),
        budgetLevel:
        draft.budgetLevel!,
        travelPace:
        draft.travelPace!,
      );

      if (generated.places.isEmpty) {
        _awaitingGenerationConfirmation =
        false;

        _addAssistantMessage(
          'I could not find suitable places for those preferences. '
              'Try changing the location, interests or budget.',
        );

        return;
      }

      // ----------------------------------------------------------
      // SAVE SAME PLANNER PREFERENCES INTO TRAVELER PROFILE
      // ----------------------------------------------------------

      await AppServices
          .travelerRef(user.uid)
          .set(
        {
          'lastPlannerPreferences': {
            'area': draft.area!,
            'date': Timestamp.fromDate(
              draft.date!,
            ),
            'availableHours':
            draft.availableHours!,
            'interests':
            draft.interests.toList(),
            'budgetLevel':
            draft.budgetLevel!,
            'travelPace':
            draft.travelPace!,
            'placeSource':
            'Registered MyHeritage vendors in Penang',
          },
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // ----------------------------------------------------------
      // SAVE INTO SAME ITINERARIES COLLECTION AS DAILY PLANNER
      // ----------------------------------------------------------

      final itineraryRef =
      await AppServices.db
          .collection(
        'itineraries',
      )
          .add({
        'userId': user.uid,

        'title':
        '${draft.area!} - ${DateFormat('d MMM yyyy').format(draft.date!)}',

        'area': draft.area!,

        // Added for Chatbot → Daily Planner integration
        'tripDate': Timestamp.fromDate(
          DateTime(
            draft.date!.year,
            draft.date!.month,
            draft.date!.day,
          ),
        ),

        'availableHours':
        draft.availableHours!,

        'budget':
        _budgetAmount(
          draft.budgetLevel!,
        ),

        'budgetLevel':
        draft.budgetLevel!,

        'interests':
        draft.interests.toList(),

        'travelPace':
        draft.travelPace!,

        'placeSource':
        'Registered MyHeritage vendors in Penang',

        'totalEstimatedMinutes':
        generated
            .totalEstimatedMinutes,

        'remainingMinutes':
        generated.remainingMinutes,

        'stops':
        generated.places,

        'status': 'saved',

        'createdBy':
        'ai_chatbot',

        'createdAt':
        FieldValue.serverTimestamp(),

        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      _lastCreatedItineraryId =
          itineraryRef.id;

      final stopNames =
      generated.places
          .take(5)
          .map(
            (place) =>
        '${place['name'] ?? 'Place'}',
      )
          .toList();

      final additional =
      generated.places.length >
          stopNames.length
          ? '\n…and ${generated.places.length - stopNames.length} more stop(s).'
          : '';

      _addAssistantMessage(
        '''
Your itinerary has been generated and saved successfully! 🎉

📍 ${draft.area}
📅 ${DateFormat('d MMMM yyyy').format(draft.date!)}
🗺️ ${generated.places.length} stops
⏱️ Estimated duration: ${_minutesToReadableTime(generated.totalEstimatedMinutes)}

Route highlights:
${stopNames.asMap().entries.map(
              (entry) =>
          '${entry.key + 1}. ${entry.value}',
        ).join('\n')}$additional

You can tap "Open Generated Itinerary" below to view the complete route.
''',
      );

      _resetItineraryState(
        keepLastItinerary: true,
      );
    } catch (error) {
      _awaitingGenerationConfirmation =
      false;

      _addAssistantMessage(
        'I could not generate the itinerary.\n\n'
            '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ==============================================================
  // GENERAL CHAT
  // ==============================================================

  Future<void> _answerGeneralQuestion(
      String text,
      ) async {
    final recent =
        messages
            .where(
              (message) =>
          message['role'] ==
              'user' ||
              message['role'] ==
                  'assistant',
        )
            .toList()
            .reversed
            .take(8)
            .toList()
            .reversed;

    final historyText =
    recent.map((message) {
      final role =
      message['role'] ==
          'user'
          ? 'User'
          : 'Assistant';

      return '$role: ${message['text']}';
    }).join('\n');

    final response =
    await AiChatService.ask(
      '''
You are the intelligent AI assistant inside MyHeritage Explorer,
a sustainable tourism application for Malaysia.

The application includes:

- Daily Planner
- Cultural Experiences and cultural tasks
- Rewards and vouchers
- Companion travel groups
- Private chat
- Consent-based location sharing
- SOS
- Route guidance
- Safety and hazard reporting
- Notifications
- Traveler profile

You should answer naturally and intelligently.

When a user asks you to create an itinerary, the application itself
will handle that workflow, so do not invent a fake itinerary here.

Recent conversation:
$historyText

Latest user message:
$text

Give a concise, helpful response.
''',
    );

    _addAssistantMessage(
      response,
    );
  }

  // ==============================================================
  // ITINERARY STATE HELPERS
  // ==============================================================

  void _cancelItinerary() {
    _resetItineraryState();

    _addAssistantMessage(
      'The itinerary planning process has been cancelled. '
          'You can ask me to create another itinerary anytime.',
    );
  }

  void _resetItineraryState({
    bool keepLastItinerary = false,
  }) {
    _itineraryDraft = null;

    _awaitingGenerationConfirmation =
    false;

    if (!keepLastItinerary) {
      _lastCreatedItineraryId =
      null;
    }
  }

  bool _looksLikeItineraryRequest(
      String text,
      ) {
    final value =
    text.toLowerCase();

    final hasTripWord =
        value.contains('itinerary') ||
            value.contains('trip') ||
            value.contains('travel plan');

    final hasAction =
        value.contains('create') ||
            value.contains('make') ||
            value.contains('generate') ||
            value.contains('plan');

    return hasTripWord && hasAction;
  }

  double _budgetAmount(
      String budgetLevel,
      ) {
    switch (budgetLevel) {
      case 'Low':
        return 50;

      case 'High':
        return 200;

      default:
        return 100;
    }
  }

  String _formatHours(
      double hours,
      ) {
    if (hours % 1 == 0) {
      return '${hours.toInt()} hours';
    }

    return '${hours.toStringAsFixed(1)} hours';
  }

  String _minutesToReadableTime(
      int totalMinutes,
      ) {
    if (totalMinutes <= 0) {
      return '-';
    }

    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (hours == 0) {
      return '$minutes minutes';
    }

    if (minutes == 0) {
      return '$hours hour${hours == 1 ? '' : 's'}';
    }

    return '$hours h $minutes min';
  }

  // ==============================================================
  // MESSAGE HELPERS
  // ==============================================================

  void _addAssistantMessage(
      String text,
      ) {
    if (!mounted) return;

    setState(() {
      messages.add({
        'role': 'assistant',
        'text': text.trim(),
      });
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController
            .position
            .maxScrollExtent,
        duration:
        const Duration(
          milliseconds: 280,
        ),
        curve: Curves.easeOut,
      );
    });
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ==============================================================
  // UI
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      ExplorerColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Travel Assistant',
            ),
            Text(
              'AI + MyHeritage modules',
              style: TextStyle(
                color:
                ExplorerColors.muted,
                fontSize: 10,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding:
            EdgeInsets.only(
              right: 14,
            ),
            child: Center(
              child:
              ExplorerStatusBadge(
                label: 'AI',
                tone:
                ExplorerStatusTone
                    .navy,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ------------------------------------------------------
          // MODULE INTEGRATION BANNER
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            color:
            ExplorerColors.navySoft,
            padding:
            const EdgeInsets
                .fromLTRB(
              14,
              9,
              14,
              9,
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  color:
                  ExplorerColors.navy,
                  size: 17,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'The AI can coordinate with MyHeritage modules. '
                        'Itinerary requests are generated using the real Daily Planner.',
                    style: TextStyle(
                      color:
                      ExplorerColors
                          .navy,
                      fontSize: 10,
                      height: 1.35,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // CHAT
          // ------------------------------------------------------

          Expanded(
            child: ListView.builder(
              controller:
              scrollController,
              padding:
              const EdgeInsets
                  .fromLTRB(
                14,
                18,
                14,
                18,
              ),
              itemCount:
              messages.length +
                  (sending
                      ? 1
                      : 0),
              itemBuilder:
                  (context, index) {
                if (sending &&
                    index ==
                        messages
                            .length) {
                  return _thinkingBubble();
                }

                final message =
                messages[index];

                final isUser =
                    message['role'] ==
                        'user';

                return _messageBubble(
                  text:
                  message['text'] ??
                      '',
                  isUser: isUser,
                );
              },
            ),
          ),

          // ------------------------------------------------------
          // OPEN GENERATED ITINERARY
          // ------------------------------------------------------

          if (_lastCreatedItineraryId !=
              null)
            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                0,
                12,
                8,
              ),
              child: SizedBox(
                width:
                double.infinity,
                child:
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ItineraryDetailPage(
                              itineraryId:
                              _lastCreatedItineraryId!,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons
                        .route_outlined,
                  ),
                  label: const Text(
                    'Open Generated Itinerary',
                  ),
                ),
              ),
            ),

          // ------------------------------------------------------
          // SUGGESTIONS
          // ------------------------------------------------------

          if (messages.length <= 2)
            SizedBox(
              height: 48,
              child:
              ListView.separated(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                ),
                scrollDirection:
                Axis.horizontal,
                itemCount:
                _suggestions.length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  width: 7,
                ),
                itemBuilder:
                    (context, index) {
                  final suggestion =
                  _suggestions[
                  index];

                  return ActionChip(
                    avatar:
                    const Icon(
                      Icons
                          .auto_awesome,
                      size: 16,
                    ),
                    label: Text(
                      suggestion,
                      style:
                      const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    onPressed: sending
                        ? null
                        : () => send(
                      suggestion,
                    ),
                  );
                },
              ),
            ),

          // ------------------------------------------------------
          // INPUT
          // ------------------------------------------------------

          SafeArea(
            top: false,
            child: Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                10,
                12,
                12,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color:
                    ExplorerColors
                        .border,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      enabled:
                      !sending,
                      textCapitalization:
                      TextCapitalization
                          .sentences,
                      textInputAction:
                      TextInputAction
                          .send,
                      onSubmitted:
                          (_) => send(),
                      decoration:
                      const InputDecoration(
                        hintText:
                        'Ask about your trip...',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton.filled(
                    onPressed:
                    sending
                        ? null
                        : send,
                    icon: sending
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        Colors
                            .white,
                      ),
                    )
                        : const Icon(
                      Icons.send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // THINKING BUBBLE
  // ==============================================================

  Widget _thinkingBubble() {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor:
            ExplorerColors.navy,
            child: Icon(
              Icons
                  .smart_toy_outlined,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration:
            const BoxDecoration(
              color:
              Color(0xFFDDE8FF),
              borderRadius:
              BorderRadius.only(
                topLeft:
                Radius.circular(
                  14,
                ),
                topRight:
                Radius.circular(
                  14,
                ),
                bottomLeft:
                Radius.circular(
                  3,
                ),
                bottomRight:
                Radius.circular(
                  14,
                ),
              ),
            ),
            child: const Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    ExplorerColors
                        .navy,
                  ),
                ),
                SizedBox(
                  width: 9,
                ),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color:
                    ExplorerColors
                        .navy,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // MESSAGE BUBBLE
  // ==============================================================

  Widget _messageBubble({
    required String text,
    required bool isUser,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        mainAxisAlignment:
        isUser
            ? MainAxisAlignment
            .end
            : MainAxisAlignment
            .start,
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor:
              ExplorerColors
                  .navy,
              child: Icon(
                Icons
                    .smart_toy_outlined,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
          ],
          Flexible(
            child: Container(
              padding:
              const EdgeInsets
                  .all(13),
              constraints:
              const BoxConstraints(
                maxWidth: 330,
              ),
              decoration:
              BoxDecoration(
                color: isUser
                    ? ExplorerColors
                    .navy
                    : const Color(
                  0xFFDDE8FF,
                ),
                borderRadius:
                BorderRadius.only(
                  topLeft:
                  const Radius
                      .circular(
                    14,
                  ),
                  topRight:
                  const Radius
                      .circular(
                    14,
                  ),
                  bottomLeft:
                  Radius.circular(
                    isUser
                        ? 14
                        : 3,
                  ),
                  bottomRight:
                  Radius.circular(
                    isUser
                        ? 3
                        : 14,
                  ),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : ExplorerColors
                      .navy,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}