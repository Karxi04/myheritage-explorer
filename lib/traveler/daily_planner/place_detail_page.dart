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
  bool isUpdatingReview = false;
  bool loadingDetails = false;
  bool showAllReviews = false;
  int? starFilter;
  String sortOption = 'helpful';
  final Set<String> _pendingHelpfulReviewIds = <String>{};
  final Set<String> _selectedAspectTags = <String>{};
  bool _isEditingReview = false;
  String? _editingReviewId;
  int _editingReviewOriginalEditCount = 0;
  double? liveReviewAverage;
  int? liveReviewCount;
  String? detailsError;
  late Map<String, dynamic> place;
  final GlobalKey reviewFormKey = GlobalKey();

  static const List<String> availableAspectTags = [
    'Authentic Taste',
    'Must Try',
    'Friendly Service',
    'Scenic View',
    'Photogenic',
    'Heritage Atmosphere',
    'Value for Money',
    'Clean & Cozy',
    'Family Friendly',
  ];

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

    try {
      final activeTasks = await CulturalTaskService.loadActiveTasks();
      final matchedTask = CulturalTaskService.matchTaskForPlace(enriched, activeTasks);
      if (matchedTask != null) {
        enriched['culturalTask'] = matchedTask;
      }
    } catch (_) {}

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

  String _vendorReviewId() {
    final vendorId = '${place['vendorId'] ?? ''}'.trim();
    if (vendorId.isNotEmpty) return vendorId;

    final placeId = widget.placeId.trim();
    if (placeId.startsWith('vendor_')) {
      return placeId.substring('vendor_'.length);
    }
    return '';
  }

  bool _isRegisteredVendorPlace() {
    return _vendorReviewId().isNotEmpty ||
        '${place['source'] ?? ''}' == 'registered_vendor';
  }

  bool _isDisplayableReview(Map<String, dynamic> review) {
    final status = '${review['status'] ?? 'valid'}'.trim().toLowerCase();
    return !{'flagged', 'hidden', 'removed', 'rejected', 'filtered', 'deleted'}.contains(status);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _placeReviewsStream() {
    final vendorId = _vendorReviewId();
    final reviews = AppServices.db.collection('reviews');
    if (vendorId.isNotEmpty) {
      return reviews.where('vendorId', isEqualTo: vendorId).snapshots();
    }

    final placeId = widget.placeId.trim().isNotEmpty
        ? widget.placeId.trim()
        : '${place['placeId'] ?? ''}'.trim();
    if (placeId.isNotEmpty) {
      return reviews.where('placeId', isEqualTo: placeId).snapshots();
    }

    return reviews
        .where('placeNameKey', isEqualTo: GeoapifyPlanner.reviewKeyFor(place))
        .snapshots();
  }

  void _syncLiveReviewSummary({required double average, required int count}) {
    if (liveReviewAverage == average && liveReviewCount == count) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (liveReviewAverage == average && liveReviewCount == count) return;
      setState(() {
        liveReviewAverage = average;
        liveReviewCount = count;
        if (count > 0) {
          place['score'] = average;
          place['inAppReviewCount'] = count;
        }
      });
    });
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
    return frequencies.values.any((frequency) => frequency >= 5);
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
    String? excludeReviewId,
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

    final vendorId = _vendorReviewId();
    Query<Map<String, dynamic>> query = AppServices.db.collection('reviews');
    if (vendorId.isNotEmpty) {
      query = query.where('vendorId', isEqualTo: vendorId);
    } else if (placeNameKey.isNotEmpty) {
      query = query.where('placeNameKey', isEqualTo: placeNameKey);
    }

    if (normalised.isNotEmpty) {
      final relatedReviews = await query.get();
      final duplicate = relatedReviews.docs.any((doc) {
        if (doc.id == excludeReviewId) return false;
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

  void _startEditReview(Map<String, dynamic> existingReview) {
    final editCount = (existingReview['editCount'] as num? ?? 0).toInt();
    if (editCount >= 2) {
      showMessage(
        context,
        'You have reached the maximum of 2 review edits.',
        error: true,
      );
      return;
    }

    setState(() {
      _isEditingReview = true;
      _editingReviewId = '${existingReview['id'] ?? existingReview['reviewId'] ?? ''}';
      _editingReviewOriginalEditCount = editCount;
      rating = (existingReview['rating'] as num? ?? 5).round();
      comment.text = '${existingReview['comment'] ?? ''}';
      _selectedAspectTags.clear();
      _selectedAspectTags.addAll(
        List<String>.from(existingReview['aspectTags'] ?? const <String>[]),
      );
    });
    _scrollToReviewForm();
  }

  void _cancelEditReview() {
    setState(() {
      _isEditingReview = false;
      _editingReviewId = null;
      _editingReviewOriginalEditCount = 0;
      comment.clear();
      _selectedAspectTags.clear();
      rating = 5;
    });
  }

  Future<void> _saveReviewEdit() async {
    if (isUpdatingReview) return;
    if (_editingReviewId == null || _editingReviewId!.isEmpty) {
      showMessage(context, 'Unable to locate review to update.', error: true);
      return;
    }

    final reviewText = comment.text.trim();
    if (reviewText.isEmpty) {
      showMessage(context, 'Please provide a review comment.', error: true);
      return;
    }

    setState(() => isUpdatingReview = true);
    try {
      final currentUser = AppServices.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Please sign in before updating your review.');
      }

      final uid = currentUser.uid;
      final placeNameKey = GeoapifyPlanner.reviewKeyFor(place);

      // Re-run NLP & ML analysis dynamically on the updated text & star rating
      final mlPrediction = ReviewMlModel.analyze(
        reviewText: reviewText,
        rating: rating,
      );
      final flags = await _detectReviewFlags(
        reviewText: reviewText,
        placeNameKey: placeNameKey,
        uid: uid,
        prediction: mlPrediction,
        excludeReviewId: _editingReviewId,
      );
      final moderation = ReviewModerationPolicy.decide(
        prediction: mlPrediction,
        ruleFlags: flags,
        reviewText: reviewText,
        rating: rating,
      );
      final flagged = moderation.isFlagged;

      final mlMap = {
        'status': moderation.reviewStatus,
        'flagReason': moderation.reasons.isEmpty
            ? null
            : moderation.reasons.join(' - '),
        'flagReasons': moderation.reasons,
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
        'mlRiskScore': double.parse(moderation.riskScore.toStringAsFixed(4)),
        'mlRiskLevel': moderation.riskLevel,
        'mlNeedsReview': moderation.needsReview,
        'mlDecision': moderation.decision,
      };

      await ReviewService.editReview(
        reviewId: _editingReviewId!,
        userId: uid,
        newRating: rating,
        newComment: reviewText,
        newAspectTags: _selectedAspectTags.toList(),
        mlData: mlMap,
      );

      _cancelEditReview();
      if (mounted) {
        showMessage(
          context,
          flagged
              ? 'Review updated and queued for administrator checking.'
              : 'Review updated successfully. (Edit ${_editingReviewOriginalEditCount + 1} of 2 used)',
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
      if (mounted) setState(() => isUpdatingReview = false);
    }
  }

  Future<void> submitReview() async {
    if (submitting) return;
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
      final reviewVendorId = _vendorReviewId();
      
      final alreadyReviewed = await ReviewService.hasUserReviewedPlace(
        userId: uid,
        placeId: widget.placeId,
        vendorId: reviewVendorId,
      );
      if (alreadyReviewed) {
        if (mounted) {
          showMessage(
            context,
            'You have already reviewed this place. You can edit your existing review.',
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
      final moderation = ReviewModerationPolicy.decide(
        prediction: mlPrediction,
        ruleFlags: flags,
        reviewText: reviewText,
        rating: rating,
      );
      final flagged = moderation.isFlagged;
      final reviewerName = await _loadReviewerName(uid);

      final mlMap = {
        'status': moderation.reviewStatus,
        'flagReason': moderation.reasons.isEmpty
            ? null
            : moderation.reasons.join(' - '),
        'flagReasons': moderation.reasons,
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
        'mlRiskScore': double.parse(moderation.riskScore.toStringAsFixed(4)),
        'mlRiskLevel': moderation.riskLevel,
        'mlNeedsReview': moderation.needsReview,
        'mlDecision': moderation.decision,
      };

      await ReviewService.submitReview(
        userId: uid,
        userName: reviewerName,
        placeId: widget.placeId,
        vendorId: reviewVendorId.isNotEmpty
            ? reviewVendorId
            : (place['vendorId'] ?? ''),
        placeName: '${place['name'] ?? ''}',
        placeNameKey: placeNameKey,
        source: '${place['source'] ?? 'registered_vendor'}',
        geoapifyPlaceId: '${place['geoapifyPlaceId'] ?? ''}',
        rating: rating,
        comment: reviewText,
        aspectTags: _selectedAspectTags.toList(),
        isVerified: true,
        mlData: mlMap,
      );

      comment.clear();
      _selectedAspectTags.clear();
      if (mounted) {
        showMessage(
          context,
          flagged
              ? 'Review submitted and sent to the administrator for checking.'
              : moderation.needsReview
              ? 'Review submitted and queued for a quick quality check.'
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
                          color: Colors.black.withValues(alpha: .72),
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
                                final raw =
                                    liveReviewAverage ??
                                    ((place['score'] as num?) ??
                                            (place['rating'] as num?) ??
                                            0)
                                        .toDouble();
                                final s = raw > 0 ? raw : 4.8;
                                final count =
                                    liveReviewCount ??
                                    (place['inAppReviewCount'] as num? ?? 0);
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
                  subtitle:
                      'Authentic community ratings & verified traveler reviews.',
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _placeReviewsStream(),
                  builder: (context, snapshot) {
                    final liveReviews = (snapshot.data?.docs ?? [])
                        .map((doc) => {'id': doc.id, ...doc.data()})
                        .where(_isDisplayableReview)
                        .toList();

                    final fallbackReviews =
                        liveReviews.isEmpty && !_isRegisteredVendorPlace()
                        ? PlaceReviewsData.getVerifiedReviews(place)
                        : const <Map<String, dynamic>>[];
                    final allReviews = <Map<String, dynamic>>[
                      ...liveReviews,
                      ...fallbackReviews,
                    ];

                    double calculatedScore = 0.0;
                    if (allReviews.isNotEmpty) {
                      final sum = allReviews.fold<double>(
                        0.0,
                        (acc, r) =>
                            acc + ((r['rating'] as num?)?.toDouble() ?? 5.0),
                      );
                      calculatedScore = sum / allReviews.length;
                    }
                    final double rawPlaceScore =
                        ((place['score'] as num?) ??
                                (place['rating'] as num?) ??
                                0)
                            .toDouble();
                    final double baseScore = calculatedScore > 0
                        ? calculatedScore
                        : (rawPlaceScore > 0 ? rawPlaceScore : 4.8);
                    final int totalReviews = allReviews.length;
                    if (snapshot.hasData) {
                      _syncLiveReviewSummary(
                        average: calculatedScore > 0 ? calculatedScore : 0,
                        count: totalReviews,
                      );
                    }

                    final int count5 = allReviews
                        .where(
                          (r) => ((r['rating'] as num?)?.round() ?? 5) == 5,
                        )
                        .length;
                    final int count4 = allReviews
                        .where(
                          (r) => ((r['rating'] as num?)?.round() ?? 5) == 4,
                        )
                        .length;
                    final int count3 = allReviews
                        .where(
                          (r) => ((r['rating'] as num?)?.round() ?? 5) == 3,
                        )
                        .length;
                    final int count2 = allReviews
                        .where(
                          (r) => ((r['rating'] as num?)?.round() ?? 5) == 2,
                        )
                        .length;
                    final int count1 = allReviews
                        .where(
                          (r) => ((r['rating'] as num?)?.round() ?? 5) == 1,
                        )
                        .length;
                    final int reviewTotal = allReviews.isEmpty
                        ? 1
                        : allReviews.length;

                    // Filter by selected star rating
                    final filteredReviews = allReviews.where((r) {
                      if (starFilter == null) return true;
                      return ((r['rating'] as num?)?.round() ?? 5) == starFilter;
                    }).toList();

                    // Sort reviews
                    filteredReviews.sort((a, b) {
                      if (sortOption == 'helpful') {
                        final hA = (a['helpfulCount'] as num? ?? 0).toInt();
                        final hB = (b['helpfulCount'] as num? ?? 0).toInt();
                        if (hB != hA) return hB.compareTo(hA);
                      } else if (sortOption == 'rating') {
                        final rA = (a['rating'] as num? ?? 5).toDouble();
                        final rB = (b['rating'] as num? ?? 5).toDouble();
                        if (rB != rA) return rB.compareTo(rA);
                      }
                      // fallback: newest date
                      final dateA = asDate(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final dateB = asDate(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return dateB.compareTo(dateA);
                    });

                    const previewCount = 4;
                    final visibleDocs = showAllReviews
                        ? filteredReviews
                        : filteredReviews.take(previewCount).toList();
                    final hiddenCount = filteredReviews.length - visibleDocs.length;

                    return Column(
                      children: [
                        // Rating Breakdown Card
                        ExplorerCard(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            i < baseScore.round()
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
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
                        // Star Filter and Sort Controls Card
                        ExplorerCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Filter & Sort',
                                    style: TextStyle(
                                      color: ExplorerColors.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: sortOption,
                                      isDense: true,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'helpful',
                                          child: Text('👍 Most Helpful'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'newest',
                                          child: Text('🕒 Newest First'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'rating',
                                          child: Text('★ Highest Rating'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => sortOption = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildStarFilterChip(label: 'All ($totalReviews)', value: null),
                                    const SizedBox(width: 6),
                                    _buildStarFilterChip(label: '5★ ($count5)', value: 5),
                                    const SizedBox(width: 6),
                                    _buildStarFilterChip(label: '4★ ($count4)', value: 4),
                                    const SizedBox(width: 6),
                                    _buildStarFilterChip(label: '3★ ($count3)', value: 3),
                                    const SizedBox(width: 6),
                                    _buildStarFilterChip(label: '2★ ($count2)', value: 2),
                                    const SizedBox(width: 6),
                                    _buildStarFilterChip(label: '1★ ($count1)', value: 1),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExplorerCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              if (visibleDocs.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    starFilter != null
                                        ? 'No $starFilter★ reviews found. Try selecting "All".'
                                        : 'No traveler reviews yet.',
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                ...visibleDocs.asMap().entries.map((entry) {
                                  final review = entry.value;
                                  final reviewId = '${review['id'] ?? review['reviewId'] ?? 'rev_${entry.key}'}';
                                  final currentUid = AppServices.auth.currentUser?.uid;
                                  final reviewUserId = '${review['userId'] ?? ''}';
                                  final isOwnReview = currentUid != null && reviewUserId.isNotEmpty && reviewUserId == currentUid;
                                  final helpfulUserIds = List<String>.from(review['helpfulUserIds'] ?? const <String>[]);
                                  final isMarkedHelpful = currentUid != null && helpfulUserIds.contains(currentUid);
                                  final int displayHelpfulCount = (review['helpfulCount'] as num?)?.toInt() ?? helpfulUserIds.length;
                                  final int editCount = (review['editCount'] as num? ?? 0).toInt();
                                  final aspectTags = List<String>.from(review['aspectTags'] ?? const <String>[]);
                                  final dateStr =
                                      review['date'] ??
                                      (asDate(review['createdAt']) != null
                                          ? DateFormat.yMMMd().format(
                                              asDate(review['createdAt'])!,
                                            )
                                          : 'Recent review');
                                  final isLastVisible =
                                      entry.key == visibleDocs.length - 1;
                                  final isVerified =
                                      review['isVerified'] == true ||
                                      reviewUserId.isNotEmpty;

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                const CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: ExplorerColors.navySoft,
                                                  foregroundColor: ExplorerColors.navy,
                                                  child: Icon(Icons.person_outline, size: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              '${review['reviewerName'] ?? review['travelerName'] ?? 'Traveler'}',
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: ExplorerColors.navy,
                                                                fontWeight: FontWeight.w800,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isOwnReview) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: ExplorerColors.navy,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.person_outline,
                                                                    size: 10,
                                                                    color: Colors.white,
                                                                  ),
                                                                  SizedBox(width: 3),
                                                                  Text(
                                                                    'Your Review',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.w800,
                                                                      color: Colors.white,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                          if (isVerified) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 1.5,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFE8F5E9),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.verified,
                                                                    size: 10,
                                                                    color: Color(0xFF2E7D32),
                                                                  ),
                                                                  SizedBox(width: 3),
                                                                  Text(
                                                                    'Verified Visit',
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
                                                      const SizedBox(height: 3),
                                                      Row(
                                                        children: [
                                                          Row(
                                                            children: List.generate(5, (index) {
                                                              final reviewRating =
                                                                  (review['rating'] as num?)?.round() ?? 5;
                                                              return Icon(
                                                                index < reviewRating
                                                                    ? Icons.star_rounded
                                                                    : Icons.star_border_rounded,
                                                                color: ExplorerColors.goldDark,
                                                                size: 15,
                                                              );
                                                            }),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            dateStr,
                                                            style: const TextStyle(
                                                              color: ExplorerColors.muted,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                          if (editCount > 0) ...[
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              '• ($editCount/2 edits used)',
                                                              style: const TextStyle(
                                                                color: ExplorerColors.muted,
                                                                fontSize: 10,
                                                                fontStyle: FontStyle.italic,
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
                                            if (aspectTags.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: aspectTags.map((tag) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: ExplorerColors.navySoft,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: ExplorerColors.navy.withValues(alpha: 0.15),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '🏷️ $tag',
                                                      style: const TextStyle(
                                                        color: ExplorerColors.navy,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              '${review['comment'] ?? ''}',
                                              style: const TextStyle(
                                                color: ExplorerColors.text,
                                                fontSize: 12.5,
                                                height: 1.45,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                if (isOwnReview) ...[
                                                  if (editCount < 2)
                                                    OutlinedButton.icon(
                                                      onPressed: () => _startEditReview(review),
                                                      style: OutlinedButton.styleFrom(
                                                        visualDensity: VisualDensity.compact,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        side: const BorderSide(color: ExplorerColors.navy),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                      ),
                                                      icon: const Icon(Icons.edit_outlined, size: 12, color: ExplorerColors.navy),
                                                      label: Text(
                                                        'Edit Review ($editCount/2 edits used)',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: ExplorerColors.navy,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF5F5F5),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Text(
                                                        '2/2 edits used • Maximum edits reached',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: ExplorerColors.muted,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ] else ...[
                                                  InkWell(
                                                    borderRadius: BorderRadius.circular(16),
                                                    onTap: _pendingHelpfulReviewIds.contains(reviewId)
                                                        ? null
                                                        : () async {
                                                            if (currentUid == null) {
                                                              showMessage(context, 'Please sign in to vote.');
                                                              return;
                                                            }
                                                            if (review['id'] == null) {
                                                              showMessage(context, 'Sample preview review cannot be voted on.');
                                                              return;
                                                            }
                                                            setState(() => _pendingHelpfulReviewIds.add(reviewId));
                                                            try {
                                                              final isNowHelpful = await ReviewService.toggleHelpfulVote(
                                                                reviewId: '${review['id']}',
                                                                userId: currentUid,
                                                              );
                                                              if (!mounted) return;
                                                              showMessage(
                                                                context,
                                                                isNowHelpful
                                                                    ? 'Thank you! Marked as helpful.'
                                                                    : 'Helpful vote removed.',
                                                              );
                                                            } catch (e) {
                                                              if (!mounted) return;
                                                              showMessage(
                                                                context,
                                                                e.toString().replaceFirst('Exception: ', ''),
                                                                error: true,
                                                              );
                                                            } finally {
                                                              if (mounted) {
                                                                setState(() => _pendingHelpfulReviewIds.remove(reviewId));
                                                              }
                                                            }
                                                          },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isMarkedHelpful
                                                            ? ExplorerColors.navy
                                                            : ExplorerColors.navySoft,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: isMarkedHelpful
                                                            ? null
                                                            : Border.all(color: ExplorerColors.navy.withValues(alpha: 0.1)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (_pendingHelpfulReviewIds.contains(reviewId))
                                                            const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                valueColor: AlwaysStoppedAnimation<Color>(ExplorerColors.navy),
                                                              ),
                                                            )
                                                          else
                                                            Icon(
                                                              isMarkedHelpful
                                                                  ? Icons.thumb_up_rounded
                                                                  : Icons.thumb_up_alt_outlined,
                                                              size: 13,
                                                              color: isMarkedHelpful ? Colors.white : ExplorerColors.navy,
                                                            ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Helpful ($displayHelpfulCount)',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                              color: isMarkedHelpful ? Colors.white : ExplorerColors.navy,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLastVisible)
                                        const Divider(height: 1),
                                    ],
                                  );
                                }),
                              if (filteredReviews.length > previewCount) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(
                                        () => showAllReviews = !showAllReviews,
                                      ),
                                      icon: Icon(
                                        showAllReviews
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                      ),
                                      label: Text(
                                        showAllReviews
                                            ? 'Show Fewer Reviews'
                                            : 'See More Reviews ($hiddenCount more)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final currentUid = AppServices.auth.currentUser?.uid;
                            final userExistingReview = allReviews.cast<Map<String, dynamic>?>().firstWhere(
                              (r) => r != null && currentUid != null && '${r['userId'] ?? ''}' == currentUid,
                              orElse: () => null,
                            );
                            final hasUserReviewed = userExistingReview != null;

                            return _WriteReviewPrompt(
                              onPressed: _scrollToReviewForm,
                              isAlreadyReviewed: hasUserReviewed,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                // Review Form Card (Already Reviewed / Edit Mode / Write Mode)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _placeReviewsStream(),
                  builder: (context, snapshot) {
                    final currentUid = AppServices.auth.currentUser?.uid;
                    final liveReviews = (snapshot.data?.docs ?? [])
                        .map((doc) => {'id': doc.id, ...doc.data()})
                        .toList();
                    final userExistingReview = liveReviews.cast<Map<String, dynamic>?>().firstWhere(
                      (r) => r != null && currentUid != null && '${r['userId'] ?? ''}' == currentUid,
                      orElse: () => null,
                    );
                    final hasUserReviewed = userExistingReview != null;

                    if (hasUserReviewed && !_isEditingReview) {
                      final editCount = (userExistingReview['editCount'] as num? ?? 0).toInt();
                      final aspectTags = List<String>.from(userExistingReview['aspectTags'] ?? const <String>[]);
                      final ratingVal = (userExistingReview['rating'] as num?)?.round() ?? 5;

                      return ExplorerCard(
                        key: reviewFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2E7D32),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'You have already reviewed this place.',
                                        style: TextStyle(
                                          color: ExplorerColors.navy,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        editCount < 2
                                            ? 'You can edit your review up to 2 times (${2 - editCount} remaining).'
                                            : 'You have reached the maximum of 2 review edits for this place.',
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ExplorerColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ExplorerColors.navy.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < ratingVal
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: ExplorerColors.goldDark,
                                            size: 16,
                                          );
                                        }),
                                      ),
                                      const Spacer(),
                                      Text(
                                        editCount > 0
                                            ? '$editCount/2 edits used'
                                            : '0/2 edits used (Original submission)',
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (aspectTags.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: aspectTags.map((t) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: ExplorerColors.navySoft,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '🏷️ $t',
                                            style: const TextStyle(
                                              color: ExplorerColors.navy,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '${userExistingReview['comment'] ?? ''}',
                                    style: const TextStyle(
                                      color: ExplorerColors.text,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (editCount < 2)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _startEditReview(userExistingReview),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: Text(
                                    'Edit Review ($editCount/2 edits used)',
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFB74D)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
                                    SizedBox(width: 6),
                                    Text(
                                      '2/2 edits used • Maximum edits reached.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    if (_isEditingReview) {
                      return ExplorerCard(
                        key: reviewFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExplorerSectionTitle(
                              'Edit Your Review',
                              subtitle:
                                  'Editing review (${_editingReviewOriginalEditCount}/2 edits used). ML sentiment & suspiciousness analysis will be automatically re-evaluated.',
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
                            const SizedBox(height: 8),
                            const Text(
                              'Update highlights (optional):',
                              style: TextStyle(
                                color: ExplorerColors.navy,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: availableAspectTags.map((tag) {
                                final isSelected = _selectedAspectTags.contains(tag);
                                return FilterChip(
                                  label: Text(tag),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedAspectTags.add(tag);
                                      } else {
                                        _selectedAspectTags.remove(tag);
                                      }
                                    });
                                  },
                                  selectedColor: ExplorerColors.goldSoft,
                                  checkmarkColor: ExplorerColors.goldDark,
                                  labelStyle: TextStyle(
                                    color: isSelected ? ExplorerColors.goldDark : ExplorerColors.navy,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  backgroundColor: ExplorerColors.navySoft,
                                  side: BorderSide(
                                    color: isSelected
                                        ? ExplorerColors.goldDark
                                        : ExplorerColors.navy.withValues(alpha: 0.1),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: comment,
                              maxLines: 4,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Review comment',
                                hintText: 'Update your review comment...',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: isUpdatingReview ? null : _saveReviewEdit,
                                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                    icon: isUpdatingReview
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 18),
                                    label: Text(isUpdatingReview ? 'Saving...' : 'Update Review'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: isUpdatingReview ? null : _cancelEditReview,
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(80, 48)),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    // Standard Write Review Card
                    return ExplorerCard(
                      key: reviewFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ExplorerSectionTitle(
                            'Write Your Review',
                            subtitle:
                                'Visited this place? Select a star rating, choose aspect tags, and describe your experience.',
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
                          const SizedBox(height: 8),
                          const Text(
                            'Add highlights to your review (optional):',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: availableAspectTags.map((tag) {
                              final isSelected = _selectedAspectTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedAspectTags.add(tag);
                                    } else {
                                      _selectedAspectTags.remove(tag);
                                    }
                                  });
                                },
                                selectedColor: ExplorerColors.goldSoft,
                                checkmarkColor: ExplorerColors.goldDark,
                                labelStyle: TextStyle(
                                  color: isSelected ? ExplorerColors.goldDark : ExplorerColors.navy,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 11,
                                ),
                                backgroundColor: ExplorerColors.navySoft,
                                side: BorderSide(
                                  color: isSelected
                                      ? ExplorerColors.goldDark
                                      : ExplorerColors.navy.withValues(alpha: 0.1),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
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
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarFilterChip({required String label, required int? value}) {
    final isSelected = starFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => starFilter = value),
      selectedColor: ExplorerColors.navy,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : ExplorerColors.navy,
        fontSize: 10.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      ),
      backgroundColor: ExplorerColors.navySoft,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: isSelected ? ExplorerColors.navy : ExplorerColors.navy.withValues(alpha: 0.1),
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
        const Icon(
          Icons.star_rounded,
          size: 11,
          color: ExplorerColors.goldDark,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: const AlwaysStoppedAnimation<Color>(
                ExplorerColors.goldDark,
              ),
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
}

class _WriteReviewPrompt extends StatelessWidget {
  const _WriteReviewPrompt({
    required this.onPressed,
    this.isAlreadyReviewed = false,
  });

  final VoidCallback onPressed;
  final bool isAlreadyReviewed;

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
              color: isAlreadyReviewed
                  ? const Color(0xFFE8F5E9)
                  : ExplorerColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAlreadyReviewed
                  ? Icons.check_circle_outline_rounded
                  : Icons.rate_review_outlined,
              color: isAlreadyReviewed
                  ? const Color(0xFF2E7D32)
                  : ExplorerColors.goldDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAlreadyReviewed
                      ? 'You reviewed this place'
                      : 'Already visited this place?',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAlreadyReviewed
                      ? 'Tap to view or edit your review.'
                      : 'Write your own rating and review below.',
                  style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onPressed,
            child: Text(isAlreadyReviewed ? 'View / Edit' : 'Write Review'),
          ),
        ],
      ),
    );
  }
}
