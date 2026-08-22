import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      final stops = schedule.stops;
      final docRef = await FirebaseFirestore.instance
          .collection('itineraries')
          .add({
            'userId': user.uid,
            'title': '${widget.itinerary['title'] ?? 'Shared Itinerary'} (Saved)',
            'area': widget.itinerary['area'] ?? 'Penang',
            'availableHours':
                (widget.itinerary['availableHours'] as num?)?.toDouble() ?? 4,
            'budget':
                (widget.itinerary['budget'] as num?)?.toDouble() ?? 100,
            'budgetLevel': widget.itinerary['budgetLevel'] ?? 'Medium',
            'interests': List<String>.from(
              widget.itinerary['interests'] ?? const [],
            ),
            'travelPace': widget.itinerary['travelPace'] ?? 'Balanced',
            'placeSource': 'Saved from shared link',
            'suggestedStartMinutes': schedule.startMinutes,
            'suggestedEndMinutes': schedule.endMinutes,
            'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
            'remainingMinutes': schedule.remainingMinutes,
            'stops': stops,
            'status': 'saved',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Itinerary saved to My Itineraries!'),
            backgroundColor: ExplorerColors.navy,
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
    final stops = List<Map<String, dynamic>>.from(
      (widget.itinerary['stops'] ?? const []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.goldSoft,
                foregroundColor: ExplorerColors.goldDark,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSaving ? null : () => _saveToAccount(context, schedule),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined, size: 16),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ExplorerColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSaving ? null : () => _saveToAccount(context, schedule),
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
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                  );
                },
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text(
                  'Explore App',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 80),
            children: [
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
                              if (scheduledStops.isNotEmpty)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => ItineraryShareHelper.openMultiStopNavigation(
                                    context,
                                    scheduledStops,
                                  ),
                                  icon: const Icon(Icons.directions_outlined, size: 18),
                                  label: const Text(
                                    'Navigate Route',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => ItineraryShareHelper.exportAndShareItinerary(
                                  context,
                                  itinerary: widget.itinerary,
                                  schedule: schedule,
                                ),
                                icon: const Icon(Icons.file_download_outlined, size: 18),
                                label: const Text('Export / Copy'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AuthGate()),
                                  );
                                },
                                icon: const Icon(Icons.explore_outlined, size: 18),
                                label: const Text('Explore App'),
                              ),
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
          ),
        ),
      ),
    );
  }
}
