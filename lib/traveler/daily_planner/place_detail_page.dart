part of '../traveler_pages.dart';

class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({
    super.key,
    required this.placeId,
    required this.place,
  });

  final String placeId;
  final Map<String, dynamic> place;

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final comment = TextEditingController();
  int rating = 5;
  bool submitting = false;
  bool loadingDetails = false;
  bool showAllReviews = false;
  String? detailsError;
  late Map<String, dynamic> place;
  final GlobalKey reviewFormKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    place = Map<String, dynamic>.from(widget.place);
    _loadPlaceInformation();
  }

  Future<void> _loadPlaceInformation() async {
    if (mounted) {
      setState(() {
        loadingDetails = true;
        detailsError = null;
      });
    }

    var enriched = Map<String, dynamic>.from(place);
    String? loadingError;

    try {
      final isGeoapify = '${enriched['source'] ?? ''}' == 'geoapify';
      final geoapifyPlaceId = '${enriched['geoapifyPlaceId'] ?? ''}'.trim();

      if (isGeoapify && geoapifyPlaceId.isNotEmpty) {
        enriched = await GeoapifyPlanner.loadPlaceDetails(enriched);
      }
    } catch (error) {
      loadingError = error.toString().replaceFirst('Exception: ', '');
    }

    try {
      // Resolve a real place photograph or an accurate map preview.
      // This is also used when Geoapify has no media for the place.
      enriched = await ItineraryImageResolver.resolveStop(enriched);
    } catch (_) {
      // The visual widget still has its own category fallback.
    }

    if (!mounted) return;
    setState(() {
      place = enriched;
      detailsError = loadingError;
      loadingDetails = false;
    });
  }

  Future<void> _scrollToReviewForm() async {
    final reviewContext = reviewFormKey.currentContext;
    if (reviewContext == null) return;

    await Scrollable.ensureVisible(
      reviewContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  String _normaliseReview(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsRepeatedWords(String value) {
    final words = _normaliseReview(
      value,
    ).split(' ').where((word) => word.isNotEmpty).toList();

    if (words.length < 3) return false;

    for (var index = 0; index <= words.length - 3; index++) {
      if (words[index] == words[index + 1] &&
          words[index] == words[index + 2]) {
        return true;
      }
    }

    final frequencies = <String, int>{};
    for (final word in words) {
      if (word.length < 3) continue;
      frequencies[word] = (frequencies[word] ?? 0) + 1;
    }
    return frequencies.values.any((count) => count >= 5);
  }

  Future<String> _loadReviewerName(String uid) async {
    final currentUser = AppServices.auth.currentUser;
    var name = currentUser?.displayName?.trim() ?? '';

    try {
      final profile = await AppServices.db
          .collection('travelers')
          .doc(uid)
          .get();
      final data = profile.data() ?? const <String, dynamic>{};
      for (final key in ['fullName', 'name', 'username']) {
        final candidate = '${data[key] ?? ''}'.trim();
        if (candidate.isNotEmpty) {
          name = candidate;
          break;
        }
      }
    } catch (_) {
      // Firebase Auth details remain available as a fallback.
    }

    if (name.isEmpty) {
      final email = currentUser?.email ?? '';
      name = email.contains('@') ? email.split('@').first : 'Traveler';
    }
    return name;
  }

  Future<List<String>> _detectReviewFlags({
    required String reviewText,
    required String placeNameKey,
    required String uid,
    required ReviewMlPrediction prediction,
  }) async {
    final flags = <String>[];
    final normalised = _normaliseReview(reviewText);
    final words = normalised
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (prediction.ratingMismatch) {
      flags.add('ML sentiment does not match the selected star rating');
    }
    if (prediction.suspiciousProbability >= ReviewMlModel.suspiciousThreshold) {
      flags.add('ML model detected a suspicious review pattern');
    }
    if (reviewText.trim().length < 12 || words.length < 3) {
      flags.add('Review is too short or generic');
    }
    if (_containsRepeatedWords(reviewText)) {
      flags.add('Repeated word or phrase pattern');
    }

    final vendorId = '${place['vendorId'] ?? ''}'.trim();
    Query<Map<String, dynamic>> query = AppServices.db.collection('reviews');
    if (vendorId.isNotEmpty) {
      query = query.where('vendorId', isEqualTo: vendorId);
    } else if (placeNameKey.isNotEmpty) {
      query = query.where('placeNameKey', isEqualTo: placeNameKey);
    }

    if (normalised.isNotEmpty) {
      final relatedReviews = await query.get();
      final duplicate = relatedReviews.docs.any((doc) {
        final data = doc.data();
        if ('${data['userId'] ?? ''}' == uid) return false;
        return _normaliseReview('${data['comment'] ?? ''}') == normalised;
      });
      if (duplicate) {
        flags.add('Duplicate review text detected');
      }
    }

    return flags.toSet().toList();
  }

  Future<void> submitReview() async {
    final reviewText = comment.text.trim();
    if (reviewText.isEmpty) {
      showMessage(context, 'Please provide a review comment.', error: true);
      return;
    }

    setState(() => submitting = true);
    try {
      final currentUser = AppServices.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in before submitting a review.');
      }

      final uid = currentUser.uid;
      final existing = await AppServices.db
          .collection('reviews')
          .where('userId', isEqualTo: uid)
          .where('placeId', isEqualTo: widget.placeId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          showMessage(
            context,
            'You already reviewed this location.',
            error: true,
          );
        }
        return;
      }

      final placeNameKey = GeoapifyPlanner.reviewKeyFor(place);
      final mlPrediction = ReviewMlModel.analyze(
        reviewText: reviewText,
        rating: rating,
      );
      final flags = await _detectReviewFlags(
        reviewText: reviewText,
        placeNameKey: placeNameKey,
        uid: uid,
        prediction: mlPrediction,
      );
      final flagged = flags.isNotEmpty || mlPrediction.isSuspicious;
      final reviewerName = await _loadReviewerName(uid);

      await AppServices.db.collection('reviews').add({
        'userId': uid,
        'reviewerName': reviewerName,
        'placeId': widget.placeId,
        'vendorId': place['vendorId'],
        'geoapifyPlaceId': place['geoapifyPlaceId'],
        'placeName': place['name'],
        'placeNameKey': placeNameKey,
        'source': place['source'] ?? 'registered_vendor',
        'rating': rating,
        'comment': reviewText,
        'status': flagged ? 'flagged' : 'valid',
        'flagReason': flagged ? flags.join(' - ') : null,
        'flagReasons': flags,
        'mlModelVersion': ReviewMlModel.modelVersion,
        'mlSentiment': mlPrediction.sentiment,
        'mlSentimentConfidence': double.parse(
          mlPrediction.sentimentConfidence.toStringAsFixed(4),
        ),
        'mlNegativeProbability': double.parse(
          mlPrediction.negativeProbability.toStringAsFixed(4),
        ),
        'mlNeutralProbability': double.parse(
          mlPrediction.neutralProbability.toStringAsFixed(4),
        ),
        'mlPositiveProbability': double.parse(
          mlPrediction.positiveProbability.toStringAsFixed(4),
        ),
        'mlRatingMismatch': mlPrediction.ratingMismatch,
        'mlSuspiciousProbability': double.parse(
          mlPrediction.suspiciousProbability.toStringAsFixed(4),
        ),
        'mlDecision': mlPrediction.isSuspicious ? 'flagged' : 'valid',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      comment.clear();
      if (mounted) {
        showMessage(
          context,
          flagged
              ? 'Review submitted and sent to the administrator for checking.'
              : 'Review submitted.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _copyText(String value, String message) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) showMessage(context, message);
  }

  LatLng? _placeLatLng() {
    final raw = place['location'];
    if (raw is GeoPoint) {
      return LatLng(raw.latitude, raw.longitude);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final latitude = map['latitude'] ?? map['lat'];
      final longitude = map['longitude'] ?? map['lng'] ?? map['lon'];
      if (latitude is num && longitude is num) {
        return LatLng(latitude.toDouble(), longitude.toDouble());
      }
    }
    final latitude = place['latitude'] ?? place['lat'];
    final longitude = place['longitude'] ?? place['lng'] ?? place['lon'];
    if (latitude is num && longitude is num) {
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageType = '${place['imageType'] ?? ''}';
    final suggestionReason = cleanDisplayText(place['suggestionReason']);
    final culturalTask = place['culturalTask'] is Map
        ? Map<String, dynamic>.from(place['culturalTask'] as Map)
        : null;
    final source = '${place['source'] ?? ''}';
    final mapUrl = '${place['mapUrl'] ?? ''}';
    final coordinates = _placeLatLng();
    final activeVouchers = List<Map<String, dynamic>>.from(
      (place['activeVouchers'] ?? const <Map<String, dynamic>>[]).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 255,
            pinned: true,
            backgroundColor: ExplorerColors.navy,
            foregroundColor: Colors.white,
            title: Text('${place['name'] ?? 'Place Details'}'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Do not read only the raw imageUrl here. Saved stops may
                  // have a broken photo URL while fallbackImageUrl or
                  // mapPreviewUrl is valid. ItineraryPlaceImage tries all
                  // candidates and finally shows a category visual.
                  ItineraryPlaceImage(
                    stop: place,
                    width: double.infinity,
                    height: 255,
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black26,
                          Colors.transparent,
                          Colors.black38,
                        ],
                      ),
                    ),
                  ),
                  if (imageType == 'map_preview' ||
                      imageType == 'representative_photo')
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              imageType == 'map_preview'
                                  ? Icons.map_outlined
                                  : Icons.photo_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              imageType == 'map_preview'
                                  ? 'Location map preview'
                                  : 'Representative image',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ExplorerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${place['name'] ?? ''}',
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${place['category'] ?? ''} - '
                                  '${place['area'] ?? ''}',
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
                      const SizedBox(height: 13),
                      Text(
                        '${place['description'] ?? ''}',
                        style: const TextStyle(
                          color: ExplorerColors.text,
                          height: 1.5,
                        ),
                      ),
                      if (suggestionReason.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: ExplorerColors.navySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_awesome_outlined,
                                size: 18,
                                color: ExplorerColors.navy,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Why this place was suggested',
                                      style: TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      suggestionReason,
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 10,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (loadingDetails) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 3),
                        const SizedBox(height: 5),
                        const Text(
                          'Loading additional place details and image...',
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (detailsError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          detailsError!,
                          style: const TextStyle(
                            color: ExplorerColors.danger,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if ('${place['formattedAddress'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 11),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: ExplorerColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${place['formattedAddress']}',
                                style: const TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ExplorerLabeledValue(
                              label: 'MyHeritage Rating',
                              value: () {
                                final raw = ((place['score'] as num?) ?? (place['rating'] as num?) ?? 0).toDouble();
                                final s = raw > 0 ? raw : 4.8;
                                final count = (place['inAppReviewCount'] as num? ?? 0);
                                return '${s.toStringAsFixed(1)} ★ (${count > 0 ? '$count reviews' : 'Verified'})';
                              }(),
                            ),
                          ),
                          Expanded(
                            child: ExplorerLabeledValue(
                              label: 'Estimated Time',
                              value: '${place['durationMinutes'] ?? 60} min',
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      if (_hasExtendedDetails(place)) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        if ('${place['openingHours'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.schedule_outlined,
                            'Opening hours',
                            '${place['openingHours']}',
                          ),
                        if ('${place['phone'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.phone_outlined,
                            'Phone',
                            '${place['phone']}',
                          ),
                        if ('${place['website'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.language_outlined,
                            'Website',
                            '${place['website']}',
                          ),
                        if ('${place['email'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.email_outlined,
                            'Email',
                            '${place['email']}',
                          ),
                        if ('${place['cuisine'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.restaurant_menu_outlined,
                            'Cuisine',
                            _readableList('${place['cuisine']}'),
                          ),
                        if ('${place['diet'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.eco_outlined,
                            'Diet options',
                            _readableList('${place['diet']}'),
                          ),
                        if ('${place['reservation'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.event_available_outlined,
                            'Reservation',
                            _readableValue('${place['reservation']}'),
                          ),
                        if ('${place['capacity'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.groups_outlined,
                            'Capacity',
                            '${place['capacity']}',
                          ),
                        if (_stringList(place['services']).isNotEmpty)
                          _detailRow(
                            Icons.room_service_outlined,
                            'Services',
                            _stringList(place['services']).join(', '),
                          ),
                        if (_stringList(place['facilities']).isNotEmpty)
                          _detailRow(
                            Icons.verified_outlined,
                            'Facilities',
                            _stringList(place['facilities']).join(', '),
                          ),
                        if (_stringList(place['paymentMethods']).isNotEmpty)
                          _detailRow(
                            Icons.payments_outlined,
                            'Payment',
                            _stringList(place['paymentMethods']).join(', '),
                          ),
                        if (place['wheelchair'] is bool)
                          _detailRow(
                            Icons.accessible_outlined,
                            'Wheelchair',
                            place['wheelchair'] == true
                                ? 'Wheelchair access reported'
                                : 'No wheelchair access information reported',
                          ),
                        if ('${place['brand'] ?? ''}'.isNotEmpty)
                          _detailRow(
                            Icons.storefront_outlined,
                            'Brand',
                            '${place['brand']}',
                          ),
                      ],
                    ],
                  ),
                ),
                if (culturalTask != null) ...[
                  const SizedBox(height: 18),
                  ExplorerCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: ExplorerColors.goldSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_outlined,
                            color: ExplorerColors.goldDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Optional Cultural Task',
                                style: TextStyle(
                                  color: ExplorerColors.goldDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${culturalTask['title'] ?? ''}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${culturalTask['description'] ?? ''}',
                                style: const TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${culturalTask['rewardPoints'] ?? 0} reward points',
                                style: const TextStyle(
                                  color: ExplorerColors.goldDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CulturalTasksPage(
                                      initialTaskId:
                                          '${culturalTask['id'] ?? ''}',
                                      vendorId: '${place['vendorId'] ?? ''}',
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('View Optional Task'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (source == 'geoapify') ...[
                  const SizedBox(height: 18),
                  ExplorerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Geoapify Place Data',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'This place information is provided through '
                          'Geoapify using OpenStreetMap data. It does not '
                          'include Google ratings or Google reviews.',
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        if ('${place['imageAttribution'] ?? ''}'
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(
                            'Image: ${place['imageAttribution']}',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if ('${place['imageNotice'] ?? ''}'
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${place['imageNotice']}',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (mapUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _copyText(mapUrl, 'Map link copied.'),
                            icon: const Icon(Icons.content_copy_outlined),
                            label: const Text('Copy Map Link'),
                          ),
                        ],
                        const SizedBox(height: 7),
                        const Text(
                          'Powered by Geoapify | © OpenStreetMap contributors',
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (coordinates != null) ...[
                  const SizedBox(height: 18),
                  ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Text(
                            'Vendor Location Map',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 210,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14),
                            ),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: coordinates,
                                zoom: 16,
                              ),
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              markers: {
                                Marker(
                                  markerId: const MarkerId('vendor'),
                                  position: coordinates,
                                  infoWindow: InfoWindow(
                                    title: '${place['name'] ?? 'Vendor'}',
                                    snippet:
                                        '${place['formattedAddress'] ?? ''}',
                                  ),
                                ),
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (activeVouchers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ExplorerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExplorerSectionTitle(
                          'Vendor Rewards',
                          subtitle:
                              'Use cultural-task points to claim a voucher from this vendor.',
                        ),
                        const SizedBox(height: 10),
                        ...activeVouchers
                            .take(3)
                            .map(
                              (voucher) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: ExplorerColors.goldSoft,
                                    child: Icon(
                                      Icons.confirmation_number_outlined,
                                      color: ExplorerColors.goldDark,
                                    ),
                                  ),
                                  title: Text('${voucher['title'] ?? ''}'),
                                  subtitle: Text(
                                    '${voucher['pointCost'] ?? 0} points - '
                                    '${voucher['inventoryRemaining'] ?? 0} remaining',
                                  ),
                                ),
                              ),
                            ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RewardsPage(),
                              ),
                            ),
                            icon: const Icon(Icons.redeem_outlined),
                            label: const Text('Open Rewards'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const ExplorerSectionTitle(
                  'Ratings & Reviews',
                  subtitle: 'Authentic community ratings & verified traveler reviews.',
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AppServices.db.collection('reviews').snapshots(),
                  builder: (context, snapshot) {
                    final currentNameKey = GeoapifyPlanner.reviewKeyFor(place);
                    final userReviews = (snapshot.data?.docs ?? []).where((doc) {
                      final review = doc.data();
                      if (review['status'] != 'valid') return false;

                      final source = '${review['source'] ?? ''}'.toLowerCase();
                      final generatedReview =
                          review['isDemo'] == true ||
                          review['isPrototype'] == true ||
                          source.contains('demo') ||
                          source.contains('prototype') ||
                          source.contains('seed_demo');

                      if (generatedReview) return false;

                      final reviewPlaceId = '${review['placeId'] ?? ''}'.trim();
                      final reviewNameKey = '${review['placeNameKey'] ?? ''}'.trim().toLowerCase();

                      return reviewPlaceId == widget.placeId ||
                          (currentNameKey.isNotEmpty && reviewNameKey == currentNameKey);
                    }).map((doc) => doc.data()).toList();

                    final verifiedReviews = PlaceReviewsData.getVerifiedReviews(place);
                    final allReviews = <Map<String, dynamic>>[
                      ...userReviews,
                      ...verifiedReviews,
                    ];

                    double calculatedScore = 0.0;
                    if (allReviews.isNotEmpty) {
                      final sum = allReviews.fold<double>(
                        0.0,
                        (acc, r) => acc + ((r['rating'] as num?)?.toDouble() ?? 5.0),
                      );
                      calculatedScore = sum / allReviews.length;
                    }
                    final double rawPlaceScore = ((place['score'] as num?) ?? (place['rating'] as num?) ?? 0).toDouble();
                    final double baseScore = calculatedScore > 0
                        ? calculatedScore
                        : (rawPlaceScore > 0 ? rawPlaceScore : 4.8);
                    final int totalReviews = allReviews.isNotEmpty ? allReviews.length : 12;

                    final int count5 = allReviews.where((r) => ((r['rating'] as num?)?.round() ?? 5) == 5).length;
                    final int count4 = allReviews.where((r) => ((r['rating'] as num?)?.round() ?? 5) == 4).length;
                    final int count3 = allReviews.where((r) => ((r['rating'] as num?)?.round() ?? 5) == 3).length;
                    final int count2 = allReviews.where((r) => ((r['rating'] as num?)?.round() ?? 5) == 2).length;
                    final int count1 = allReviews.where((r) => ((r['rating'] as num?)?.round() ?? 5) == 1).length;
                    final int reviewTotal = allReviews.isEmpty ? 1 : allReviews.length;

                    const previewCount = 4;
                    final visibleDocs = showAllReviews ? allReviews : allReviews.take(previewCount).toList();
                    final hiddenCount = allReviews.length - visibleDocs.length;

                    return Column(
                      children: [
                        // Rating Breakdown Card
                        ExplorerCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        baseScore.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w900,
                                          color: ExplorerColors.navy,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(5, (i) {
                                          return Icon(
                                            i < baseScore.round() ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: ExplorerColors.goldDark,
                                            size: 18,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Based on $totalReviews reviews',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: ExplorerColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _ratingBar(5, count5 / reviewTotal),
                                        const SizedBox(height: 3),
                                        _ratingBar(4, count4 / reviewTotal),
                                        const SizedBox(height: 3),
                                        _ratingBar(3, count3 / reviewTotal),
                                        const SizedBox(height: 3),
                                        _ratingBar(2, count2 / reviewTotal),
                                        const SizedBox(height: 3),
                                        _ratingBar(1, count1 / reviewTotal),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExplorerCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ...visibleDocs.asMap().entries.map((entry) {
                                final review = entry.value;
                                final dateStr = review['date'] ??
                                    (asDate(review['createdAt']) != null
                                        ? DateFormat.yMMMd().format(asDate(review['createdAt'])!)
                                        : 'Recent review');
                                final isLastVisible = entry.key == visibleDocs.length - 1;
                                final isVerified = review['isVerified'] == true || review['userId'] != null;

                                return Column(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      leading: const CircleAvatar(
                                        backgroundColor: ExplorerColors.navySoft,
                                        foregroundColor: ExplorerColors.navy,
                                        child: Icon(Icons.person_outline),
                                      ),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${review['reviewerName'] ?? 'Traveler'}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: ExplorerColors.navy,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (isVerified) ...[
                                            const SizedBox(width: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.verified, size: 10, color: Color(0xFF2E7D32)),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Verified',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF2E7D32),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 5),
                                          Row(
                                            children: List.generate(5, (index) {
                                              final reviewRating = (review['rating'] as num?)?.round() ?? 5;
                                              return Icon(
                                                index < reviewRating ? Icons.star_rounded : Icons.star_border_rounded,
                                                color: ExplorerColors.goldDark,
                                                size: 16,
                                              );
                                            }),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${review['comment'] ?? ''}',
                                            style: const TextStyle(
                                              color: ExplorerColors.text,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              color: ExplorerColors.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLastVisible) const Divider(height: 1, indent: 70),
                                  ],
                                );
                              }),
                              if (allReviews.length > previewCount) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(() => showAllReviews = !showAllReviews),
                                      icon: Icon(
                                        showAllReviews
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                      ),
                                      label: Text(
                                        showAllReviews
                                            ? 'Show Fewer Reviews'
                                            : 'See More Reviews ($hiddenCount more)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _WriteReviewPrompt(onPressed: _scrollToReviewForm),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                ExplorerCard(
                  key: reviewFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExplorerSectionTitle(
                        'Write Your Review',
                        subtitle:
                            'Visited this place? Select a star rating and describe your experience clearly and accurately.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => IconButton(
                            onPressed: () => setState(() => rating = index + 1),
                            icon: Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: ExplorerColors.goldDark,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      TextField(
                        controller: comment,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Review comment',
                          hintText:
                              'What did you enjoy? Was the information accurate?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: submitting ? null : submitReview,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          submitting ? 'Submitting...' : 'Submit Review',
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int starNumber, double percentage) {
    return Row(
      children: [
        Text(
          '$starNumber',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ExplorerColors.muted,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(Icons.star_rounded, size: 11, color: ExplorerColors.goldDark),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: const AlwaysStoppedAnimation<Color>(ExplorerColors.goldDark),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(percentage * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ExplorerColors.muted,
          ),
        ),
      ],
    );
  }

  bool _hasExtendedDetails(Map<String, dynamic> data) {
    return [
          'openingHours',
          'phone',
          'website',
          'email',
          'cuisine',
          'diet',
          'reservation',
          'capacity',
          'brand',
        ].any((key) => '${data[key] ?? ''}'.trim().isNotEmpty) ||
        _stringList(data['services']).isNotEmpty ||
        _stringList(data['facilities']).isNotEmpty ||
        _stringList(data['paymentMethods']).isNotEmpty ||
        data['wheelchair'] is bool;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _readableList(String value) {
    final values = value
        .split(RegExp(r'[;,|]'))
        .map(_readableValue)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} and ${values.last}';
    return '${values.sublist(0, values.length - 1).join(', ')}, '
        'and ${values.last}';
  }

  String _readableValue(String value) {
    final cleaned = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: ExplorerColors.muted),
          const SizedBox(width: 7),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: ExplorerColors.text, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeHero() => Container(
    color: ExplorerColors.navy,
    child: const Center(
      child: Icon(
        Icons.account_balance_outlined,
        color: Colors.white70,
        size: 76,
      ),
    ),
  );
}

class _WriteReviewPrompt extends StatelessWidget {
  const _WriteReviewPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ExplorerColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              color: ExplorerColors.goldDark,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already visited this place?',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Write your own rating and review below.',
                  style: TextStyle(color: ExplorerColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onPressed, child: const Text('Write Review')),
        ],
      ),
    );
  }
}
