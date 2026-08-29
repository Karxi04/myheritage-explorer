part of '../traveler_pages.dart';

class ItineraryScheduleResult {
  const ItineraryScheduleResult({
    required this.stops,
    required this.totalEstimatedMinutes,
    required this.remainingMinutes,
    required this.startMinutes,
    required this.endMinutes,
  });

  final List<Map<String, dynamic>> stops;
  final int totalEstimatedMinutes;
  final int remainingMinutes;
  final int startMinutes;
  final int endMinutes;
}

class ItineraryBudgetEstimate {
  const ItineraryBudgetEstimate({
    required this.dayBudget,
    required this.tripBudget,
    required this.budgetLevel,
  });

  final int dayBudget;
  final int tripBudget;
  final String budgetLevel;
}

class ItineraryBudgetEstimator {
  const ItineraryBudgetEstimator._();

  static const int lowDailyLimit = 50;
  static const int mediumDailyLimit = 150;

  static ItineraryBudgetEstimate estimateDay(
    List<Map<String, dynamic>> stops,
  ) {
    final dayBudget = stops.fold<int>(
      0,
      (total, stop) => total + estimateStop(stop),
    );
    return ItineraryBudgetEstimate(
      dayBudget: dayBudget,
      tripBudget: dayBudget,
      budgetLevel: levelForDailyBudget(dayBudget),
    );
  }

  static ItineraryBudgetEstimate estimateTrip(
    List<Map<String, dynamic>> days, {
    List<Map<String, dynamic>> fallbackStops = const <Map<String, dynamic>>[],
  }) {
    final dayBudgets = <int>[];
    for (final day in days) {
      final rawStops = day['stops'];
      if (rawStops is! List) continue;
      final stops = rawStops
          .whereType<Map>()
          .map((stop) => Map<String, dynamic>.from(stop))
          .toList();
      dayBudgets.add(
        stops.fold<int>(0, (total, stop) => total + estimateStop(stop)),
      );
    }

    if (dayBudgets.isEmpty && fallbackStops.isNotEmpty) {
      dayBudgets.add(
        fallbackStops.fold<int>(
          0,
          (total, stop) => total + estimateStop(stop),
        ),
      );
    }

    final tripBudget = dayBudgets.fold<int>(0, (total, day) => total + day);
    final averageDayBudget = dayBudgets.isEmpty
        ? 0
        : (tripBudget / dayBudgets.length).round();
    return ItineraryBudgetEstimate(
      dayBudget: averageDayBudget,
      tripBudget: tripBudget,
      budgetLevel: levelForDailyBudget(averageDayBudget),
    );
  }

  static int estimateStop(Map<String, dynamic> stop) {
    final explicit = _explicitCost(stop);
    if (explicit != null) return explicit;

    final level = '${stop['budgetLevel'] ?? stop['budget'] ?? ''}'
        .trim()
        .toLowerCase();
    final category = '${stop['category'] ?? ''}'.toLowerCase();
    final tags = (stop['tags'] as List?)
            ?.map((tag) => '$tag'.toLowerCase())
            .toList() ??
        const <String>[];

    if (level.contains('free') || category.contains('free')) return 0;
    if (level.contains('high') || category.contains('fine dining')) return 90;
    if (level.contains('medium')) {
      if (category.contains('food') || tags.any((tag) => tag.contains('food'))) {
        return 35;
      }
      return 45;
    }
    if (level.contains('low')) {
      if (category.contains('food') ||
          category.contains('hawker') ||
          category.contains('market')) {
        return 20;
      }
      return 10;
    }
    if (category.contains('food') ||
        category.contains('cafe') ||
        category.contains('restaurant')) {
      return 35;
    }
    if (category.contains('heritage') ||
        category.contains('landmark') ||
        category.contains('temple') ||
        category.contains('mosque') ||
        category.contains('park')) {
      return 10;
    }
    return 30;
  }

