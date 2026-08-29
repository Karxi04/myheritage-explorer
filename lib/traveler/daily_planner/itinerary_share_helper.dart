part of '../traveler_pages.dart';

class ItineraryShareHelper {
  const ItineraryShareHelper._();

  static const String publicWebUrl = 'https://myheritage-4fe2f.web.app/share/';
  static const String _shareCollection = 'shared_itineraries';
  static const String _shareCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _shortText(Object? value, [int maxLength = 350]) {
    final text = '${value ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength).trim()}…';
  }

  static Map<String, double>? _coordinatesFor(Map<String, dynamic> stop) =>
      ItineraryImageResolver.coordinatesFor(stop);

  static String previewImageForStop(Map<String, dynamic> stop) =>
      ItineraryImageResolver.previewImageForStop(stop);

  static double _availableHoursFor(Map<String, dynamic> itinerary) {
    final explicit = (itinerary['availableHours'] as num?)?.toDouble();
    if (explicit != null && explicit > 0) return explicit;

    final totalMinutes = (itinerary['totalEstimatedMinutes'] as num?)?.round();
    if (totalMinutes != null && totalMinutes > 0) {
      return max(1, totalMinutes / 60);
    }

    return 4;
  }

  static bool canCurrentUserManage(Map<String, dynamic> itinerary) {
    final user = AppServices.auth.currentUser;
    if (user == null) return false;
    return _isOwnedBy(itinerary, user.uid);
  }

  static bool _isOwnedBy(Map<String, dynamic> itinerary, String uid) {
    final ownerIds = <String>{
      '${itinerary['userId'] ?? ''}'.trim(),
      '${itinerary['travelerId'] ?? ''}'.trim(),
      '${itinerary['ownerId'] ?? ''}'.trim(),
      '${itinerary['createdBy'] ?? ''}'.trim(),
    }..remove('');
    if (ownerIds.isNotEmpty) return ownerIds.contains(uid);

    final hasSharedContext =
        '${itinerary['visibility'] ?? ''}' == 'public' ||
        '${itinerary['groupId'] ?? ''}'.trim().isNotEmpty ||
        '${itinerary['sharedFromGroupId'] ?? ''}'.trim().isNotEmpty ||
        '${itinerary['sharedBy'] ?? ''}'.trim().isNotEmpty;
    return !hasSharedContext;
  }

  static Future<Map<String, dynamic>> _publicStop(
    Map<String, dynamic> rawStop,
  ) async {
    final stop = await ItineraryImageResolver.resolveStop(rawStop);
    final coordinates = _coordinatesFor(stop);
    final previewImage = previewImageForStop(stop);
    final imageCandidates = ItineraryImageResolver.imageCandidatesFor(
      stop,
    ).take(6).toList();
    final publicStop = <String, dynamic>{
      'name': _shortText(stop['name'], 100),
      'description': _shortText(stop['description']),
      'formattedAddress': _shortText(
        stop['formattedAddress'] ?? stop['area'],
        180,
      ),
      'area': _shortText(stop['area'], 80),
      'category': _shortText(stop['category'], 60),
      'imageUrl': previewImage,
      'fallbackImageUrl':
          '${stop['fallbackImageUrl'] ?? stop['mapPreviewUrl'] ?? ''}',
      'imageCandidates': imageCandidates,
      'imageType':
          '${stop['imageType'] ?? (previewImage.isEmpty ? '' : 'map_preview')}',
      'durationMinutes': (stop['durationMinutes'] as num?)?.round() ?? 60,
      'travelMinutesBefore':
          (stop['travelMinutesBefore'] as num?)?.round() ?? 0,
      'routeDistanceMetersBefore':
          (stop['routeDistanceMetersBefore'] as num?)?.round(),
      'openingHours': _shortText(stop['openingHours'], 80),
      'suggestedStartMinutes':
          (stop['suggestedStartMinutes'] as num?)?.round(),
      'suggestedEndMinutes': (stop['suggestedEndMinutes'] as num?)?.round(),
      'suggestedTimeLabel': _shortText(stop['suggestedTimeLabel'], 40),
      'mealSuggestionLabel': _shortText(stop['mealSuggestionLabel'], 60),
      'scheduleStatus': _shortText(stop['scheduleStatus'], 20),
      'scheduleNotes': List<String>.from(
        stop['scheduleNotes'] ?? const <String>[],
      ).map((note) => _shortText(note, 180)).take(4).toList(),
      'rating':
          ((stop['inAppAverageRating'] as num?) ?? (stop['score'] as num?) ?? 0)
              .toDouble(),
      'reviewCount': (stop['inAppReviewCount'] as num?)?.round() ?? 0,
      'culturalTaskTitle': _shortText(stop['culturalTaskTitle'], 100),
      'culturalTaskRewardPoints':
          (stop['culturalTaskRewardPoints'] as num?)?.round() ?? 0,
      'mapUrl': _shortText(stop['mapUrl'], 350),
    };
    if (coordinates != null) publicStop['location'] = coordinates;
    return publicStop;
  }

