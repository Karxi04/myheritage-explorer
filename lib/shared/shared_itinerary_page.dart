import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_gate.dart';
import '../core/explorer_ui.dart';
import '../traveler/traveler_pages.dart';

class SharedItineraryPage extends StatelessWidget {
  const SharedItineraryPage({super.key, this.shareId, this.encodedItinerary})
    : assert(shareId != null || encodedItinerary != null);

  final String? shareId;
  final String? encodedItinerary;

  Map<String, dynamic>? _decodeLegacy() {
    final raw = encodedItinerary?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      var encoded = raw;
      while (encoded.length % 4 != 0) {
        encoded += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      if (data['v'] == 2 && data['s'] is List) {
        final stops = List<Map<String, dynamic>>.from(
          (data['s'] as List).map((item) {
            final stop = Map<String, dynamic>.from(item as Map);
            return {
              'name': '${stop['n'] ?? ''}',
              'imageUrl': '${stop['g'] ?? ''}',
              'description': '${stop['d'] ?? ''}',
              'formattedAddress': '${stop['f'] ?? ''}',
              'area': '${stop['a'] ?? ''}',
              'category': '${stop['c'] ?? ''}',
              'durationMinutes': stop['u'] ?? 60,
              'travelMinutesBefore': stop['w'] ?? 0,
              'rating': stop['r'] ?? 0,
              'reviewCount': stop['v'] ?? 0,
              'culturalTaskTitle': '${stop['x'] ?? ''}',
              'culturalTaskRewardPoints': stop['p'] ?? 0,
            };
          }),
        );
        return {
          'title': '${data['t'] ?? 'Shared Itinerary'}',
          'area': '${data['a'] ?? 'Penang'}',
          'budgetLevel': '${data['b'] ?? 'Medium'}',
          'travelPace': '${data['p'] ?? 'Balanced'}',
          'interests': List<String>.from(data['i'] ?? const []),
          'totalEstimatedMinutes': data['m'],
          'stops': stops,
        };
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadSharedItinerary(String id) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shared_itineraries')
        .doc(id)
        .get();
    return snapshot.data();
  }

  @override
  Widget build(BuildContext context) {
    if (shareId != null && shareId!.trim().isNotEmpty) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: _loadSharedItinerary(shareId!.trim()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _SharedError(
              title: 'Unable to open itinerary',
              message: snapshot.error.toString(),
            );
          }
          final data = snapshot.data;
          if (data == null || data['visibility'] != 'public') {
            return const _SharedError(
              title: 'Shared itinerary not found',
              message:
                  'The link may be invalid or the itinerary is no longer shared.',
            );
          }
          return _SharedItineraryContent(itinerary: data);
        },
      );
    }

    final legacy = _decodeLegacy();
    if (legacy == null) {
      return const _SharedError(
        title: 'Invalid itinerary link',
        message: 'The shared link is incomplete or no longer readable.',
      );
    }
    return _SharedItineraryContent(itinerary: legacy);
  }
}

class _SharedError extends StatelessWidget {
  const _SharedError({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Shared Itinerary')),
      body: ExplorerEmptyState(
        title: title,
        subtitle: message,
        icon: Icons.link_off_rounded,
      ),
    );
  }
}

class _SharedItineraryContent extends StatefulWidget {
  const _SharedItineraryContent({required this.itinerary});
  final Map<String, dynamic> itinerary;

  @override
  State<_SharedItineraryContent> createState() => _SharedItineraryContentState();
}

class _SharedItineraryContentState extends State<_SharedItineraryContent> {
  bool _isSaving = false;
  bool _isSaved = false;
  String? _savedItineraryId;