  static String levelForDailyBudget(int dayBudget) {
    if (dayBudget <= lowDailyLimit) return 'Low';
    if (dayBudget <= mediumDailyLimit) return 'Medium';
    return 'High';
  }

  static int? _explicitCost(Map<String, dynamic> stop) {
    for (final key in const [
      'estimatedCostRm',
      'estimatedCost',
      'costRm',
      'cost',
      'priceRm',
      'price',
      'entryFee',
    ]) {
      final parsed = _parseCost(stop[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static int? _parseCost(Object? value) {
    if (value == null) return null;
    if (value is num) return max(0, value.round());
    final text = '$value'.toLowerCase().trim();
    if (text.isEmpty || text == 'null') return null;
    if (text.contains('free') || text == 'no' || text == 'false') return 0;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    if (match == null) return null;
    return max(0, double.parse(match.group(0)!).round());
  }
}

class ItinerarySchedulePlanner {
  const ItinerarySchedulePlanner._();

  static const int defaultStartMinutes = 9 * 60;

  static ItineraryScheduleResult plan({
    required List<Map<String, dynamic>> stops,
    required String pace,
    required double availableHours,
    int? preferredStartMinutes,
  }) {
    final planned = stops
        .map((stop) => Map<String, dynamic>.from(stop))
        .toList(growable: true);
    if (planned.isEmpty) {
      final start = preferredStartMinutes ?? defaultStartMinutes;
      return ItineraryScheduleResult(
        stops: const [],
        totalEstimatedMinutes: 0,
        remainingMinutes: (availableHours * 60).round(),
        startMinutes: start,
        endMinutes: start,
      );
    }

    final start = preferredStartMinutes != null
        ? _suggestedStartWithPreferred(planned.first, preferredStartMinutes)
        : _suggestedStart(planned.first, defaultStartMinutes);
    var cursor = start;

    for (var index = 0; index < planned.length; index++) {
      final stop = planned[index];
      final travel = index == 0
          ? 0
          : _travelMinutes(planned[index - 1], stop, pace);
      final distance = index == 0
          ? null
          : _distanceMeters(planned[index - 1], stop);
      var arrival = cursor + travel;
      final duration = max(
        30,
        (stop['durationMinutes'] as num?)?.round() ?? 60,
      );

      final openingWindow = _openingWindow('${stop['openingHours'] ?? ''}');
      if (openingWindow != null && !openingWindow.open24Hours) {
        if (arrival < openingWindow.opens && openingWindow.opens < openingWindow.closes) {
          arrival = openingWindow.opens;
        }
      }

      final departure = arrival + duration;
      final notes = <String>[];

      final openingNote = _openingNote(
        window: openingWindow,
        arrival: arrival,
        departure: departure,
      );
      if (openingNote != null) notes.add(openingNote);

      if (openingWindow == null &&
          '${stop['openingHours'] ?? ''}'.trim().isNotEmpty) {
        notes.add('Opening hours need a quick check before visiting.');
      }

      if (travel >= 35) {
        final fromName = '${planned[index - 1]['name'] ?? 'previous stop'}';
        final toName = '${stop['name'] ?? 'this stop'}';
        notes.add(
          'Long trip: $fromName to $toName takes about $travel minutes. Put closer places together if possible.',
        );
      } else if (travel >= 22) {
        final fromName = '${planned[index - 1]['name'] ?? 'previous stop'}';
        notes.add(
          'Travel from $fromName takes about $travel minutes. Keep a small buffer.',
        );
      }

      final mealSuggestion = GeoapifyPlanner._mealSuggestionText(stop, arrival);
      if (mealSuggestion == null) {
        stop.remove('mealSuggestionLabel');
      } else {
        stop['mealSuggestionLabel'] = mealSuggestion;
      }

      stop
        ..['sequence'] = index + 1
        ..['travelMinutesBefore'] = travel
        ..['routeDistanceMetersBefore'] = distance
        ..['suggestedStartMinutes'] = arrival
        ..['suggestedEndMinutes'] = departure
        ..['suggestedTimeLabel'] =
            '${formatTime(arrival)} - ${formatTime(departure)}'
        ..['scheduleNotes'] = notes
        ..['scheduleStatus'] = notes.isEmpty ? 'ok' : 'caution';

      cursor = departure;
    }

    _addOrderSuggestions(planned, pace);

    final total = max(0, cursor - start);
    final remaining = max(0, (availableHours * 60).round() - total);

    return ItineraryScheduleResult(
      stops: planned,
      totalEstimatedMinutes: total,
      remainingMinutes: remaining,
      startMinutes: start,
      endMinutes: cursor,
    );
  }

  static String formatTime(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  static int _suggestedStartWithPreferred(Map<String, dynamic> first, int preferred) {
    final window = _openingWindow('${first['openingHours'] ?? ''}');
    if (window == null || window.open24Hours) return preferred;
    if (window.opens > preferred && window.opens < window.closes) {
      return window.opens;
    }
    return preferred;
  }

  static int _suggestedStart(Map<String, dynamic> first, int fallback) {
    final window = _openingWindow('${first['openingHours'] ?? ''}');
    if (window == null || window.open24Hours) return fallback;
    if (window.opens > fallback && window.opens < window.closes) {
      return window.opens;
    }
    return fallback;
  }

  static int _travelMinutes(
    Map<String, dynamic> from,
    Map<String, dynamic> to,
    String pace,
  ) {
    final fromPoint = GeoapifyPlanner._coordinateMap(from['location']);
    final toPoint = GeoapifyPlanner._coordinateMap(to['location']);
    if (fromPoint == null || toPoint == null) {
      return (to['travelMinutesBefore'] as num?)?.round() ??
          switch (pace) {
            'Relaxed' => 15,
            'Fast' || 'Packed' => 8,
            _ => 10,
          };
    }
    return GeoapifyPlanner._estimatedTravelMinutes(
      from['location'],
      to['location'],
      pace,
    );
  }

  static int? _distanceMeters(
    Map<String, dynamic> from,
    Map<String, dynamic> to,
  ) {
    final fromPoint = GeoapifyPlanner._coordinateMap(from['location']);
    final toPoint = GeoapifyPlanner._coordinateMap(to['location']);
    if (fromPoint == null || toPoint == null) return null;
    return (GeoapifyPlanner._haversineKm(
              fromPoint['latitude']!,
              fromPoint['longitude']!,
              toPoint['latitude']!,
              toPoint['longitude']!,
            ) *
            1000)
        .round();
  }

  static void _addOrderSuggestions(
    List<Map<String, dynamic>> stops,
    String pace,
  ) {
    for (var index = 0; index + 1 < stops.length; index++) {
      final current = stops[index];
      final next = stops[index + 1];
      final currentWindow = _openingWindow('${current['openingHours'] ?? ''}');
      final nextWindow = _openingWindow('${next['openingHours'] ?? ''}');

      if (nextWindow != null && currentWindow != null) {
        if (nextWindow.closes + 30 < currentWindow.closes) {
          _addNote(
            next,
            'This place closes earlier than the stop before it. Move it earlier if the time feels tight.',
          );
        } else if (nextWindow.opens + 60 < currentWindow.opens) {
          _addNote(
            next,
            'This place opens earlier than the stop before it. It may fit better earlier in the day.',
          );
        }
      }

      final saving = _swapSavingMinutes(stops, index, pace);
      if (saving >= 10) {
        _addNote(
          current,
          'Swapping this with the next stop may save about $saving minutes.',
        );
        _addNote(
          next,
          'Move this before the previous stop to reduce travel time.',
        );
      }
    }
  }

  static int _swapSavingMinutes(
    List<Map<String, dynamic>> stops,
    int index,
    String pace,
  ) {
    final previous = index == 0 ? null : stops[index - 1];
    final current = stops[index];
    final next = stops[index + 1];
    final after = index + 2 < stops.length ? stops[index + 2] : null;

    final currentCost =
        (previous == null ? 0 : _travelMinutes(previous, current, pace)) +
        _travelMinutes(current, next, pace) +
        (after == null ? 0 : _travelMinutes(next, after, pace));
    final swappedCost =
        (previous == null ? 0 : _travelMinutes(previous, next, pace)) +
        _travelMinutes(next, current, pace) +
        (after == null ? 0 : _travelMinutes(current, after, pace));

    return currentCost - swappedCost;
  }

  static void _addNote(Map<String, dynamic> stop, String note) {
    final notes = List<String>.from(stop['scheduleNotes'] ?? const <String>[]);
    if (!notes.contains(note)) notes.add(note);
    stop['scheduleNotes'] = notes;
    stop['scheduleStatus'] = notes.isEmpty ? 'ok' : 'caution';
  }

  static String? _openingNote({
    required _OpeningWindow? window,
    required int arrival,
    required int departure,
  }) {
    if (window == null || window.open24Hours) return null;

    if (arrival < window.opens) {
      return 'Too early: opens at ${formatTime(window.opens)}. Move this stop later.';
    }
    if (arrival >= window.closes) {
      return 'Likely closed: closes at ${formatTime(window.closes)}.';
    }
    if (departure > window.closes) {
      return 'Time is too late: visit may pass closing at ${formatTime(window.closes)}.';
    }
    if (window.closes - departure <= 30) {
      return 'Tight timing: closes at ${formatTime(window.closes)}.';
    }
    return null;
  }

  static _OpeningWindow? _openingWindow(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.contains('24/7') || lower.contains('24 hours')) {
      return const _OpeningWindow(opens: 0, closes: 24 * 60, open24Hours: true);
    }
    if (lower.contains('closed')) return null;

    final normalized = text
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2012', '-')
        .replaceAll('\u202f', ' ')
        .replaceAll('.', ':');
    final matches = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    ).allMatches(normalized).toList();
    if (matches.length < 2) return null;

    final first = _parseTimeMatch(matches[0], null);
    var second = _parseTimeMatch(
      matches[1],
      matches[1].group(3) ?? matches[0].group(3),
    );
    if (first == null || second == null) return null;

    var opens = first;
    var closes = second;
    if (closes <= opens) closes += 24 * 60;

    if (matches[0].group(3) == null &&
        matches[1].group(3)?.toLowerCase() == 'pm' &&
        opens < 12 * 60 &&
        opens + 12 * 60 < closes) {
      opens += 12 * 60;
    }

    return _OpeningWindow(opens: opens, closes: closes);
  }

  static int? _parseTimeMatch(RegExpMatch match, String? fallbackMeridiem) {
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = (match.group(3) ?? fallbackMeridiem ?? '').toLowerCase();
    if (hour == null || hour > 24 || minute > 59) return null;

    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour == 24) hour = 0;
    return hour * 60 + minute;
  }
}

class _OpeningWindow {
  const _OpeningWindow({
    required this.opens,
    required this.closes,
    this.open24Hours = false,
  });

  final int opens;
  final int closes;
  final bool open24Hours;
}

class ItineraryTimelineSummary extends StatelessWidget {
  const ItineraryTimelineSummary({super.key, required this.schedule});

  final ItineraryScheduleResult schedule;

  @override
  Widget build(BuildContext context) {
    if (schedule.stops.isEmpty) return const SizedBox.shrink();

    return ExplorerCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: ExplorerColors.navySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: ExplorerColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested Day Timeline',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ItinerarySchedulePlanner.formatTime(schedule.startMinutes)} - '
                  '${ItinerarySchedulePlanner.formatTime(schedule.endMinutes)} '
                  '(${(schedule.totalEstimatedMinutes / 60).toStringAsFixed(1)} hours planned)',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
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
}

class ScheduleNoteList extends StatelessWidget {
  const ScheduleNoteList({super.key, required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ExplorerColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ExplorerColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.take(3).map((note) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: ExplorerColors.goldDark,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