  static Future<Map<String, dynamic>> _publicItineraryPayload(
    Map<String, dynamic> itinerary,
    String shareId,
  ) async {
    final createdAt = asDate(itinerary['createdAt']);
    final availableHours = _availableHoursFor(itinerary);
    final pace = '${itinerary['travelPace'] ?? 'Balanced'}';
    final preferredStartMinutes =
        (itinerary['suggestedStartMinutes'] as num?)?.round();
    final rawDays = (itinerary['days'] as List?)
            ?.whereType<Map>()
            .map((day) => Map<String, dynamic>.from(day))
            .where((day) => day['stops'] is List && (day['stops'] as List).isNotEmpty)
            .toList() ??
        const <Map<String, dynamic>>[];

    final publicDays = <Map<String, dynamic>>[];
    if (rawDays.isNotEmpty) {
      for (var index = 0; index < rawDays.length; index++) {
        final day = rawDays[index];
        final dayStops = List<Map<String, dynamic>>.from(
          (day['stops'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        final daySchedule = ItinerarySchedulePlanner.plan(
          stops: dayStops,
          pace: pace,
          availableHours:
              (day['availableHours'] as num?)?.toDouble() ?? availableHours,
          preferredStartMinutes:
              (day['suggestedStartMinutes'] as num?)?.round() ??
                  preferredStartMinutes,
        );
        final publicStops = await Future.wait(daySchedule.stops.map(_publicStop));
        final dayBudget = ItineraryBudgetEstimator.estimateDay(publicStops);
        publicDays.add({
          'dayNumber': (day['dayNumber'] as num?)?.round() ?? index + 1,
          'date': _shortText(day['date'], 40),
          'dateLabel': _shortText(day['dateLabel'], 80),
          'weather': day['weather'] is Map
              ? Map<String, dynamic>.from(day['weather'] as Map)
              : const <String, dynamic>{},
          'stops': publicStops,
          'suggestedStartMinutes': daySchedule.startMinutes,
          'suggestedEndMinutes': daySchedule.endMinutes,
          'totalEstimatedMinutes': daySchedule.totalEstimatedMinutes,
          'remainingMinutes': daySchedule.remainingMinutes,
          'budget': dayBudget.dayBudget,
          'budgetLevel': dayBudget.budgetLevel,
        });
      }
    } else {
      final stops = List<Map<String, dynamic>>.from(
        (itinerary['stops'] ?? const []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      final schedule = ItinerarySchedulePlanner.plan(
        stops: stops,
        pace: pace,
        availableHours: availableHours,
        preferredStartMinutes: preferredStartMinutes,
      );
      final publicStops = await Future.wait(schedule.stops.map(_publicStop));
      final dayBudget = ItineraryBudgetEstimator.estimateDay(publicStops);
      publicDays.add({
        'dayNumber': 1,
        'date': _shortText(
          itinerary['startDate'] ?? itinerary['targetDate'] ?? '',
          40,
        ),
        'dateLabel': _shortText(itinerary['dateLabel'] ?? '', 80),
        'weather': const <String, dynamic>{},
        'stops': publicStops,
        'suggestedStartMinutes': schedule.startMinutes,
        'suggestedEndMinutes': schedule.endMinutes,
        'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
        'remainingMinutes': schedule.remainingMinutes,
        'budget': dayBudget.dayBudget,
        'budgetLevel': dayBudget.budgetLevel,
      });
    }

    final publicStops = publicDays
        .expand((day) => List<Map<String, dynamic>>.from(day['stops'] as List))
        .toList();
    final startMinutes = (publicDays.first['suggestedStartMinutes'] as num?)
            ?.round() ??
        preferredStartMinutes ??
        ItinerarySchedulePlanner.defaultStartMinutes;
    final endMinutes = publicDays.fold<int>(
      startMinutes,
      (latest, day) => max(
        latest,
        (day['suggestedEndMinutes'] as num?)?.round() ?? latest,
      ),
    );
    final totalEstimatedMinutes = publicDays.fold<int>(
      0,
      (total, day) =>
          total + ((day['totalEstimatedMinutes'] as num?)?.round() ?? 0),
    );
    final remainingMinutes = publicDays.fold<int>(
      0,
      (total, day) => total + ((day['remainingMinutes'] as num?)?.round() ?? 0),
    );

    return <String, dynamic>{
      'shareId': shareId,
      'visibility': 'public',
      'title': _shortText(itinerary['title'] ?? 'Shared Penang Itinerary', 120),
      'area': _shortText(itinerary['area'] ?? 'Penang', 80),
      'availableHours': availableHours,
      'dayCount': publicDays.length,
      'startDate': _shortText(
        itinerary['startDate'] ?? itinerary['targetDate'] ?? '',
        40,
      ),
      'endDate': _shortText(itinerary['endDate'] ?? '', 40),
      'budgetLevel': _shortText(itinerary['budgetLevel'], 30),
      'travelPace': _shortText(itinerary['travelPace'], 30),
      'interests': List<String>.from(
        itinerary['interests'] ?? const <String>[],
      ),
      'suggestedStartMinutes': startMinutes,
      'suggestedEndMinutes': endMinutes,
      'timelineLabel':
          '${ItinerarySchedulePlanner.formatTime(startMinutes)} - '
          '${ItinerarySchedulePlanner.formatTime(endMinutes)}',
      'totalEstimatedMinutes': totalEstimatedMinutes,
      'remainingMinutes': remainingMinutes,
      'originalCreatedAt': createdAt?.toIso8601String(),
      'days': publicDays,
      'stops': publicStops,
    };
  }

  static Future<Map<String, dynamic>> _publicItinerary(
    Map<String, dynamic> itinerary,
    String shareId,
    String ownerId,
  ) async {
    return <String, dynamic>{
      ...await _publicItineraryPayload(itinerary, shareId),
      'ownerId': ownerId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String _newShareId() {
    final random = Random.secure();
    return List.generate(
      9,
      (_) => _shareCharacters[random.nextInt(_shareCharacters.length)],
    ).join();
  }

  static Future<String> createShortShareLink(
    Map<String, dynamic> itinerary,
  ) async {
    final user = AppServices.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in before sharing an itinerary.');
    }
    if (!_isOwnedBy(itinerary, user.uid)) {
      throw Exception(
        'Only the itinerary owner can re-share this shared itinerary.',
      );
    }

    for (var attempt = 0; attempt < 6; attempt++) {
      final shareId = _newShareId();
      final reference = AppServices.db
          .collection(_shareCollection)
          .doc(shareId);
      try {
        final existing = await reference.get();
        if (existing.exists) continue;
        await reference.set(
          await _publicItinerary(itinerary, shareId, user.uid),
        );
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw Exception(
            'Short share links need the shared_itineraries Firestore rule to be published.',
          );
        }
        rethrow;
      }

      return Uri.parse(
        publicWebUrl,
      ).replace(queryParameters: {'share': shareId}).toString();
    }

    throw Exception('Unable to create a unique short share link. Try again.');
  }

  static Future<void> openShareDialog(
    BuildContext context,
    Map<String, dynamic> itinerary,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('Creating share link...'),
          ],
        ),
      ),
    );

    try {
      final link = await createShortShareLink(itinerary);
      if (!context.mounted) return;
      Navigator.pop(context);

      final title = '${itinerary['title'] ?? 'My Penang Itinerary'}';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Share Itinerary'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anyone with this link can view the itinerary, including its place images.',
                ),
                const SizedBox(height: 12),                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ExplorerColors.subtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ExplorerColors.border),
                  ),
                  child: SelectableText(
                    link,
                    maxLines: 2,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (dialogContext.mounted) {
                  showMessage(dialogContext, 'Short link copied.');
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Link'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await SharePlus.instance.share(
                  ShareParams(text: '$title\n$link'),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  static String? buildGoogleMapsMultiStopUrl(List<Map<String, dynamic>> stops) {
    if (stops.isEmpty) return null;
    if (stops.length == 1) {
      final stop = stops.first;
      final coords = _coordinatesFor(stop);
      final query = coords != null
          ? '${coords['latitude']},${coords['longitude']}'
          : Uri.encodeComponent('${stop['name'] ?? ''}, ${stop['formattedAddress'] ?? ''}');
      return 'https://www.google.com/maps/search/?api=1&query=$query';
    }

    String pointString(Map<String, dynamic> stop) {
      final coords = _coordinatesFor(stop);
      if (coords != null) {
        return '${coords['latitude']},${coords['longitude']}';
      }
      return Uri.encodeComponent('${stop['name'] ?? ''} ${stop['formattedAddress'] ?? stop['area'] ?? ''}'.trim());
    }

    final origin = pointString(stops.first);
    final destination = pointString(stops.last);
    final waypoints = stops.length > 2
        ? stops.sublist(1, stops.length - 1).map(pointString).join('|')
        : '';

    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination');
    if (waypoints.isNotEmpty) {
      buffer.write('&waypoints=$waypoints');
    }
    buffer.write('&travelmode=driving');
    return buffer.toString();
  }

  static Future<void> openMultiStopNavigation(
    BuildContext context,
    List<Map<String, dynamic>> stops,
  ) async {
    final url = buildGoogleMapsMultiStopUrl(stops);
    if (url == null) {
      showMessage(context, 'No stops available to navigate.', error: true);
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Unable to open Google Maps.', error: true);
      }
    }
  }

  static String formatItineraryText({
    required Map<String, dynamic> itinerary,
    required ItineraryScheduleResult schedule,
  }) {
    final title = '${itinerary['title'] ?? 'Cultural Day Trip'}';
    final area = '${itinerary['area'] ?? 'Malaysia'}';
    final pace = '${itinerary['travelPace'] ?? 'Balanced'}';
    final totalHours = (schedule.totalEstimatedMinutes / 60).toStringAsFixed(1);
    final stops = schedule.stops;

    final buffer = StringBuffer();
    buffer.writeln('🏛️ $title');
    buffer.writeln('📍 Location: $area');
    buffer.writeln('⏱️ Total Duration: $totalHours hours (${stops.length} stops)');
    buffer.writeln('🚶 Pace: $pace');
    buffer.writeln('----------------------------------------');
    buffer.writeln();

    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final name = '${stop['name'] ?? 'Stop ${i + 1}'}';
      final timeLabel = '${stop['suggestedTimeLabel'] ?? ''}'.trim();
      final category = '${stop['category'] ?? ''}';
      final duration = stop['durationMinutes'] ?? 60;
      final address = '${stop['formattedAddress'] ?? stop['area'] ?? ''}'.trim();
      final travel = (stop['travelMinutesBefore'] as num?)?.round() ?? 0;
      final task = stop['culturalTask'] is Map ? Map<String, dynamic>.from(stop['culturalTask'] as Map) : null;
      final taskTitle = task != null ? '${task['title'] ?? ''}' : '${stop['culturalTaskTitle'] ?? ''}'.trim();

      if (i > 0 && travel > 0) {
        buffer.writeln('  ↓ 🚗 Travel ~$travel min');
      }
      buffer.writeln('${i + 1}. $name ${timeLabel.isNotEmpty ? '($timeLabel)' : ''}');
      buffer.writeln('   Category: $category • Visit: $duration min');
      if (address.isNotEmpty) {
        buffer.writeln('   Address: $address');
      }
      if (taskTitle.isNotEmpty) {
        buffer.writeln('   🏆 Cultural Task: $taskTitle');
      }
      buffer.writeln();
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Created with MyHeritage Explorer');
    return buffer.toString();
  }

  static Future<void> exportAndShareItinerary(
    BuildContext context, {
    required Map<String, dynamic> itinerary,
    required ItineraryScheduleResult schedule,
  }) async {
    final text = formatItineraryText(itinerary: itinerary, schedule: schedule);
    final title = '${itinerary['title'] ?? 'My Itinerary'}';

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_download_outlined, color: ExplorerColors.navy, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Export "$title"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ExplorerColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: ExplorerColors.goldSoft,
                  child: Icon(Icons.copy_outlined, color: ExplorerColors.goldDark, size: 20),
                ),
                title: const Text('Copy Formatted Schedule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Copy clean timeline text with addresses & tasks to clipboard', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bottomContext);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    showMessage(context, 'Full itinerary schedule copied to clipboard!');
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: ExplorerColors.navySoft,
                  child: Icon(Icons.share_outlined, color: ExplorerColors.navy, size: 20),
                ),
                title: const Text('Share Text Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Share full text via WhatsApp, Telegram, Notes or Email', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bottomContext);
                  await SharePlus.instance.share(ShareParams(text: text));
                },
              ),
              if (schedule.stops.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.directions_outlined, color: Color(0xFF2E7D32), size: 20),
                  ),
                  title: const Text('Open Full Route in Google Maps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Multi-stop turn-by-turn navigation for all stops', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(bottomContext);
                    await openMultiStopNavigation(context, schedule.stops);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
