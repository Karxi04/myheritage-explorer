part of '../traveler_pages.dart';

// ================================================================
// ITINERARY CONVERSATION DRAFT
// ================================================================

class _ItineraryChatDraft {
  String? stateId;
  String? stateName;
  String? area;
  DateTime? startDate;
  int dayCount = 1;
  final Set<String> interests = <String>{};
  String? budgetLevel;
  String? travelPace;
  double? availableHours;
  int preferredStartMinutes = 9 * 60;
  bool foodExplorationEnabled = false;

  bool get isComplete =>
      area != null &&
          area!.trim().isNotEmpty &&
          startDate != null &&
          interests.isNotEmpty &&
          budgetLevel != null &&
          travelPace != null &&
          availableHours != null;

  String? get nextMissingField {
    if (area == null || area!.trim().isEmpty) return 'area';
    if (startDate == null) return 'date';
    if (interests.isEmpty) return 'interests';
    if (budgetLevel == null) return 'budgetLevel';
    if (travelPace == null) return 'travelPace';
    if (availableHours == null) return 'availableHours';
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'active': true,
      'stateId': stateId,
      'stateName': stateName,
      'area': area,
      'date': startDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(startDate!),
      'dayCount': dayCount,
      'interests': interests.toList(),
      'budgetLevel': budgetLevel,
      'travelPace': travelPace,
      'availableHours': availableHours,
      'preferredStartMinutes': preferredStartMinutes,
      'foodExplorationEnabled': foodExplorationEnabled,
    };
  }
}

