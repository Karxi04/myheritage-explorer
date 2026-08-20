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
    final stops = List<Map<String, dynamic>>.from(
      (itinerary['stops'] ?? const []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
    final availableHours = _availableHoursFor(itinerary);
    final schedule = ItinerarySchedulePlanner.plan(
      stops: stops,
      pace: '${itinerary['travelPace'] ?? 'Balanced'}',
      availableHours: availableHours,
      preferredStartMinutes: (itinerary['suggestedStartMinutes'] as num?)
          ?.round(),
    );

    return <String, dynamic>{
      'shareId': shareId,
      'visibility': 'public',
      'title': _shortText(itinerary['title'] ?? 'Shared Penang Itinerary', 120),
      'area': _shortText(itinerary['area'] ?? 'Penang', 80),
      'availableHours': availableHours,
      'budgetLevel': _shortText(itinerary['budgetLevel'], 30),
      'travelPace': _shortText(itinerary['travelPace'], 30),
      'interests': List<String>.from(
        itinerary['interests'] ?? const <String>[],
      ),
      'suggestedStartMinutes': schedule.startMinutes,
      'suggestedEndMinutes': schedule.endMinutes,
      'timelineLabel':
          '${ItinerarySchedulePlanner.formatTime(schedule.startMinutes)} - '
          '${ItinerarySchedulePlanner.formatTime(schedule.endMinutes)}',
      'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
      'remainingMinutes': schedule.remainingMinutes,
      'originalCreatedAt': createdAt?.toIso8601String(),
      'stops': await Future.wait(schedule.stops.map(_publicStop)),
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
                const SizedBox(height: 12),
                Container(
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
}
