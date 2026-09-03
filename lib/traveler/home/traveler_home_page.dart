part of '../traveler_pages.dart';

class TravelerHomePage extends StatefulWidget {
  const TravelerHomePage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<TravelerHomePage> createState() => _TravelerHomePageState();
}

class _TravelerHomePageState extends State<TravelerHomePage> {
  late Future<List<Map<String, dynamic>>> recommendationsFuture;
  late String recommendationProfileKey;

  Map<String, dynamic> get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _reloadRecommendations();
  }

  @override
  void didUpdateWidget(covariant TravelerHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _profileInterests().join('|');
    if (nextKey != recommendationProfileKey) {
      _reloadRecommendations();
    }
  }

  void _reloadRecommendations() {
    final interests = _profileInterests();
    recommendationProfileKey = interests.join('|');
    recommendationsFuture = _loadRecommendedPlaces(interests);
  }

  Future<void> _refreshHome() async {
    setState(_reloadRecommendations);
    await recommendationsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    final displayName =
        '${profile['displayName'] ?? AppServices.auth.currentUser?.displayName ?? 'Traveler'}';
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyPlannerPage()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: ExplorerColors.goldSoft,
              foregroundColor: ExplorerColors.goldDark,
              child: Text(
                firstName.isEmpty ? 'T' : firstName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _journeyHero(context, firstName),
            const SizedBox(height: 22),
            ExplorerSectionTitle(
              'Current Itinerary',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyItinerariesPage()),
                ),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('itineraries')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ExplorerCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) =>
                        (asDate(b.data()['updatedAt']) ??
                                asDate(b.data()['createdAt']) ??
                                DateTime(2000))
                            .compareTo(
                              asDate(a.data()['updatedAt']) ??
                                  asDate(a.data()['createdAt']) ??
                                  DateTime(2000),
                            ),
                  );
                if (docs.isEmpty) {
                  return ExplorerCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DailyPlannerPage(),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.route_outlined,
                          color: ExplorerColors.navy,
                          size: 34,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'No itinerary yet. Tap here to generate your first heritage journey.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                }
                return _itineraryCard(
                  context,
                  docs.first.id,
                  docs.first.data(),
                );
              },
            ),
            const SizedBox(height: 24),
            _interestRecommendationsSection(context),
            const SizedBox(height: 24),
            _travelToolsSection(context),
            const SizedBox(height: 24),
            const ExplorerSectionTitle('Active Task'),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('task_submissions')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ExplorerCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                        .compareTo(
                          asDate(a.data()['createdAt']) ?? DateTime(2000),
                        ),
                  );
                if (docs.isEmpty) {
                  return ExplorerCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CulturalTasksPage(),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: ExplorerColors.navy,
                          size: 32,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Explore cultural tasks and earn impact points.',
                            style: TextStyle(color: ExplorerColors.muted),
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                }
                return _taskCard(context, docs.first.data());
              },
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle('Updates for You'),
            const SizedBox(height: 10),
            _updateCard(
              icon: Icons.confirmation_number_outlined,
              iconBackground: ExplorerColors.goldSoft,
              iconColor: ExplorerColors.goldDark,
              title: 'Nearby voucher available',
              subtitle: 'Explore active rewards from verified local vendors.',
              action: 'Claim',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RewardsPage()),
              ),
            ),
            const SizedBox(height: 9),
            _updateCard(
              icon: Icons.cloud_outlined,
              iconBackground: ExplorerColors.navySoft,
              iconColor: ExplorerColors.navy,
              title: 'Weather reminder',
              subtitle: 'Review the latest forecast before outdoor activities.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeatherReminderPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _journeyHero(BuildContext context, String firstName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final points = profile['points'] ?? profile['localImpactScore'] ?? 0;
    final rank = '${profile['rank'] ?? 'Bronze'}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ExplorerColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: Icon(
              Icons.account_balance_outlined,
              size: 136,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const SizedBox(
                width: 280,
                child: Text(
                  'Build a route around the places and culture you care about.',
                  style: TextStyle(
                    color: Color(0xFFD7E2F2),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 9,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ExplorerColors.gold,
                      foregroundColor: ExplorerColors.navyDark,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DailyPlannerPage(),
                      ),
                    ),
                    icon: const Icon(Icons.route_outlined, size: 18),
                    label: const Text('Plan a Trip'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .55),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyItinerariesPage(),
                      ),
                    ),
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    label: const Text('My Trips'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: .14)),
              const SizedBox(height: 13),
              Row(
                children: [
                  _heroMetric(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Explorer rank',
                    value: rank,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: Colors.white.withValues(alpha: .18),
                  ),
                  _heroMetric(
                    icon: Icons.stars_outlined,
                    label: 'Impact points',
                    value: '$points pts',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: ExplorerColors.gold, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFB8C8DD), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _travelToolsSection(BuildContext context) {
    final tools = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: 'Cultural Tasks',
        icon: Icons.workspace_premium_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CulturalTasksPage()),
        ),
      ),
      (
        label: 'Voucher Wallet',
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoucherWalletPage()),
        ),
      ),
      (
        label: 'Safety Centre',
        icon: Icons.health_and_safety_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SafetyPage()),
        ),
      ),
      (
        label: 'Ask Guide',
        icon: Icons.smart_toy_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatbotPage()),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExplorerSectionTitle(
          'Travel Tools',
          subtitle: 'Your most-used trip utilities.',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: columns == 4 ? 2.35 : 2.2,
              ),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return ExplorerCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  onTap: tool.onTap,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? ExplorerColors.goldSoft
                              : ExplorerColors.navySoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          tool.icon,
                          size: 19,
                          color: index == 0
                              ? ExplorerColors.goldDark
                              : ExplorerColors.navy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tool.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExplorerColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _interestRecommendationsSection(BuildContext context) {
    final interests = _profileInterests();
    final title = interests.isEmpty
        ? 'Popular Across Malaysia'
        : 'Picked for You';
    final subtitle = interests.isEmpty
        ? 'Verified places travelers often explore.'
        : 'Based on your ${interests.take(3).join(', ')} interests.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExplorerSectionTitle(
          title,
          subtitle: subtitle,
          trailing: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyPlannerPage()),
            ),
            child: const Text('Plan'),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: recommendationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: 228,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      const _RecommendationLoadingCard(),
                ),
              );
            }

            final places = snapshot.data ?? const <Map<String, dynamic>>[];
            if (places.isEmpty) {
              return ExplorerCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.travel_explore_outlined,
                      color: ExplorerColors.navy,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add travel interests in your profile to see matched places here.',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TravelerProfilePage(profile: profile),
                        ),
                      ),
                      child: const Text('Profile'),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 228,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final place = places[index];
                  return _recommendationCard(context, place);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecommendedPlaces(
    List<String> interests,
  ) async {
    final preferred = _interestLabels(interests);
    final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    if (preferred.isNotEmpty) {
      try {
        final targeted = await AppServices.db
            .collection('vendors')
            .where('status', isEqualTo: 'active')
            .where('vendorStatus', isEqualTo: 'verified')
            .where(
              'plannerCategories',
              arrayContainsAny: preferred.take(10).toList(),
            )
            .limit(60)
            .get();
        for (final doc in targeted.docs) {
          docs[doc.id] = doc;
        }
      } catch (_) {
        // Some projects may not have the composite array index yet. The
        // broader verified-vendor query below keeps the homepage usable.
      }
    }

    final fallback = await AppServices.db
        .collection('vendors')
        .where('status', isEqualTo: 'active')
        .where('vendorStatus', isEqualTo: 'verified')
        .limit(320)
        .get();
    for (final doc in fallback.docs) {
      docs[doc.id] = doc;
    }

    final places =
        docs.values
            .map((doc) => _placeFromVendor(doc.id, doc.data(), preferred))
            .where((place) => place['name'].toString().trim().isNotEmpty)
            .toList()
          ..sort(
            (a, b) => _recommendationScore(
              b,
              preferred,
            ).compareTo(_recommendationScore(a, preferred)),
          );

    if (preferred.isEmpty) return places.take(6).toList();

    final selected = <Map<String, dynamic>>[];
    final usedIds = <String>{};
    for (final interest in preferred) {
      final match = places
          .where((place) {
            final id = '${place['placeId']}';
            return !usedIds.contains(id) &&
                _placeMatchesInterest(place, interest);
          })
          .cast<Map<String, dynamic>?>()
          .firstWhere((place) => place != null, orElse: () => null);
      if (match == null) continue;
      selected.add(match);
      usedIds.add('${match['placeId']}');
      if (selected.length >= 6) return selected;
    }

    for (final place in places) {
      final id = '${place['placeId']}';
      if (usedIds.contains(id)) continue;
      selected.add(place);
      usedIds.add(id);
      if (selected.length >= 6) break;
    }
    return selected;
  }

  List<String> _profileInterests() {
    return List<String>.from(profile['travelInterests'] ?? const <String>[])
        .map((interest) => interest.trim())
        .where((interest) => interest.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _interestLabels(List<String> interests) {
    const knownLabels = {
      'heritage': 'Heritage',
      'history': 'Heritage',
      'culture': 'Culture',
      'cultural': 'Culture',
      'food': 'Food',
      'cafe': 'Food',
      'local food': 'Food',
      'nature': 'Nature',
      'outdoor': 'Nature',
      'art': 'Art',
      'gallery': 'Art',
      'craft': 'Art',
      'local business': 'Local Business',
      'business': 'Local Business',
      'market': 'Local Business',
      'shopping': 'Local Business',
    };

    final labels = <String>{};
    for (final interest in interests) {
      final normalized = _normalizeText(interest);
      labels.add(knownLabels[normalized] ?? interest.trim());
    }
    return labels.toList();
  }

  Map<String, dynamic> _placeFromVendor(
    String id,
    Map<String, dynamic> data,
    List<String> interests,
  ) {
    final location = _locationMap(data);
    final name = '${data['businessName'] ?? data['displayName'] ?? ''}'.trim();
    final categories = _vendorCategories(data);
    final category = categories.firstWhere(
      (item) => item != 'Local Business',
      orElse: () => '${data['businessCategory'] ?? 'Local Business'}',
    );
    final address =
        '${data['formattedAddress'] ?? data['shopLocation'] ?? data['address'] ?? ''}';
    final area =
        '${data['areaName'] ?? data['area'] ?? data['city'] ?? data['state'] ?? ''}';
    final imageUrl = '${data['imageUrl'] ?? ''}'.trim();
    final mapPreview = location == null
        ? ''
        : ItineraryImageResolver.staticMapPreview(
            latitude: location['latitude']!,
            longitude: location['longitude']!,
          );
    final imageCandidates = <String>[
      ..._stringList(data['imageCandidates']),
      if (imageUrl.isNotEmpty) imageUrl,
    ];
    final place = {
      'placeId': 'vendor_$id',
      'vendorId': id,
      'source': 'registered_vendor',
      'name': name,
      'businessCategory': '${data['businessCategory'] ?? category}',
      'plannerCategories': categories,
      'category': category,
      'description':
          '${data['description'] ?? data['businessDescription'] ?? ''}',
      'formattedAddress': address.isNotEmpty ? address : area,
      'area': area,
      'state': '${data['state'] ?? ''}',
      'tags': <String>{...categories, ..._stringList(data['tags'])}.toList(),
      'durationMinutes': (data['durationMinutes'] as num?)?.round() ?? 60,
      'budgetLevel': '${data['budgetLevel'] ?? 'Medium'}',
      'score':
          ((data['score'] as num?) ??
                  (data['rating'] as num?) ??
                  (data['averageRating'] as num?) ??
                  0)
              .toDouble(),
      'rating': ((data['rating'] as num?) ?? (data['score'] as num?) ?? 0)
          .toDouble(),
      'inAppReviewCount':
          ((data['inAppReviewCount'] as num?) ??
                  (data['reviewCount'] as num?) ??
                  0)
              .round(),
      'openingHours': '${data['openingHours'] ?? data['businessHours'] ?? ''}'
          .trim(),
      'phone': '${data['phone'] ?? data['contactNumber'] ?? ''}'.trim(),
      'website': '${data['website'] ?? data['websiteUrl'] ?? ''}'.trim(),
      'email': '${data['email'] ?? ''}'.trim(),
      'mapUrl': '${data['mapUrl'] ?? ''}'.trim(),
      'imageUrl': imageUrl,
      'fallbackImageUrl': mapPreview,
      'mapPreviewUrl': mapPreview,
      'imageCandidates': imageCandidates,
      'imageType': imageUrl.isNotEmpty
          ? '${data['imageType'] ?? 'vendor_uploaded_photo'}'
          : 'pending_resolution',
      ...?location == null
          ? null
          : {
              'location': location,
              'latitude': location['latitude'],
              'longitude': location['longitude'],
            },
    };
    place['suggestionReason'] = _suggestionReason(place, interests);
    return place;
  }

  List<String> _vendorCategories(Map<String, dynamic> data) {
    final categories = <String>{
      ..._stringList(data['plannerCategories']),
      '${data['businessCategory'] ?? ''}',
      '${data['category'] ?? ''}',
    }.map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    if (categories.isEmpty) return ['Local Business'];
    return categories.toList();
  }

  Map<String, double>? _locationMap(Map<String, dynamic> data) {
    final raw = data['location'];
    if (raw is GeoPoint) {
      return {'latitude': raw.latitude, 'longitude': raw.longitude};
    }
    if (raw is Map) {
      final lat = raw['latitude'] ?? raw['lat'];
      final lng = raw['longitude'] ?? raw['lng'] ?? raw['lon'];
      if (lat is num && lng is num) {
        return {'latitude': lat.toDouble(), 'longitude': lng.toDouble()};
      }
    }
    final lat = data['latitude'] ?? data['lat'];
    final lng = data['longitude'] ?? data['lng'] ?? data['lon'];
    if (lat is num && lng is num) {
      return {'latitude': lat.toDouble(), 'longitude': lng.toDouble()};
    }
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? const [] : [text];
  }

  String _normalizeText(Object? value) {
    return '$value'
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _placeMatchesInterest(Map<String, dynamic> place, String interest) {
    final normalizedInterest = _normalizeText(interest);
    if (normalizedInterest.isEmpty) return false;
    final searchable = [
      place['name'],
      place['category'],
      place['businessCategory'],
      place['description'],
      place['area'],
      ..._stringList(place['plannerCategories']),
      ..._stringList(place['tags']),
    ].map(_normalizeText).join(' ');
    return searchable.contains(normalizedInterest);
  }

  double _recommendationScore(
    Map<String, dynamic> place,
    List<String> interests,
  ) {
    final rating = ((place['score'] as num?) ?? 0).toDouble();
    final reviewCount = ((place['inAppReviewCount'] as num?) ?? 0).toDouble();
    final matchCount = interests
        .where((interest) => _placeMatchesInterest(place, interest))
        .length;
    return matchCount * 5 + rating + min(reviewCount, 20) / 20;
  }

  String _suggestionReason(Map<String, dynamic> place, List<String> interests) {
    final matched = interests
        .where((interest) => _placeMatchesInterest(place, interest))
        .take(2)
        .toList();
    final rating = ((place['score'] as num?) ?? 0).toDouble();
    final area = '${place['area'] ?? ''}'.trim();
    final pieces = <String>[
      if (matched.isNotEmpty) 'Matches ${matched.join(' and ')}',
      if (rating > 0) '${rating.toStringAsFixed(1)} rated',
      if (area.isNotEmpty) area,
    ];
    return pieces.join(' - ');
  }

  Widget _recommendationCard(BuildContext context, Map<String, dynamic> place) {
    final rating = ((place['score'] as num?) ?? 0).toDouble();
    final reason = '${place['suggestionReason'] ?? ''}'.trim();
    return SizedBox(
      width: 210,
      child: ExplorerCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlaceDetailPage(placeId: '${place['placeId']}', place: place),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: ItineraryPlaceImage(
                stop: place,
                width: double.infinity,
                height: 94,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExplorerStatusBadge(
                        label: '${place['category'] ?? 'Place'}',
                        tone: ExplorerStatusTone.navy,
                      ),
                      const Spacer(),
                      if (rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: ExplorerColors.goldDark,
                          size: 15,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${place['name']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reason.isEmpty ? '${place['area'] ?? ''}' : reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: ExplorerColors.muted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${place['state'] ?? place['area'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: ExplorerColors.navy,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryCard(
    BuildContext context,
    String itineraryId,
    Map<String, dynamic> data,
  ) {
    final stops = List<Map<String, dynamic>>.from(data['stops'] ?? const []);
    final firstStop = stops.isEmpty ? null : stops.first;
    final startDate = asDate(data['startDate']) ?? asDate(data['targetDate']);
    final endDate = asDate(data['endDate']) ?? startDate;
    final savedDays = data['days'] is List ? (data['days'] as List).length : 0;
    final dayCount = max(1, (data['dayCount'] as num?)?.round() ?? savedDays);
    final dateLabel = startDate == null
        ? 'Flexible dates'
        : endDate != null && !DateUtils.isSameDay(startDate, endDate)
        ? '${DateFormat('d MMM').format(startDate)} - ${DateFormat('d MMM').format(endDate)}'
        : DateFormat('d MMM yyyy').format(startDate);
    return ExplorerCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ItineraryEditPage(itineraryId: itineraryId, itinerary: data),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 146,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: firstStop == null
                        ? const ColoredBox(
                            color: ExplorerColors.navySoft,
                            child: Icon(
                              Icons.route_outlined,
                              size: 62,
                              color: Color(0xFF9EB1CC),
                            ),
                          )
                        : ItineraryPlaceImage(
                            stop: firstStop,
                            width: double.infinity,
                            height: 146,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: ExplorerStatusBadge(
                      label: 'CURRENT TRIP',
                      tone: ExplorerStatusTone.navy,
                    ),
                  ),
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.arrow_forward,
                        color: ExplorerColors.navy,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['title'] ?? firstStop?['name'] ?? 'Saved Itinerary'}',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['area'] ?? firstStop?['area'] ?? ''}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: ExplorerColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.map_outlined,
                      size: 15,
                      color: ExplorerColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$dayCount ${dayCount == 1 ? 'day' : 'days'} | ${stops.length} stops',
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(BuildContext context, Map<String, dynamic> data) {
    final status = '${data['status'] ?? 'pending'}';
    final tone = status == 'approved'
        ? ExplorerStatusTone.success
        : status == 'rejected'
        ? ExplorerStatusTone.danger
        : ExplorerStatusTone.warning;
    return ExplorerCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CulturalTasksPage()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExplorerStatusBadge(label: status.toUpperCase(), tone: tone),
              const Spacer(),
              Text(
                '+${data['rewardPoints'] ?? 0} pts',
                style: const TextStyle(
                  color: ExplorerColors.goldDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${data['taskTitle'] ?? 'Cultural Task'}',
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${data['expectedCategory'] ?? 'Complete your cultural experience and submit proof.'}',
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: status == 'approved' ? 1 : .6,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: ExplorerColors.subtle,
            valueColor: const AlwaysStoppedAnimation(ExplorerColors.navy),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CulturalTasksPage()),
              ),
              child: const Text('Continue Task'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _updateCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? action,
  }) {
    return ExplorerCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Text(
              action,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            const Icon(Icons.chevron_right, color: ExplorerColors.muted),
        ],
      ),
    );
  }
}

class _RecommendationLoadingCard extends StatelessWidget {
  const _RecommendationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: ExplorerCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 94,
              decoration: const BoxDecoration(
                color: ExplorerColors.navySoft,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76,
                    height: 18,
                    decoration: BoxDecoration(
                      color: ExplorerColors.subtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: ExplorerColors.subtle,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: 130,
                    height: 14,
                    decoration: BoxDecoration(
                      color: ExplorerColors.subtle,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