// ================================================================
// CHATBOT PAGE
// ================================================================

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController input = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<Map<String, String>> messages = <Map<String, String>>[
    {
      'role': 'assistant',
      'text':
      'Hi! I’m your MyHeritage intelligent travel assistant. '
          'My strongest feature is the Daily Planner: I can collect your '
          'preferences, generate a real itinerary, save it, explain it and '
          'open it for editing. I can also work with Rewards, Cultural Tasks, '
          'Safety, Companion, Notifications and your profile.\n\n'
          'Try: “Plan a 2-day food and heritage trip in George Town tomorrow.”',
    },
  ];

  bool sending = false;
  _ItineraryChatDraft? _itineraryDraft;
  bool _awaitingGenerationConfirmation = false;
  String? _lastCreatedItineraryId;

  List<String> get _suggestions {
    if (_lastCreatedItineraryId != null) {
      return const [
        'What is in my latest itinerary?',
        'Check my itinerary safety',
        'Show rewards in my itinerary',
        'Edit my latest itinerary',
      ];
    }

    return const [
      'Plan a 2-day trip in George Town',
      'Create a food and heritage itinerary',
      'How many reward points do I have?',
      'Show my travel groups',
    ];
  }

  bool _looksLikeAnswerForField(
      String? field,
      String text,
      ) {
    final value =
    text.trim().toLowerCase();

    if (value.isEmpty) {
      return false;
    }

    switch (field) {
      case 'area':
      // Avoid treating questions as locations.
        if (value.contains('?') ||
            value.startsWith('what ') ||
            value.startsWith('why ') ||
            value.startsWith('how ') ||
            value.startsWith('who ') ||
            value.startsWith('can ') ||
            value.startsWith('do ') ||
            value.startsWith('is ')) {
          return false;
        }

        return true;

      case 'date':
        return value.contains(
          'today',
        ) ||
            value.contains(
              'tomorrow',
            ) ||
            value.contains(
              'monday',
            ) ||
            value.contains(
              'tuesday',
            ) ||
            value.contains(
              'wednesday',
            ) ||
            value.contains(
              'thursday',
            ) ||
            value.contains(
              'friday',
            ) ||
            value.contains(
              'saturday',
            ) ||
            value.contains(
              'sunday',
            ) ||
            RegExp(
              r'\d',
            ).hasMatch(value);

      case 'interests':
        return value.contains(
          'heritage',
        ) ||
            value.contains(
              'history',
            ) ||
            value.contains(
              'food',
            ) ||
            value.contains(
              'art',
            ) ||
            value.contains(
              'culture',
            ) ||
            value.contains(
              'nature',
            );

      case 'budgetLevel':
        return value.contains(
          'low',
        ) ||
            value.contains(
              'medium',
            ) ||
            value.contains(
              'high',
            ) ||
            value.contains(
              'cheap',
            ) ||
            value.contains(
              'budget',
            ) ||
            value.contains(
              'premium',
            );

      case 'travelPace':
        return value.contains(
          'relax',
        ) ||
            value.contains(
              'slow',
            ) ||
            value.contains(
              'balance',
            ) ||
            value.contains(
              'normal',
            ) ||
            value.contains(
              'fast',
            ) ||
            value.contains(
              'packed',
            );

      case 'availableHours':
        return RegExp(
          r'\d+(?:\.\d+)?\s*(?:hour|hours|hr|hrs)?',
        ).hasMatch(value);

      default:
        return false;
    }
  }
  // ==============================================================
  // MAIN SEND FLOW
  // ==============================================================

  Future<void> send([String? suggestedText]) async {
    if (sending) return;

    final text = (suggestedText ?? input.text).trim();
    if (text.isEmpty) return;

    final user = AppServices.auth.currentUser;
    if (user == null) {
      showMessage(
        context,
        'Please sign in before using the chatbot.',
        error: true,
      );
      return;
    }

    setState(() {
      messages.add({'role': 'user', 'text': text});
      input.clear();
      sending = true;
    });
    _scrollToBottom();

    try {
      if (_awaitingGenerationConfirmation) {
        await _handleConfirmation(text);
        return;
      }

      if (_itineraryDraft != null) {
        await _continueItineraryConversation(text);
        return;
      }

      Map<String, dynamic>? analysis;
      try {
        analysis = await AiChatService.analyseItineraryMessage(
          message: text,
          currentDraft: const {'active': false},
        );
      } catch (_) {
        if (_looksLikeItineraryRequest(text)) {
          _itineraryDraft = _ItineraryChatDraft();
          _addAssistantMessage(_questionForField('area'));
          return;
        }
        rethrow;
      }

      final intent = '${analysis['intent'] ?? 'other'}'.toLowerCase();

      if (intent == 'create_itinerary') {
        _itineraryDraft = _ItineraryChatDraft();
        _mergeDraftFromAi(analysis);
        _askNextItineraryQuestion();
        return;
      }

      if (intent == 'suggest_area') {
        _itineraryDraft ??= _ItineraryChatDraft();
        _suggestAreas();
        return;
      }

      final handled = await _tryHandleModuleAction(text);
      if (handled) return;

      await _answerGeneralQuestion(text);
    } catch (error) {
      _addAssistantMessage(
        error.toString().replaceFirst('Exception: ', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() => sending = false);
        _scrollToBottom();
      }
    }
  }

  // ==============================================================
  // DAILY PLANNER CONVERSATION
  // ==============================================================

  Future<void> _continueItineraryConversation(
      String text,
      ) async {
    final draft = _itineraryDraft;

    if (draft == null) return;

    final expectedField =
        draft.nextMissingField;

    try {
      final analysis =
      await AiChatService
          .analyseItineraryMessage(
        message: text,
        currentDraft: draft.toMap(),
        expectedField: expectedField,
      );

      final intent =
      '${analysis['intent'] ?? 'other'}'
          .trim()
          .toLowerCase();

      debugPrint(
        'CHATBOT ITINERARY INTENT: $intent',
      );

      // ==========================================================
      // CANCEL
      // ==========================================================

      if (intent == 'cancel') {
        _cancelItinerary();
        return;
      }

      // ==========================================================
      // AREA SUGGESTION
      // ==========================================================

      if (intent == 'suggest_area') {
        _suggestAreas();
        return;
      }

      // ==========================================================
      // UPDATE EXISTING PREFERENCES
      // ==========================================================

      if (intent == 'update_itinerary') {
        _mergeDraftFromAi(
          analysis,
          isUpdate: true,
        );

        _addAssistantMessage(
          'Sure, I updated your itinerary preferences.',
        );

        _askNextItineraryQuestion();

        return;
      }

      // ==========================================================
      // USER IS ANSWERING CURRENT PLANNER QUESTION
      // ==========================================================

      if (intent == 'continue_itinerary') {
        _mergeDraftFromAi(
          analysis,
        );

        _askNextItineraryQuestion();

        return;
      }

      // ==========================================================
      // USER STARTS A NEW ITINERARY WHILE ONE EXISTS
      // ==========================================================

      if (intent == 'create_itinerary') {
        _mergeDraftFromAi(
          analysis,
        );

        _askNextItineraryQuestion();

        return;
      }

      // ==========================================================
      // GENERAL / OTHER QUESTION
      //
      // IMPORTANT:
      // Do not destroy the itinerary draft.
      // Answer the user's other question normally.
      // ==========================================================

      if (intent == 'other') {
        final handled =
        await _tryHandleModuleAction(
          text,
        );

        if (handled) {
          return;
        }

        await _answerGeneralQuestion(
          text,
        );

        // The draft remains stored.
        return;
      }

      // ==========================================================
      // SAFE FALLBACK
      // ==========================================================

      final handled =
      await _tryHandleModuleAction(
        text,
      );

      if (handled) {
        return;
      }

      await _answerGeneralQuestion(
        text,
      );
    } catch (error) {
      debugPrint(
        'ITINERARY CONVERSATION ERROR: $error',
      );

      // Only use the local field parser when the answer
      // genuinely looks like it belongs to the expected field.
      if (_looksLikeAnswerForField(
        expectedField,
        text,
      )) {
        _applyLocalFallback(
          expectedField,
          text,
        );

        _askNextItineraryQuestion();

        return;
      }

      // Otherwise answer it as a normal question.
      try {
        final handled =
        await _tryHandleModuleAction(
          text,
        );

        if (handled) {
          return;
        }

        await _answerGeneralQuestion(
          text,
        );
      } catch (secondaryError) {
        _addAssistantMessage(
          secondaryError
              .toString()
              .replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  void _askNextItineraryQuestion() {
    final draft = _itineraryDraft;
    if (draft == null) return;

    if (draft.isComplete) {
      _awaitingGenerationConfirmation = true;
      _addAssistantMessage(_buildConfirmationSummary());
      return;
    }

    final field = draft.nextMissingField;
    if (field != null) {
      _addAssistantMessage(_questionForField(field));
    }
  }

  String _questionForField(String field) {
    switch (field) {
      case 'area':
        return 'Where would you like to explore?\n\n'
            'For example: George Town, Batu Ferringhi, Melaka City or '
            'Bukit Bintang. You can also ask me to suggest somewhere.';
      case 'date':
        return 'What date are you planning to start?\n\n'
            'You can say: Tomorrow, This Saturday, or 30 August.';
      case 'interests':
        return 'What are you interested in?\n\n'
            '• Heritage\n• Food\n• Art\n• Culture\n• Nature';
      case 'budgetLevel':
        return 'What is your preferred budget level?\n\n'
            '• Low\n• Medium\n• High';
      case 'travelPace':
        return 'What travel pace do you prefer?\n\n'
            '• Relaxed\n• Balanced\n• Fast';
      case 'availableHours':
        return 'How many hours per day do you have?\n\n'
            'For example: 4 hours, 6 hours or 8 hours.';
      default:
        return 'Please provide the remaining travel information.';
    }
  }

  void _mergeDraftFromAi(
      Map<String, dynamic> data, {
        bool isUpdate = false,
      }) {
    final draft = _itineraryDraft;
    if (draft == null) return;

    final rawArea = '${data['area'] ?? ''}'.trim();
    if (_isRealValue(rawArea)) {
      final area = _normaliseArea(rawArea);
      draft.area = area;
      draft.stateId = MalaysiaLocationService.inferStateIdFromArea(area);
      draft.stateName = MalaysiaLocationService.getStateName(draft.stateId!);
    }

    final rawDate = '${data['date'] ?? ''}'.trim();
    if (_isRealValue(rawDate)) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        draft.startDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final rawDayCount = data['dayCount'];
    final parsedDays = rawDayCount is num
        ? rawDayCount.toInt()
        : int.tryParse('${rawDayCount ?? ''}');
    if (parsedDays != null && parsedDays > 0 && parsedDays <= 14) {
      draft.dayCount = parsedDays;
    }

    final rawInterests = data['interests'];
    if (rawInterests is List && rawInterests.isNotEmpty) {
      final mode = '${data['interestsMode'] ?? ''}'.toLowerCase();
      if (isUpdate && mode != 'add') {
        draft.interests.clear();
      }

      for (final item in rawInterests) {
        final interest = _normaliseInterest('$item');
        if (interest != null) draft.interests.add(interest);
      }
    }

    final budget = _normaliseBudget('${data['budgetLevel'] ?? ''}');
    if (budget != null) draft.budgetLevel = budget;

    final pace = _normalisePace('${data['travelPace'] ?? ''}');
    if (pace != null) draft.travelPace = pace;

    final rawHours = data['availableHours'];
    final hours = rawHours is num
        ? rawHours.toDouble()
        : double.tryParse('${rawHours ?? ''}');
    if (hours != null && hours > 0 && hours <= 24) {
      draft.availableHours = hours;
    }

    final rawStart = data['preferredStartMinutes'];
    final startMinutes = rawStart is num
        ? rawStart.toInt()
        : int.tryParse('${rawStart ?? ''}');
    if (startMinutes != null && startMinutes >= 0 && startMinutes < 1440) {
      draft.preferredStartMinutes = startMinutes;
    }

    if (data['foodExplorationEnabled'] is bool) {
      draft.foodExplorationEnabled = data['foodExplorationEnabled'] as bool;
    }
  }

  bool _isRealValue(String value) {
    final lower = value.trim().toLowerCase();
    return lower.isNotEmpty && lower != 'null' && lower != 'none';
  }

  String _normaliseArea(String raw) {
    final value = raw.trim();
    final lower = value.toLowerCase();

    if (lower == 'georgetown' || lower == 'george town penang') {
      return 'George Town';
    }
    if (lower == 'kl') return 'Kuala Lumpur';
    return value;
  }

  // ==============================================================
  // LOCAL FALLBACKS
  // ==============================================================

  void _applyLocalFallback(String? expectedField, String text) {
    final draft = _itineraryDraft;
    if (draft == null) return;

    switch (expectedField) {
      case 'area':
        final lower = text.trim().toLowerCase();
        final asksSuggestion = lower.contains('suggest') ||
            lower.contains('recommend') ||
            lower.contains('you choose') ||
            lower.contains('where should');
        if (!asksSuggestion && text.trim().isNotEmpty) {
          final area = _normaliseArea(text.trim());
          draft.area = area;
          draft.stateId = MalaysiaLocationService.inferStateIdFromArea(area);
          draft.stateName = MalaysiaLocationService.getStateName(draft.stateId!);
        }
        break;
      case 'date':
        final date = _parseDateLocally(text);
        if (date != null) draft.startDate = date;
        break;
      case 'interests':
        final lower = text.toLowerCase();
        for (final value in const [
          'Heritage',
          'Food',
          'Art',
          'Culture',
          'Nature',
        ]) {
          if (lower.contains(value.toLowerCase())) {
            draft.interests.add(value);
          }
        }
        break;
      case 'budgetLevel':
        final value = _normaliseBudget(text);
        if (value != null) draft.budgetLevel = value;
        break;
      case 'travelPace':
        final value = _normalisePace(text);
        if (value != null) draft.travelPace = value;
        break;
      case 'availableHours':
        final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
        if (match != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value > 0 && value <= 24) {
            draft.availableHours = value;
          }
        }
        break;
    }
  }

  DateTime? _parseDateLocally(String value) {
    final text = value.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text == 'today') return today;
    if (text == 'tomorrow') return today.add(const Duration(days: 1));

    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final formats = [
      DateFormat('d MMMM yyyy'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parseStrict(value);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }

    try {
      final parsed = DateFormat('d MMMM').parseStrict(value);
      var date = DateTime(now.year, parsed.month, parsed.day);
      if (date.isBefore(today)) {
        date = DateTime(now.year + 1, parsed.month, parsed.day);
      }
      return date;
    } catch (_) {}

    return null;
  }

  String? _normaliseInterest(String raw) {
    final value = raw.trim().toLowerCase();
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
      case 'cuisine':
        return 'Food';
      case 'art':
      case 'arts':
      case 'gallery':
      case 'street art':
        return 'Art';
      case 'culture':
      case 'cultural':
      case 'traditional':
        return 'Culture';
      case 'nature':
      case 'natural':
      case 'park':
      case 'parks':
      case 'beach':
        return 'Nature';
    }
    return null;
  }

  String? _normaliseBudget(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('low') ||
        value.contains('cheap') ||
        value.contains('budget')) {
      return 'Low';
    }
    if (value.contains('medium') ||
        value.contains('moderate') ||
        value.contains('normal')) {
      return 'Medium';
    }
    if (value.contains('high') ||
        value.contains('premium') ||
        value.contains('expensive')) {
      return 'High';
    }
    return null;
  }

  String? _normalisePace(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('relax') ||
        value.contains('slow') ||
        value.contains('easy')) {
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
  // DESTINATION SUGGESTION
  // ==============================================================

  void _suggestAreas() {
    final interests = _itineraryDraft?.interests ?? <String>{};

    String suggestions;
    if (interests.contains('Nature')) {
      suggestions =
      '• Cameron Highlands, Pahang — nature and cooler weather\n'
          '• Langkawi, Kedah — beaches and scenic attractions\n'
          '• Teluk Bahang, Penang — nature-focused Penang option';
    } else if (interests.contains('Food')) {
      suggestions =
      '• George Town, Penang — strong local food + heritage mix\n'
          '• Melaka City — heritage streets and local cuisine\n'
          '• Chinatown / Petaling Street, Kuala Lumpur — food and city culture';
    } else {
      suggestions =
      '• George Town, Penang — heritage, art, culture and food\n'
          '• Melaka City — historic core and cultural attractions\n'
          '• Ipoh Old Town, Perak — heritage, food and old-town atmosphere';
    }

    _addAssistantMessage(
      'Here are a few good choices:\n\n$suggestions\n\n'
          'Tell me which one you want. I won’t choose it for you automatically.',
    );
  }

  // ==============================================================
  // CONFIRMATION + EDITING
  // ==============================================================

  String _buildConfirmationSummary() {
    final draft = _itineraryDraft!;
    final startDate = draft.startDate!;
    final endDate = startDate.add(Duration(days: draft.dayCount - 1));
    final dateText = draft.dayCount == 1
        ? DateFormat('d MMMM yyyy').format(startDate)
        : '${DateFormat('d MMM yyyy').format(startDate)} – '
        '${DateFormat('d MMM yyyy').format(endDate)}';

    return '''
Great! Here is your Daily Planner setup.

📍 Location: ${draft.area}, ${draft.stateName ?? ''}
📅 Date: $dateText
🗓️ Days: ${draft.dayCount}
🎯 Interests: ${draft.interests.join(', ')}
💰 Budget: ${draft.budgetLevel}
🚶 Pace: ${draft.travelPace}
⏰ Available time/day: ${_formatHours(draft.availableHours!)}
🕘 Start time: ${_formatStartTime(draft.preferredStartMinutes)}
🍜 Food exploration: ${draft.foodExplorationEnabled ? 'On' : 'Off'}

I will use the real MyHeritage Daily Planner engine, including its vendor, cultural-task, voucher and weather-aware planning data.

You can still say things like:
• "Change location to Batu Ferringhi"
• "Make it 2 days"
• "Start at 10am instead"
• "Change budget to Medium"

Would you like me to generate and save this itinerary now?
''';
  }

  Future<void> _handleConfirmation(
      String text,
      ) async {
    final value =
    text.trim().toLowerCase();

    // ============================================================
    // FAST YES
    // ============================================================

    if (_isPositiveConfirmation(
      value,
    )) {
      await _generateAndSaveItinerary();
      return;
    }

    // ============================================================
    // FAST NO
    // ============================================================

    if (_isNegativeConfirmation(
      value,
    )) {
      _awaitingGenerationConfirmation =
      false;

      _addAssistantMessage(
        'No problem. Your itinerary draft is still saved. '
            'Tell me what you want to change.',
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
        expectedField:
        'confirmation',
      );

      final intent =
      '${result['intent'] ?? 'other'}'
          .trim()
          .toLowerCase();

      debugPrint(
        'CONFIRMATION INTENT: $intent',
      );

      // ==========================================================
      // CONFIRM
      // ==========================================================

      if (intent == 'confirm') {
        await _generateAndSaveItinerary();
        return;
      }

      // ==========================================================
      // CANCEL
      // ==========================================================

      if (intent == 'cancel') {
        _cancelItinerary();
        return;
      }

      // ==========================================================
      // UPDATE ITINERARY
      // ==========================================================

      if (intent == 'update_itinerary') {
        _mergeDraftFromAi(
          result,
          isUpdate: true,
        );

        _awaitingGenerationConfirmation =
        false;

        _addAssistantMessage(
          'Sure, I updated your itinerary.',
        );

        _askNextItineraryQuestion();

        return;
      }

      // ==========================================================
      // SUGGESTION
      // ==========================================================

      if (intent == 'suggest_area') {
        _awaitingGenerationConfirmation =
        false;

        _suggestAreas();

        return;
      }

      // ==========================================================
      // THIS IS THE IMPORTANT FIX:
      // unrelated question while confirmation is pending
      // ==========================================================

      final handled =
      await _tryHandleModuleAction(
        text,
      );

      if (handled) {
        return;
      }

      await _answerGeneralQuestion(
        text,
      );

      // Keep:
      // _awaitingGenerationConfirmation = true
      //
      // So user can later simply say "yes".
    } catch (error) {
      debugPrint(
        'CONFIRMATION HANDLER ERROR: $error',
      );

      try {
        final handled =
        await _tryHandleModuleAction(
          text,
        );

        if (handled) {
          return;
        }

        await _answerGeneralQuestion(
          text,
        );
      } catch (secondaryError) {
        _addAssistantMessage(
          secondaryError
              .toString()
              .replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  bool _looksLikePreferenceEdit(String text) {
    return text.contains('change') ||
        text.contains('update') ||
        text.contains('instead') ||
        text.contains('actually') ||
        text.contains('location') ||
        text.contains('area') ||
        text.contains('budget') ||
        text.contains('pace') ||
        text.contains('interest') ||
        text.contains('day') ||
        text.contains('hour') ||
        text.contains('start at') ||
        text.contains('start time') ||
        text.contains('food exploration');
  }

  bool _isPositiveConfirmation(String value) {
    return value == 'yes' ||
        value == 'y' ||
        value == 'sure' ||
        value == 'ok' ||
        value == 'okay' ||
        value == 'confirm' ||
        value == 'looks good' ||
        value.contains('go ahead') ||
        value.contains('generate it') ||
        value.contains('create it now') ||
        value.contains('proceed');
  }

  bool _isNegativeConfirmation(String value) {
    return value == 'no' ||
        value == 'n' ||
        value == 'not yet' ||
        value == 'nope';
  }

  // ==============================================================
  // REAL DAILY PLANNER GENERATION
  // ==============================================================

  Future<void> _generateAndSaveItinerary() async {
    final draft = _itineraryDraft;
    final user = AppServices.auth.currentUser;

    if (draft == null || !draft.isComplete || user == null) {
      _addAssistantMessage(
        'Some planner information is missing. Please continue the itinerary '
            'setup before generating it.',
      );
      return;
    }

    final stateId = draft.stateId ??
        MalaysiaLocationService.inferStateIdFromArea(draft.area!);
    final stateName =
        draft.stateName ?? MalaysiaLocationService.getStateName(stateId);

    _addAssistantMessage(
      'Generating your itinerary with the real Daily Planner engine...',
    );

    try {
      final generated = await GeoapifyPlanner.generate(
        area: draft.area!,
        availableHours: draft.availableHours!,
        interests: draft.interests.toList(),
        budgetLevel: draft.budgetLevel!,
        travelPace: draft.travelPace!,
        preferredStartMinutes: draft.preferredStartMinutes,
        startDate: draft.startDate!,
        dayCount: draft.dayCount,
        foodExplorationEnabled: draft.foodExplorationEnabled,
      );

      if (generated.places.isEmpty) {
        _awaitingGenerationConfirmation = false;
        _addAssistantMessage(
          'The Daily Planner could not find suitable places for this setup. '
              'Try changing the location, interests, budget or available hours.',
        );
        return;
      }

      final startDate = generated.startDate ?? draft.startDate!;
      final endDate = generated.endDate ??
          startDate.add(Duration(days: draft.dayCount - 1));

      final daysMap = generated.days.map((day) => day.toMap()).toList();
      if (daysMap.isEmpty) {
        daysMap.add({
          'dayNumber': 1,
          'date': startDate.toIso8601String(),
          'dateLabel': DateFormat('EEE, d MMM').format(startDate),
          'weather': const <String, dynamic>{},
          'stops': generated.places,
          'totalEstimatedMinutes': generated.totalEstimatedMinutes,
          'remainingMinutes': generated.remainingMinutes,
        });
      }

      final title = draft.dayCount > 1
          ? '$stateName ${draft.dayCount}-Day Tour'
          : '${draft.area} Cultural Day';

      await AppServices.travelerRef(user.uid).set(
        {
          'lastPlannerPreferences': {
            'stateId': stateId,
            'stateName': stateName,
            'area': draft.area!,
            'availableHours': draft.availableHours!,
            'dayCount': draft.dayCount,
            'interests': draft.interests.toList(),
            'budgetLevel': draft.budgetLevel!,
            'travelPace': draft.travelPace!,
            'startMinutes': draft.preferredStartMinutes,
            'foodExplorationEnabled': draft.foodExplorationEnabled,
            'tripStartDate': Timestamp.fromDate(startDate),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final itineraryRef = await AppServices.db.collection('itineraries').add({
        'userId': user.uid,
        'title': title,
        'stateId': stateId,
        'stateName': stateName,
        'selectedArea': draft.area!,
        'area': draft.area!,
        'availableHours': draft.availableHours!,
        'dailyHours': draft.availableHours!,
        'numberOfDays': draft.dayCount,
        'dayCount': draft.dayCount,
        'dailyStartTime': _format24Hour(draft.preferredStartMinutes),
        'dailyEndTime': _format24Hour(
          (draft.preferredStartMinutes + (draft.availableHours! * 60).round())
              .clamp(0, 1439),
        ),
        'tripDate': Timestamp.fromDate(startDate),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'budget': _budgetRange(draft.budgetLevel!),
        'budgetLevel': draft.budgetLevel!,
        'budgetPreference': draft.budgetLevel!,
        'interests': draft.interests.toList(),
        'travelPace': draft.travelPace!,
        'pace': draft.travelPace!,
        'suggestedStartMinutes': draft.preferredStartMinutes,
        'foodExplorationEnabled': draft.foodExplorationEnabled,
        'totalEstimatedMinutes': generated.totalEstimatedMinutes,
        'remainingMinutes': generated.remainingMinutes,
        'stops': generated.places,
        'days': daysMap,
        'status': 'saved',
        'createdBy': 'ai_chatbot',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _lastCreatedItineraryId = itineraryRef.id;

      final stopNames = generated.places
          .take(6)
          .map((place) => '${place['name'] ?? 'Place'}')
          .toList();
      final extra = generated.places.length > stopNames.length
          ? '\n…and ${generated.places.length - stopNames.length} more stop(s).'
          : '';

      _addAssistantMessage(
        '''
Your Daily Planner itinerary has been generated and saved successfully! 🎉

📍 ${draft.area}, $stateName
📅 ${_dateRange(startDate, endDate)}
🗓️ ${draft.dayCount} day${draft.dayCount == 1 ? '' : 's'}
🗺️ ${generated.places.length} total stop(s)
⏱️ Planned activity time: ${_minutesToReadableTime(generated.totalEstimatedMinutes)}
💰 Budget preference: ${draft.budgetLevel} (${_budgetRange(draft.budgetLevel!)})

Route highlights:
${stopNames.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n')}$extra

You can open the itinerary below, ask what is on a specific day, check rewards/cultural tasks, check nearby verified hazards, or ask me to open the itinerary editor.
''',
      );

      _resetItineraryState(keepLastItinerary: true);
    } catch (error) {
      _awaitingGenerationConfirmation = false;
      _addAssistantMessage(
        'I could not generate the itinerary.\n\n'
            '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ==============================================================
  // REAL MODULE CONTEXT
  // ==============================================================

  Future<Map<String, dynamic>> _buildAppContext() async {
    final user = AppServices.auth.currentUser;
    if (user == null) return const {};
    final uid = user.uid;

    final results = await Future.wait<Map<String, dynamic>>([
      _profileContext(uid),
      _groupContext(uid),
      _rewardContext(uid),
      _culturalContext(),
      _safetyContext(),
      _notificationContext(uid),
      _itineraryContext(uid),
    ]);

    return {
      'profile': results[0],
      'companion': results[1],
      'rewards': results[2],
      'cultural': results[3],
      'safety': results[4],
      'notifications': results[5],
      'itineraries': results[6],
    };
  }

  Future<Map<String, dynamic>> _profileContext(String uid) async {
    try {
      final snapshot = await AppServices.travelerRef(uid).get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      return {
        'displayName': data['displayName'] ?? '',
        'points': (data['points'] as num?)?.toInt() ?? 0,
        'travelInterests': data['travelInterests'] ?? [],
        'budgetPreference': data['budgetPreference'],
        'travelPace': data['travelPace'],
      };
    } catch (error) {
      return {'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _groupContext(String uid) async {
    try {
      final snapshot = await AppServices.db
          .collection('travel_groups')
          .where('memberIds', arrayContains: uid)
          .limit(10)
          .get();

      final groups = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if ('${data['status'] ?? ''}'.toLowerCase() != 'active') continue;

        final members = List<String>.from(data['memberIds'] ?? const []);
        groups.add({
          'groupId': doc.id,
          'name': data['name'] ?? 'Travel Group',
          'role': '${data['leaderId'] ?? ''}' == uid ? 'leader' : 'member',
          'memberCount': members.length,
          'memberNames': data['memberNames'] ?? {},
        });
      }

      return {'count': groups.length, 'groups': groups};
    } catch (error) {
      return {'count': 0, 'groups': [], 'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _rewardContext(String uid) async {
    try {
      final profile = await AppServices.travelerRef(uid).get();
      final points = (profile.data()?['points'] as num?)?.toInt() ?? 0;

      final snapshot = await AppServices.db
          .collection('vouchers')
          .where('status', isEqualTo: 'active')
          .limit(20)
          .get();

      final vouchers = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cost = (data['pointCost'] as num?)?.toInt() ?? 0;
        final inventory = (data['inventoryRemaining'] as num?)?.toInt() ?? 0;
        final expiry = asDate(data['expiresAt']);
        if (cost <= 0 || inventory <= 0) continue;
        if (expiry != null && expiry.isBefore(DateTime.now())) continue;

        vouchers.add({
          'voucherId': doc.id,
          'title': data['title'] ?? '',
          'vendorName': data['vendorName'] ?? '',
          'pointCost': cost,
          'canClaim': points >= cost,
          'pointsNeeded': points >= cost ? 0 : cost - points,
        });
      }

      return {
        'points': points,
        'availableVoucherCount': vouchers.length,
        'vouchers': vouchers.take(8).toList(),
      };
    } catch (error) {
      return {'points': 0, 'vouchers': [], 'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _culturalContext() async {
    try {
      final snapshot = await AppServices.db
          .collection('cultural_tasks')
          .where('status', isEqualTo: 'active')
          .limit(20)
          .get();

      final tasks = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final deadline = asDate(data['deadline']);
        if (deadline != null && deadline.isBefore(DateTime.now())) continue;
        tasks.add({
          'taskId': doc.id,
          'title': data['title'] ?? '',
          'category': data['category'] ?? '',
          'vendorName': data['vendorName'] ?? '',
          'rewardPoints': data['rewardPoints'] ?? 0,
        });
      }

      return {'activeCount': tasks.length, 'tasks': tasks.take(8).toList()};
    } catch (error) {
      return {'activeCount': 0, 'tasks': [], 'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _safetyContext() async {
    try {
      final snapshot = await AppServices.db
          .collection('hazards')
          .where('status', isEqualTo: 'verified')
          .limit(30)
          .get();

      final hazards = snapshot.docs.map((doc) {
        final data = doc.data();
        final point = _extractLatLng(data['location']);
        return {
          'hazardId': doc.id,
          'category': data['category'] ?? '',
          'severity': data['severity'] ?? '',
          'description': data['description'] ?? '',
          'latitude': point?.latitude,
          'longitude': point?.longitude,
        };
      }).toList();

      return {'verifiedCount': hazards.length, 'hazards': hazards.take(12).toList()};
    } catch (error) {
      return {'verifiedCount': 0, 'hazards': [], 'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _notificationContext(String uid) async {
    try {
      final snapshot = await AppServices.db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .limit(20)
          .get();
      final unread = snapshot.docs.where((doc) => doc.data()['read'] != true).length;
      return {'total': snapshot.docs.length, 'unread': unread};
    } catch (error) {
      return {'total': 0, 'unread': 0, 'error': '$error'};
    }
  }

  Future<Map<String, dynamic>> _itineraryContext(String uid) async {
    try {
      final snapshot = await AppServices.db
          .collection('itineraries')
          .where('userId', isEqualTo: uid)
          .limit(10)
          .get();

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate = asDate(a.data()['createdAt']) ?? DateTime(2000);
          final bDate = asDate(b.data()['createdAt']) ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      final items = docs.take(5).map((doc) {
        final data = doc.data();
        final stops = List<Map<String, dynamic>>.from(data['stops'] ?? const []);
        return {
          'itineraryId': doc.id,
          'title': data['title'] ?? '',
          'area': data['area'] ?? data['selectedArea'] ?? '',
          'dayCount': data['dayCount'] ?? data['numberOfDays'] ?? 1,
          'startDate': asDate(data['startDate'])?.toIso8601String(),
          'stopCount': stops.length,
          'stopNames': stops.take(8).map((s) => '${s['name'] ?? 'Place'}').toList(),
        };
      }).toList();

      return {
        'count': docs.length,
        'recent': items,
        'latest': items.isEmpty ? null : items.first,
      };
    } catch (error) {
      return {'count': 0, 'recent': [], 'latest': null, 'error': '$error'};
    }
  }

  // ==============================================================
  // MODULE ACTION ROUTER
  // ==============================================================

  Future<bool> _tryHandleModuleAction(String text) async {
    final appContext = await _buildAppContext();
    final analysis = await AiChatService.analyseAppAction(
      message: text,
      appContext: appContext,
    );

    final action = '${analysis['action'] ?? 'general_chat'}';
    final targetName = '${analysis['targetName'] ?? ''}'.trim();
    final targetNumberRaw = analysis['targetNumber'];
    final targetNumber = targetNumberRaw is num
        ? targetNumberRaw.toInt()
        : int.tryParse('${targetNumberRaw ?? ''}');

    switch (action) {
      case 'show_reward_points':
        final rewards = Map<String, dynamic>.from(appContext['rewards'] ?? {});
        _addAssistantMessage(
          'You currently have ⭐ ${rewards['points'] ?? 0} reward points.',
        );
        return true;

      case 'show_rewards':
        _showRewardsFromContext(appContext);
        return true;

      case 'open_rewards':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RewardsPage()),
        );
        return true;

      case 'open_voucher_wallet':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoucherWalletPage()),
        );
        return true;

      case 'show_groups':
        _showGroupsFromContext(appContext);
        return true;

      case 'open_companion':
        _addAssistantMessage(
          'I’ll open Companion. Safety-sensitive actions such as SOS or '
              'location sharing still require your explicit action there.',
        );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompanionPage()),
        );
        return true;

      case 'open_group_chat':
        return _openGroupChat(appContext, targetName);

      case 'show_group_members':
        _showGroupMembers(appContext, targetName);
        return true;

      case 'show_hazards':
        _showHazardsFromContext(appContext);
        return true;

      case 'open_safety':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SafetyPage()),
        );
        return true;

      case 'report_hazard':
        _addAssistantMessage(
          'I’ll open the hazard report form. You must review and submit the '
              'report yourself.',
        );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateHazardPage()),
        );
        return true;

      case 'show_cultural_tasks':
        _showCulturalTasksFromContext(appContext);
        return true;

      case 'open_cultural_tasks':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CulturalTasksPage()),
        );
        return true;

      case 'show_notifications':
        final notifications =
        Map<String, dynamic>.from(appContext['notifications'] ?? {});
        final unread = notifications['unread'] ?? 0;
        _addAssistantMessage(
          unread == 0
              ? 'You have no unread notifications.'
              : 'You currently have $unread unread notification(s).',
        );
        return true;

      case 'open_notifications':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
        return true;

      case 'show_profile':
        final profile = Map<String, dynamic>.from(appContext['profile'] ?? {});
        _addAssistantMessage(
          'Profile summary:\n\n'
              '👤 ${profile['displayName'] ?? 'Traveler'}\n'
              '⭐ ${profile['points'] ?? 0} points\n'
              '🎯 Interests: ${_listText(profile['travelInterests'])}\n'
              '💰 Budget preference: ${profile['budgetPreference'] ?? '-'}\n'
              '🚶 Pace: ${profile['travelPace'] ?? '-'}',
        );
        return true;

      case 'open_profile':
        final user = AppServices.auth.currentUser;
        if (user == null) return true;
        final snapshot = await AppServices.travelerRef(user.uid).get();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TravelerProfilePage(
              profile: snapshot.data() ?? const <String, dynamic>{},
            ),
          ),
        );
        return true;

      case 'show_itineraries':
        _showItinerariesFromContext(appContext);
        return true;

      case 'open_itineraries':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyItinerariesPage()),
        );
        return true;

      case 'describe_latest_itinerary':
        await _describeLatestItinerary(targetNumber);
        return true;

      case 'open_latest_itinerary':
        await _openLatestItinerary();
        return true;

      case 'edit_latest_itinerary':
        await _editLatestItinerary();
        return true;

      case 'show_itinerary_rewards':
        await _showLatestItineraryRewards();
        return true;

      case 'show_itinerary_cultural_tasks':
        await _showLatestItineraryCulturalTasks();
        return true;

      case 'check_itinerary_safety':
        await _checkLatestItinerarySafety();
        return true;
    }

    return false;
  }

  void _showRewardsFromContext(Map<String, dynamic> appContext) {
    final rewards = Map<String, dynamic>.from(appContext['rewards'] ?? {});
    final vouchers = List<Map<String, dynamic>>.from(rewards['vouchers'] ?? []);
    final points = rewards['points'] ?? 0;

    if (vouchers.isEmpty) {
      _addAssistantMessage(
        'You have $points points, but there are no active claimable vouchers '
            'listed right now.',
      );
      return;
    }

    final lines = vouchers.take(6).map((voucher) {
      final canClaim = voucher['canClaim'] == true;
      return '• ${voucher['title']} — ${voucher['pointCost']} pts'
          '${canClaim ? ' ✅' : ' (need ${voucher['pointsNeeded']} more)'}';
    }).join('\n');

    _addAssistantMessage(
      'You have ⭐ $points points.\n\nAvailable rewards:\n$lines',
    );
  }

  void _showGroupsFromContext(Map<String, dynamic> appContext) {
    final companion = Map<String, dynamic>.from(appContext['companion'] ?? {});
    final groups = List<Map<String, dynamic>>.from(companion['groups'] ?? []);

    if (groups.isEmpty) {
      _addAssistantMessage('You are not in any active travel groups.');
      return;
    }

    final lines = groups.map((group) {
      return '• ${group['name']} — ${group['role']}, '
          '${group['memberCount']} member(s)';
    }).join('\n');

    _addAssistantMessage('Your active travel groups:\n\n$lines');
  }

  Future<bool> _openGroupChat(
      Map<String, dynamic> appContext,
      String targetName,
      ) async {
    final companion = Map<String, dynamic>.from(appContext['companion'] ?? {});
    final groups = List<Map<String, dynamic>>.from(companion['groups'] ?? []);

    final selected = _selectGroup(groups, targetName);
    if (selected == null) {
      _addAssistantMessage(
        groups.isEmpty
            ? 'You are not currently in an active travel group.'
            : 'You are in more than one group. Tell me which group chat you '
            'want to open.',
      );
      return true;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatPage(
          groupId: '${selected['groupId']}',
          groupName: '${selected['name']}',
        ),
      ),
    );
    return true;
  }

  void _showGroupMembers(Map<String, dynamic> appContext, String targetName) {
    final companion = Map<String, dynamic>.from(appContext['companion'] ?? {});
    final groups = List<Map<String, dynamic>>.from(companion['groups'] ?? []);
    final selected = _selectGroup(groups, targetName);

    if (selected == null) {
      _addAssistantMessage(
        groups.isEmpty
            ? 'You are not currently in an active travel group.'
            : 'Tell me which travel group you mean.',
      );
      return;
    }

    final names = Map<String, dynamic>.from(selected['memberNames'] ?? {});
    final lines = names.values.isEmpty
        ? 'Member names are not available.'
        : names.values.map((name) => '• $name').join('\n');
    _addAssistantMessage('Members of ${selected['name']}:\n\n$lines');
  }

  Map<String, dynamic>? _selectGroup(
      List<Map<String, dynamic>> groups,
      String targetName,
      ) {
    if (groups.isEmpty) return null;
    if (targetName.trim().isEmpty) return groups.length == 1 ? groups.first : null;

    final target = targetName.toLowerCase();
    for (final group in groups) {
      final name = '${group['name'] ?? ''}'.toLowerCase();
      if (name.contains(target) || target.contains(name)) return group;
    }
    return null;
  }

  void _showHazardsFromContext(Map<String, dynamic> appContext) {
    final safety = Map<String, dynamic>.from(appContext['safety'] ?? {});
    final hazards = List<Map<String, dynamic>>.from(safety['hazards'] ?? []);

    if (hazards.isEmpty) {
      _addAssistantMessage('There are currently no verified hazards listed.');
      return;
    }

    final lines = hazards.take(6).map((hazard) {
      return '• ${hazard['category']} (${hazard['severity']}) — '
          '${hazard['description']}';
    }).join('\n');

    _addAssistantMessage(
      'I found ${hazards.length} verified hazard(s):\n\n$lines',
    );
  }

  void _showCulturalTasksFromContext(Map<String, dynamic> appContext) {
    final cultural = Map<String, dynamic>.from(appContext['cultural'] ?? {});
    final tasks = List<Map<String, dynamic>>.from(cultural['tasks'] ?? []);

    if (tasks.isEmpty) {
      _addAssistantMessage('There are currently no active cultural tasks.');
      return;
    }

    final lines = tasks.take(6).map((task) {
      return '• ${task['title']} — ${task['rewardPoints']} pts';
    }).join('\n');

    _addAssistantMessage('Active cultural tasks:\n\n$lines');
  }

  void _showItinerariesFromContext(Map<String, dynamic> appContext) {
    final itineraries = Map<String, dynamic>.from(appContext['itineraries'] ?? {});
    final recent = List<Map<String, dynamic>>.from(itineraries['recent'] ?? []);

    if (recent.isEmpty) {
      _addAssistantMessage('You do not have any saved itineraries yet.');
      return;
    }

    final lines = recent.map((item) {
      return '• ${item['title']} — ${item['dayCount']} day(s), '
          '${item['stopCount']} stop(s)';
    }).join('\n');

    _addAssistantMessage('Your recent itineraries:\n\n$lines');
  }

  // ==============================================================
  // LATEST ITINERARY OPERATIONS
  // ==============================================================

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _latestItineraryDoc() async {
    final user = AppServices.auth.currentUser;
    if (user == null) return null;

    final snapshot = await AppServices.db
        .collection('itineraries')
        .where('userId', isEqualTo: user.uid)
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aDate = asDate(a.data()['createdAt']) ?? DateTime(2000);
        final bDate = asDate(b.data()['createdAt']) ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    return docs.first;
  }

  Future<void> _describeLatestItinerary(int? requestedDay) async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    final data = doc.data();
    final days = List<Map<String, dynamic>>.from(data['days'] ?? const []);
    final allStops = List<Map<String, dynamic>>.from(data['stops'] ?? const []);

    if (requestedDay != null && requestedDay > 0 && days.isNotEmpty) {
      final index = requestedDay - 1;
      if (index >= days.length) {
        _addAssistantMessage(
          'This itinerary has ${days.length} day(s), so Day $requestedDay '
              'does not exist.',
        );
        return;
      }

      final day = days[index];
      final stops = List<Map<String, dynamic>>.from(day['stops'] ?? const []);
      final lines = stops.isEmpty
          ? 'No stops are stored for this day.'
          : stops.asMap().entries.map((entry) {
        return '${entry.key + 1}. ${entry.value['name'] ?? 'Place'}';
      }).join('\n');

      _addAssistantMessage(
        'Day $requestedDay of ${data['title'] ?? 'your itinerary'}:\n\n'
            '$lines\n\n'
            'Estimated activity time: '
            '${_minutesToReadableTime((day['totalEstimatedMinutes'] as num?)?.toInt() ?? 0)}',
      );
      return;
    }

    final stopLines = allStops.take(8).toList().asMap().entries.map((entry) {
      return '${entry.key + 1}. ${entry.value['name'] ?? 'Place'}';
    }).join('\n');

    _addAssistantMessage(
      '${data['title'] ?? 'Your latest itinerary'}\n\n'
          '📍 ${data['area'] ?? data['selectedArea'] ?? '-'}\n'
          '🗓️ ${data['dayCount'] ?? data['numberOfDays'] ?? 1} day(s)\n'
          '🗺️ ${allStops.length} stop(s)\n'
          '⏱️ ${_minutesToReadableTime((data['totalEstimatedMinutes'] as num?)?.toInt() ?? 0)}\n\n'
          '$stopLines',
    );
  }

  Future<void> _openLatestItinerary() async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryDetailPage(itineraryId: doc.id),
      ),
    );
  }

  Future<void> _editLatestItinerary() async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    _addAssistantMessage('I’ll open the Daily Planner itinerary editor.');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryEditPage(
          itineraryId: doc.id,
          itinerary: doc.data(),
        ),
      ),
    );
  }

  Future<void> _showLatestItineraryRewards() async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    final stops = List<Map<String, dynamic>>.from(doc.data()['stops'] ?? const []);
    final found = <String>[];

    for (final stop in stops) {
      final vouchers = stop['activeVouchers'];
      if (vouchers is! List || vouchers.isEmpty) continue;
      final placeName = '${stop['name'] ?? 'Itinerary stop'}';
      for (final raw in vouchers.take(3)) {
        if (raw is! Map) continue;
        final voucher = Map<String, dynamic>.from(raw);
        found.add(
          '• $placeName — ${voucher['title'] ?? 'Voucher'} '
              '${voucher['pointCost'] == null ? '' : '(${voucher['pointCost']} pts)'}',
        );
      }
    }

    _addAssistantMessage(
      found.isEmpty
          ? 'I did not find active voucher data attached to the stops in your '
          'latest itinerary.'
          : 'Rewards/vouchers along your latest itinerary:\n\n${found.join('\n')}',
    );
  }

  Future<void> _showLatestItineraryCulturalTasks() async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    final stops = List<Map<String, dynamic>>.from(doc.data()['stops'] ?? const []);
    final found = <String>[];

    for (final stop in stops) {
      final raw = stop['culturalTask'];
      if (raw is! Map) continue;
      final task = Map<String, dynamic>.from(raw);
      found.add(
        '• ${task['title'] ?? task['taskTitle'] ?? 'Cultural task'} — '
            '${task['rewardPoints'] ?? 0} pts',
      );
    }

    _addAssistantMessage(
      found.isEmpty
          ? 'There are no cultural tasks attached to the stops in your latest '
          'itinerary.'
          : 'Cultural tasks in your latest itinerary:\n\n${found.join('\n')}',
    );
  }

  Future<void> _checkLatestItinerarySafety() async {
    final doc = await _latestItineraryDoc();
    if (doc == null) {
      _addAssistantMessage('You do not have a saved itinerary yet.');
      return;
    }

    final hazardSnapshot = await AppServices.db
        .collection('hazards')
        .where('status', isEqualTo: 'verified')
        .limit(50)
        .get();

    final stops = List<Map<String, dynamic>>.from(doc.data()['stops'] ?? const []);
    final warnings = <Map<String, dynamic>>[];

    for (final stop in stops) {
      final stopPoint = _extractLatLng(stop['location']) ??
          _extractLatLng({
            'latitude': stop['latitude'] ?? stop['lat'],
            'longitude': stop['longitude'] ?? stop['lng'],
          });
      if (stopPoint == null) continue;

      for (final hazardDoc in hazardSnapshot.docs) {
        final hazard = hazardDoc.data();
        final hazardPoint = _extractLatLng(hazard['location']);
        if (hazardPoint == null) continue;

        final distance = Geolocator.distanceBetween(
          stopPoint.latitude,
          stopPoint.longitude,
          hazardPoint.latitude,
          hazardPoint.longitude,
        );

        if (distance <= 500) {
          warnings.add({
            'stop': stop['name'] ?? 'Itinerary stop',
            'category': hazard['category'] ?? 'Hazard',
            'severity': hazard['severity'] ?? 'Unknown',
            'distance': distance,
          });
        }
      }
    }

    warnings.sort(
          (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    if (warnings.isEmpty) {
      _addAssistantMessage(
        'I did not find any verified hazard within 500 m of the mapped stops '
            'in your latest itinerary. This is only based on currently verified '
            'MyHeritage hazard reports, not a guarantee that an area is risk-free.',
      );
      return;
    }

    final lines = warnings.take(6).map((warning) {
      return '• ${warning['category']} (${warning['severity']}) — about '
          '${(warning['distance'] as double).round()} m from ${warning['stop']}';
    }).join('\n');

    _addAssistantMessage(
      'I found verified hazards near your itinerary:\n\n$lines\n\n'
          'You can ask me to open the Safety module for more details.',
    );
  }

  LatLng? _extractLatLng(dynamic raw) {
    if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final lat = map['latitude'] ?? map['lat'];
      final lng = map['longitude'] ?? map['lng'] ?? map['lon'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  // ==============================================================
  // GENERAL CHAT WITH REAL CONTEXT
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
            .take(10)
            .toList()
            .reversed;

    final historyText =
    recent.map(
          (message) {
        final role =
        message['role'] == 'user'
            ? 'User'
            : 'Assistant';

        return '$role: ${message['text']}';
      },
    ).join('\n');

    Map<String, dynamic> appContext =
    const {};

    try {
      appContext =
      await _buildAppContext();
    } catch (error) {
      debugPrint(
        'APP CONTEXT ERROR: $error',
      );
    }

    final activeDraft =
    _itineraryDraft?.toMap();

    final response =
    await AiChatService.ask(
      '''
You are the intelligent conversational assistant inside
MyHeritage Explorer.

You are a capable general assistant, but you also understand the
MyHeritage tourism application.

============================================================
YOUR CAPABILITIES
============================================================

You can answer:

- general questions
- Malaysia tourism questions
- cultural and heritage questions
- travel advice
- explanations
- recommendations
- questions about MyHeritage Explorer
- questions about the user's real app data when context is available

You do NOT have to force every conversation into an app module.

If the user asks a normal question, simply answer it naturally.

Examples:

"What is the capital of Malaysia?"
→ Answer normally.

"Why is George Town famous?"
→ Explain normally.

"What food is famous in Penang?"
→ Answer normally.

"How many points do I have?"
→ Use real application context.

============================================================
REAL APPLICATION CONTEXT
============================================================

${jsonEncode(appContext)}

============================================================
ACTIVE DAILY PLANNER DRAFT
============================================================

${jsonEncode(activeDraft)}

The user may currently be creating an itinerary.

IMPORTANT:

If they ask an unrelated question while an itinerary is in progress,
answer their question normally.

Do NOT force them back into itinerary setup.

The Flutter application remembers the itinerary draft separately.

============================================================
RULES
============================================================

- Never invent personal app data.
- If information exists in REAL APPLICATION CONTEXT, use it.
- Do not pretend an app action occurred.
- Do not claim that an SOS, voucher claim, hazard report or GPS share
  was completed.
- Do not fabricate a saved itinerary.
- Daily Planner generation is performed by Flutter, not by you.
- Be conversational and helpful.
- Keep answers concise unless the user asks for more detail.

============================================================
RECENT CONVERSATION
============================================================

$historyText

============================================================
LATEST USER MESSAGE
============================================================

$text

Answer the user's latest question naturally.
''',
    );

    _addAssistantMessage(
      response,
    );
  }

  // ==============================================================
  // STATE + FORMAT HELPERS
  // ==============================================================

  void _cancelItinerary() {
    _resetItineraryState();
    _addAssistantMessage(
      'The itinerary planning process has been cancelled. You can start a new '
          'Daily Planner request anytime.',
    );
  }

  void _resetItineraryState({bool keepLastItinerary = false}) {
    _itineraryDraft = null;
    _awaitingGenerationConfirmation = false;
    if (!keepLastItinerary) _lastCreatedItineraryId = null;
  }

  bool _looksLikeItineraryRequest(String text) {
    final value = text.toLowerCase();
    final hasTripWord = value.contains('itinerary') ||
        value.contains('trip') ||
        value.contains('travel plan') ||
        value.contains('day plan');
    final hasAction = value.contains('create') ||
        value.contains('make') ||
        value.contains('generate') ||
        value.contains('plan');
    return hasTripWord && hasAction;
  }

  String _budgetRange(String level) {
    switch (level) {
      case 'Low':
        return 'RM 30 - 80 / day';
      case 'High':
        return 'RM 150+ / day';
      default:
        return 'RM 80 - 150 / day';
    }
  }

  String _formatHours(double hours) {
    return hours % 1 == 0
        ? '${hours.toInt()} hours'
        : '${hours.toStringAsFixed(1)} hours';
  }

  String _format24Hour(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatStartTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final date = DateTime(2026, 1, 1, hour, minute);
    return DateFormat.jm().format(date);
  }

  String _minutesToReadableTime(int totalMinutes) {
    if (totalMinutes <= 0) return '-';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '$minutes minutes';
    if (minutes == 0) return '$hours hour${hours == 1 ? '' : 's'}';
    return '$hours h $minutes min';
  }

  String _dateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('d MMMM yyyy').format(start);
    }
    return '${DateFormat('d MMM yyyy').format(start)} – '
        '${DateFormat('d MMM yyyy').format(end)}';
  }

  String _listText(dynamic value) {
    if (value is List && value.isNotEmpty) return value.join(', ');
    return '-';
  }

  // ==============================================================
  // MESSAGE HELPERS
  // ==============================================================

  void _addAssistantMessage(String text) {
    if (!mounted) return;
    setState(() {
      messages.add({'role': 'assistant', 'text': text.trim()});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Travel Assistant'),
            Text(
              'AI + Daily Planner + MyHeritage modules',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(
              child: ExplorerStatusBadge(
                label: 'AI',
                tone: ExplorerStatusTone.navy,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: ExplorerColors.navySoft,
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            child: const Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  color: ExplorerColors.navy,
                  size: 17,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Daily Planner is fully connected. The assistant can also '
                        'read/open Rewards, Cultural, Safety, Companion, '
                        'Notifications and Profile features.',
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 10,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              itemCount: messages.length + (sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (sending && index == messages.length) {
                  return _thinkingBubble();
                }
                final message = messages[index];
                return _messageBubble(
                  text: message['text'] ?? '',
                  isUser: message['role'] == 'user',
                );
              },
            ),
          ),
          if (_lastCreatedItineraryId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItineraryDetailPage(
                          itineraryId: _lastCreatedItineraryId!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Open Generated Itinerary'),
                ),
              ),
            ),
          if (messages.length <= 3 || _lastCreatedItineraryId != null)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      suggestion,
                      style: const TextStyle(fontSize: 10),
                    ),
                    onPressed: sending ? null : () => send(suggestion),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: ExplorerColors.border),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !sending,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask me to plan, check or open something...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    icon: sending
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: ExplorerColors.navy,
            child: Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFDDE8FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ExplorerColors.navy,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble({
    required String text,
    required bool isUser,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: ExplorerColors.navy,
              child: Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(13),
              constraints: const BoxConstraints(maxWidth: 330),
              decoration: BoxDecoration(
                color: isUser
                    ? ExplorerColors.navy
                    : const Color(0xFFDDE8FF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 3),
                  bottomRight: Radius.circular(isUser ? 3 : 14),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : ExplorerColors.navy,
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
