import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/explorer_ui.dart';

class SharedItineraryPage extends StatelessWidget {
  const SharedItineraryPage({
    super.key,
    this.shareId,
    this.encodedItinerary,
  }) : assert(shareId != null || encodedItinerary != null);

  final String? shareId;
  final String? encodedItinerary;

  Map<String, dynamic>? _decodeLegacy() {
    final raw = encodedItinerary?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      var encoded = raw;
      while (encoded.length % 4 != 0) encoded += '=';
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
              'trustLabel': '${stop['t'] ?? ''}',
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

  @override
  Widget build(BuildContext context) {
    if (shareId != null && shareId!.trim().isNotEmpty) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('shared_itineraries')
            .doc(shareId!.trim())
            .get(),
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
          final data = snapshot.data?.data();
          if (data == null || data['visibility'] != 'public') {
            return const _SharedError(
              title: 'Shared itinerary not found',
              message: 'The link may be invalid or the itinerary is no longer shared.',
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

class _SharedItineraryContent extends StatelessWidget {
  const _SharedItineraryContent({required this.itinerary});
  final Map<String, dynamic> itinerary;

  Widget _preview(String imageUrl, {double? width, double height = 96}) {
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
    if (imageUrl.trim().isEmpty) return fallback;
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = List<Map<String, dynamic>>.from(
      (itinerary['stops'] ?? const []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
    final totalMinutes =
        (itinerary['totalEstimatedMinutes'] as num?)?.round() ??
            stops.fold<int>(
              0,
              (total, stop) =>
                  total +
                  ((stop['durationMinutes'] as num?)?.round() ?? 60) +
                  ((stop['travelMinutesBefore'] as num?)?.round() ?? 0),
            );
    final cover = stops.isEmpty ? '' : '${stops.first['imageUrl'] ?? ''}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('MyHeritage Explorer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
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
                        height: 220,
                        child: _preview(cover, height: 220),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHARED PENANG ITINERARY',
                            style: TextStyle(
                              color: ExplorerColors.goldDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${itinerary['title'] ?? 'Shared Itinerary'}',
                            style: const TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${itinerary['area'] ?? 'Penang'} • '
                            '${stops.length} stops • '
                            '${(totalMinutes / 60).toStringAsFixed(1)} hours',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const ExplorerSectionTitle(
                'Itinerary Route',
                subtitle: 'Every saved place includes an image or map preview.',
              ),
              const SizedBox(height: 10),
              ...stops.asMap().entries.map((entry) {
                final stop = entry.value;
                final imageUrl = '${stop['imageUrl'] ?? ''}';
                final travel =
                    (stop['travelMinutesBefore'] as num?)?.round() ?? 0;
                final duration =
                    (stop['durationMinutes'] as num?)?.round() ?? 60;
                final rating =
                    (stop['rating'] as num?)?.toDouble() ?? 0;
                final reviewCount =
                    (stop['reviewCount'] as num?)?.round() ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: _preview(imageUrl, height: 180),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${stop['category'] ?? 'Place'} • '
                                      '$duration minutes'
                                      '${travel > 0 ? ' • $travel minutes travel' : ''}',
                                      style: const TextStyle(
                                        color: ExplorerColors.goldDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${stop['formattedAddress'] ?? stop['area'] ?? ''}',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
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
                                          Text(
                                            ' ${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                                            style: const TextStyle(
                                              color: ExplorerColors.navy,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
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
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