  List<Map<String, dynamic>> _rawStopsFrom(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _rawSharedDays() {
    final rawDays = widget.itinerary['days'];
    if (rawDays is! List) return const <Map<String, dynamic>>[];
    return rawDays
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((day) => _rawStopsFrom(day['stops']).isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _displayStops() {
    final days = _rawSharedDays();
    if (days.isNotEmpty) {
      return days.expand((day) => _rawStopsFrom(day['stops'])).toList();
    }
    return _rawStopsFrom(widget.itinerary['stops']);
  }

  Future<List<Map<String, dynamic>>> _cloneDaysForAccount() async {
    final sharedDays = _rawSharedDays();
    final fallbackDate = widget.itinerary['startDate'] ??
        widget.itinerary['targetDate'] ??
        DateTime.now().toIso8601String();
    final sourceDays = sharedDays.isNotEmpty
        ? sharedDays
        : [
            {
              'dayNumber': 1,
              'date': fallbackDate,
              'dateLabel': widget.itinerary['dateLabel'] ?? 'Day 1',
              'weather': const <String, dynamic>{},
              'stops': _rawStopsFrom(widget.itinerary['stops']),
            }
          ];
    final availableHours =
        (widget.itinerary['availableHours'] as num?)?.toDouble() ?? 4;
    final pace = '${widget.itinerary['travelPace'] ?? 'Balanced'}';
    final preferredStart =
        (widget.itinerary['suggestedStartMinutes'] as num?)?.round();
    final clonedDays = <Map<String, dynamic>>[];

    for (var index = 0; index < sourceDays.length; index++) {
      final day = sourceDays[index];
      final dayStops = _rawStopsFrom(day['stops']);
      final schedule = ItinerarySchedulePlanner.plan(
        stops: dayStops,
        pace: pace,
        availableHours:
            (day['availableHours'] as num?)?.toDouble() ?? availableHours,
        preferredStartMinutes:
            (day['suggestedStartMinutes'] as num?)?.round() ?? preferredStart,
      );
      final resolvedStops = await Future.wait(
        schedule.stops.asMap().entries.map((entry) async {
          final stop = await ItineraryImageResolver.resolveStop(
            Map<String, dynamic>.from(entry.value),
          );
          return {
            ...stop,
            'sequence': entry.key + 1,
            'dayNumber': (day['dayNumber'] as num?)?.round() ?? index + 1,
          };
        }),
      );
      final dayBudget = ItineraryBudgetEstimator.estimateDay(resolvedStops);
      clonedDays.add({
        ...day,
        'dayNumber': (day['dayNumber'] as num?)?.round() ?? index + 1,
        'stops': resolvedStops,
        'suggestedStartMinutes': schedule.startMinutes,
        'suggestedEndMinutes': schedule.endMinutes,
        'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
        'remainingMinutes': schedule.remainingMinutes,
        'budget': dayBudget.dayBudget,
        'budgetLevel': dayBudget.budgetLevel,
      });
    }

    return clonedDays;
  }

  void _copyShareCode(BuildContext context) {
    final shareId = '${widget.itinerary['shareId'] ?? ''}'.trim();
    if (shareId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: shareId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share code copied: $shareId\nEnter this code in the mobile app (My Itineraries > 🔗)'),
        backgroundColor: ExplorerColors.navy,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: ExplorerColors.gold,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showAppPromptDialog(BuildContext context, String shareId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: ExplorerColors.navy, size: 24),
            SizedBox(width: 8),
            Text('Open in Mobile App', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, color: ExplorerColors.navy, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If the MyHeritage Explorer app is installed on your Android device, it will launch automatically.',
                          style: TextStyle(fontSize: 12, color: ExplorerColors.navy, fontWeight: FontWeight.w600, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'DON\'T HAVE THE APP YET?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ExplorerColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• You can view this full itinerary directly here in your browser.\n'
                  '• To create, save, or customize itineraries and track cultural tasks, install the MyHeritage Explorer Android app on your device.',
                  style: TextStyle(fontSize: 12, color: ExplorerColors.navy, height: 1.45),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SHARE CODE FOR IN-APP IMPORT:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ExplorerColors.goldDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ExplorerColors.goldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ExplorerColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SelectableText(
                        shareId,
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ExplorerColors.goldDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: shareId));
                          Navigator.pop(dialogContext);
                          _copyShareCode(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'HOW TO IMPORT IN THE APP:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: ExplorerColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. Open MyHeritage Explorer on your Android device\n'
                  '2. Go to the "My Itineraries" tab\n'
                  '3. Tap the "🔗" (Import) icon in the top app bar\n'
                  '4. Paste the share code to clone this full itinerary into your account',
                  style: TextStyle(fontSize: 11.5, color: ExplorerColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ExplorerColors.navy),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uri = Uri(
                scheme: 'myheritage',
                host: 'shared-itinerary',
                queryParameters: {'share': shareId},
              );
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Try Launch App'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInstalledApp() async {
    final shareId = '${widget.itinerary['shareId'] ?? ''}'.trim();
    if (shareId.isEmpty) return;
    final uri = Uri(
      scheme: 'myheritage',
      host: 'shared-itinerary',
      queryParameters: {'share': shareId},
    );
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        final intentUri = Uri.parse(
          'intent://shared-itinerary?share=$shareId#Intent;scheme=myheritage;package=com.example.myheritage_explorer;end',
        );
        launched = await launchUrl(intentUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (mounted) {
      _showAppPromptDialog(context, shareId);
    }
  }

  Widget _previewStop(
    Map<String, dynamic>? stop, {
    double? width,
    double height = 96,
  }) {
    final fallback = Container(
      width: width,
      height: height,
      color: ExplorerColors.navySoft,
      child: const Icon(
        Icons.photo_outlined,
        color: ExplorerColors.navy,
        size: 30,
      ),
    );
    if (stop == null) return fallback;
    return ItineraryPlaceImage(
      stop: stop,
      width: width,
      height: height,
    );
  }

  Future<void> _saveToAccount(
    BuildContext context,
    ItineraryScheduleResult schedule,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isSaving) return;
    if (_isSaved || _savedItineraryId != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This itinerary has already been saved.'),
          backgroundColor: ExplorerColors.navy,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bookmark_add_outlined, color: ExplorerColors.navy),
              SizedBox(width: 8),
              Text('Save to My Itineraries'),
            ],
          ),
          content: const Text(
            'Sign in to MyHeritage Explorer to save this itinerary to your account, track cultural tasks, and access offline routes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In / Register'),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final clonedDays = await _cloneDaysForAccount();
      final stops = clonedDays
          .expand((day) => _rawStopsFrom(day['stops']))
          .toList();
      final tripBudget = ItineraryBudgetEstimator.estimateTrip(
        clonedDays,
        fallbackStops: stops,
      );
      final totalEstimatedMinutes = clonedDays.fold<int>(
        0,
        (total, day) =>
            total + ((day['totalEstimatedMinutes'] as num?)?.round() ?? 0),
      );
      final remainingMinutes = clonedDays.fold<int>(
        0,
        (total, day) =>
            total + ((day['remainingMinutes'] as num?)?.round() ?? 0),
      );
      final clonedStartMinutes =
          (clonedDays.isEmpty
                  ? null
                  : (clonedDays.first['suggestedStartMinutes'] as num?)
                      ?.round()) ??
          schedule.startMinutes;
      final clonedEndMinutes = clonedDays.fold<int>(
        clonedStartMinutes,
        (latest, day) => max(
          latest,
          (day['suggestedEndMinutes'] as num?)?.round() ?? latest,
        ),
      );
      final docRef = await FirebaseFirestore.instance
          .collection('itineraries')
          .add({
            'userId': user.uid,
            'ownerId': user.uid,
            'title':
                '${widget.itinerary['title'] ?? 'Shared Itinerary'} (Saved Copy)',
            'area': widget.itinerary['area'] ?? 'Penang',
            'selectedArea': widget.itinerary['selectedArea'] ?? widget.itinerary['area'] ?? '',
            'stateId': widget.itinerary['stateId'] ?? '',
            'stateName': widget.itinerary['stateName'] ?? '',
            'availableHours':
                (widget.itinerary['availableHours'] as num?)?.toDouble() ?? 4,
            'dailyHours':
                (widget.itinerary['availableHours'] as num?)?.toDouble() ?? 4,
            'dayCount': clonedDays.length,
            'startDate': widget.itinerary['startDate'] ??
                (clonedDays.isNotEmpty ? clonedDays.first['date'] : null) ??
                widget.itinerary['targetDate'] ??
                DateTime.now().toIso8601String(),
            'endDate': widget.itinerary['endDate'] ??
                (clonedDays.isNotEmpty ? clonedDays.last['date'] : null) ??
                widget.itinerary['startDate'] ??
                widget.itinerary['targetDate'] ??
                DateTime.now().toIso8601String(),
            'budget': tripBudget.tripBudget,
            'budgetLevel': tripBudget.budgetLevel,
            'budgetPreference': widget.itinerary['budgetLevel'] ?? 'Medium',
            'interests': List<String>.from(
              widget.itinerary['interests'] ?? const [],
            ),
            'travelPace': widget.itinerary['travelPace'] ?? 'Balanced',
            'pace': widget.itinerary['travelPace'] ?? 'Balanced',
            'placeSource': 'Cloned from shared itinerary link',
            'shareSourceId': widget.itinerary['shareId'],
            'clonedFromShareId': widget.itinerary['shareId'],
            'clonedFromOwnerId': widget.itinerary['ownerId'],
            'suggestedStartMinutes': clonedStartMinutes,
            'suggestedEndMinutes': clonedEndMinutes,
            'totalEstimatedMinutes': totalEstimatedMinutes,
            'remainingMinutes': remainingMinutes,
            'days': clonedDays,
            'stops': stops,
            'status': 'saved',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _isSaved = true;
        _savedItineraryId = docRef.id;
      });

      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Itinerary saved to My Itineraries!'),
            backgroundColor: ExplorerColors.navy,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: ExplorerColors.gold,
              onPressed: () {
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => ItineraryDetailPage(itineraryId: docRef.id),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save itinerary: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _displayStops();
    final schedule = ItinerarySchedulePlanner.plan(
      stops: stops,
      pace: '${widget.itinerary['travelPace'] ?? 'Balanced'}',
      availableHours:
          (widget.itinerary['availableHours'] as num?)?.toDouble() ?? 4,
      preferredStartMinutes:
          (widget.itinerary['suggestedStartMinutes'] as num?)?.round(),
    );
    final scheduledStops = schedule.stops;
    final totalMinutes = schedule.totalEstimatedMinutes;
    final coverStop = scheduledStops.isEmpty ? null : scheduledStops.first;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('MyHeritage Explorer'),
        actions: [
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isSaved ? ExplorerColors.gold : ExplorerColors.goldSoft,
                  foregroundColor:
                      _isSaved ? Colors.white : ExplorerColors.goldDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    _isSaving ? null : () => _saveToAccount(context, schedule),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isSaved
                            ? Icons.bookmark_added
                            : Icons.bookmark_add_outlined,
                        size: 16,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isSaved
                          ? 'Saved'
                          : 'Save',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else if ('${widget.itinerary['shareId'] ?? ''}'.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ExplorerColors.navy,
                  side: const BorderSide(color: ExplorerColors.navy),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _copyShareCode(context),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(
                  'Code: ${widget.itinerary['shareId']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
            children: [
              if (kIsWeb)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: ExplorerColors.goldSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ExplorerColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: ExplorerColors.goldDark, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Viewing shared cultural itinerary. Tap "Open in App" or copy share code "${widget.itinerary['shareId'] ?? ''}" to clone it directly into your MyHeritage Explorer mobile app (My Itineraries > 🔗).',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ExplorerColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if ('${widget.itinerary['shareId'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            backgroundColor: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: () => _copyShareCode(context),
                          icon: const Icon(Icons.copy_rounded, size: 14, color: ExplorerColors.navy),
                          label: const Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ExplorerColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ExplorerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: _previewStop(coverStop, height: 180),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHARED CULTURAL ITINERARY',
                            style: TextStyle(
                              color: ExplorerColors.goldDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.itinerary['title'] ?? 'Shared Itinerary'}',
                            style: const TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.itinerary['area'] ?? 'Penang'} • '
                            '${scheduledStops.length} stops • '
                            '${(totalMinutes / 60).toStringAsFixed(1)} hours',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (kIsWeb) ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: ExplorerColors.navy,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _openInstalledApp,
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Open in App',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                                if ('${widget.itinerary['shareId'] ?? ''}'.trim().isNotEmpty)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ExplorerColors.navy,
                                      side: const BorderSide(color: ExplorerColors.navy),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _copyShareCode(context),
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    label: const Text(
                                      'Copy Share Code',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ),
                              ] else ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: ExplorerColors.navy,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _isSaving
                                      ? null
                                      : () => _saveToAccount(context, schedule),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.bookmark_add_outlined, size: 18),
                                  label: Text(
                                    _isSaving ? 'Saving...' : 'Save to My Itineraries',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ItineraryTimelineSummary(schedule: schedule),
              const SizedBox(height: 18),
              const ExplorerSectionTitle(
                'Itinerary Timeline & Stops',
                subtitle: 'Full chronological schedule with travel times and cultural tasks.',
              ),
              const SizedBox(height: 10),
              ...scheduledStops.asMap().entries.map((entry) {
                final stop = entry.value;
                final travel =
                    (stop['travelMinutesBefore'] as num?)?.round() ?? 0;
                final duration =
                    (stop['durationMinutes'] as num?)?.round() ?? 60;
                final rating = (stop['score'] as num?)?.toDouble() ??
                    (stop['rating'] as num?)?.toDouble() ?? 0;
                final reviewCount =
                    (stop['inAppReviewCount'] as num?)?.round() ??
                    (stop['reviewCount'] as num?)?.round() ?? 0;
                final timeLabel = '${stop['suggestedTimeLabel'] ?? ''}'.trim();
                final formattedAddress =
                    '${stop['formattedAddress'] ?? stop['area'] ?? ''}'.trim();
                final scheduleNotes = List<String>.from(
                  stop['scheduleNotes'] ?? const <String>[],
                );
                final task = stop['culturalTask'] is Map
                    ? Map<String, dynamic>.from(stop['culturalTask'] as Map)
                    : null;
                final taskTitle = '${task?['title'] ?? stop['culturalTaskTitle'] ?? ''}'.trim();
                final taskPoints = task?['rewardPoints'] ?? stop['culturalTaskRewardPoints'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: _previewStop(stop, height: 180),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: ExplorerColors.goldSoft,
                                    foregroundColor: ExplorerColors.goldDark,
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${stop['name'] ?? ''}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (timeLabel.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.schedule_outlined,
                                                size: 14,
                                                color: ExplorerColors.goldDark,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                timeLabel,
                                                style: const TextStyle(
                                                  color: ExplorerColors.goldDark,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${stop['category'] ?? 'Place'} • $duration min duration'
                                '${travel > 0 ? ' • $travel min travel' : ''}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (formattedAddress.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: ExplorerColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        formattedAddress,
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 11,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if ('${stop['description'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${stop['description']}',
                                  style: const TextStyle(
                                    color: ExplorerColors.text,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (reviewCount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: ExplorerColors.goldDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (taskTitle.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: ExplorerColors.goldSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_outlined,
                                        size: 16,
                                        color: ExplorerColors.goldDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$taskTitle${taskPoints != null ? ' (+$taskPoints pts)' : ''}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (scheduleNotes.isNotEmpty) ...[
                                const SizedBox(height: 9),
                                ScheduleNoteList(notes: scheduleNotes),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: ExplorerColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => _saveToAccount(context, schedule),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text(
                    'Save Itinerary to Account',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
