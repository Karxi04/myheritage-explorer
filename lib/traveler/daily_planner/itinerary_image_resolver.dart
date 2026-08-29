part of '../traveler_pages.dart';

class ItineraryImageResolver {
  const ItineraryImageResolver._();

  static final Map<String, Future<Map<String, dynamic>>> _stopCache = {};
  static Future<Map<String, Map<String, dynamic>>>? _contentCache;

  static String _normalize(Object? value) {
    return '${value ?? ''}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isNetworkUrl(Object? value) {
    final url = '${value ?? ''}'.trim();
    return url.startsWith('https://') || url.startsWith('http://');
  }

  static bool _isStaticMapUrl(String value) {
    final lower = value.toLowerCase();
    return lower.contains('maps.geoapify.com/v1/staticmap') ||
        lower.contains('staticmap');
  }

  static String _normaliseImageUrl(Object? raw) {
    var value = '${raw ?? ''}'.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('//')) value = 'https:$value';

    if (value.toLowerCase().startsWith('file:')) {
      final fileName = value.substring(5).trim();
      if (fileName.isEmpty) return '';
      return 'https://commons.wikimedia.org/wiki/'
          'Special:Redirect/file/${Uri.encodeComponent(fileName)}?width=1200';
    }

    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.host.toLowerCase().contains('commons.wikimedia.org') &&
        uri.path.toLowerCase().startsWith('/wiki/file:')) {
      final encodedName = uri.path.substring('/wiki/File:'.length);
      final fileName = Uri.decodeComponent(encodedName);
      return 'https://commons.wikimedia.org/wiki/'
          'Special:Redirect/file/${Uri.encodeComponent(fileName)}?width=1200';
    }

    return _isNetworkUrl(value) ? value : '';
  }

  static List<String> _uniqueUrls(Iterable<Object?> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final url = _normaliseImageUrl(value);
      if (url.isEmpty || !seen.add(url)) continue;
      result.add(url);
    }
    return result;
  }

  static Map<String, dynamic> _withLatestStopFields(
    Map<String, dynamic> resolved,
    Map<String, dynamic> original,
  ) {
    final merged = <String, dynamic>{...original, ...resolved};
    for (final key in const [
      'durationMinutes',
      'openingHours',
      'sequence',
      'travelMinutesBefore',
      'routeDistanceMetersBefore',
      'suggestedStartMinutes',
      'suggestedEndMinutes',
      'suggestedTimeLabel',
      'mealSuggestionLabel',
      'scheduleNotes',
      'scheduleStatus',
    ]) {
      if (original.containsKey(key)) merged[key] = original[key];
    }
    return merged;
  }

  static Map<String, double>? coordinatesFor(Map<String, dynamic> stop) {
    final raw = stop['location'];
    if (raw is GeoPoint) {
      return {
        'latitude': raw.latitude,
        'longitude': raw.longitude,
      };
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final latitude = map['latitude'] ?? map['lat'];
      final longitude = map['longitude'] ?? map['lon'] ?? map['lng'];
      if (latitude is num && longitude is num) {
        return {
          'latitude': latitude.toDouble(),
          'longitude': longitude.toDouble(),
        };
      }
    }

    final latitude = stop['latitude'] ?? stop['lat'];
    final longitude = stop['longitude'] ?? stop['lon'] ?? stop['lng'];
    if (latitude is num && longitude is num) {
      return {
        'latitude': latitude.toDouble(),
        'longitude': longitude.toDouble(),
      };
    }
    return null;
  }

  static String staticMapPreview({
    required double latitude,
    required double longitude,
  }) {
    if (!GeoapifyConfig.isConfigured) return '';

    final lon = longitude.toStringAsFixed(6);
    final lat = latitude.toStringAsFixed(6);

    // Use only the documented centre parameters. This avoids failures from
    // malformed marker strings and still guarantees a location preview.
    return Uri.https(
      'maps.geoapify.com',
      '/v1/staticmap',
      {
        'style': 'osm-bright',
        'width': '640',
        'height': '400',
        'center': 'lonlat:$lon,$lat',
        'zoom': '16',
        'scaleFactor': '1',
        'format': 'jpeg',
        'apiKey': GeoapifyConfig.apiKey,
      },
    ).toString();
  }

  static String previewImageForStop(
    Map<String, dynamic> stop,
  ) {
    final candidates = _uniqueUrls([
      ...List<Object?>.from(
        stop['imageCandidates'] ?? const <Object?>[],
      ),
      stop['imageUrl'],
      stop['fallbackImageUrl'],
      stop['mapPreviewUrl'],
    ]);

    if (candidates.isNotEmpty) return candidates.first;

    final coordinates = coordinatesFor(stop);
    if (coordinates == null) return '';

    return staticMapPreview(
      latitude: coordinates['latitude']!,
      longitude: coordinates['longitude']!,
    );
  }

  static Future<Map<String, Map<String, dynamic>>> _loadPlaceContent() {
    return _contentCache ??= () async {
      final result = <String, Map<String, dynamic>>{};
      try {
        final snapshot = await AppServices.db
            .collection('place_content')
            .where('status', isEqualTo: 'active')
            .get();

        for (final document in snapshot.docs) {
          final data = <String, dynamic>{
            'id': document.id,
            ...document.data(),
          };
          final keys = <String>{
            _normalize(data['placeNameKey']),
            _normalize(data['name']),
            _normalize(document.id),
            ...List<String>.from(data['aliases'] ?? const <String>[])
                .map(_normalize),
          }..removeWhere((key) => key.isEmpty);
          for (final key in keys) {
            result[key] = data;
          }
        }
      } catch (_) {
        // Other image sources remain available.
      }
      return result;
    }();
  }

  static Map<String, dynamic>? _matchPlaceContent(
    Map<String, Map<String, dynamic>> content,
    String placeName,
  ) {
    final key = _normalize(placeName);
    if (key.isEmpty) return null;

    final exact = content[key];
    if (exact != null) return exact;

    final targetWords = key
        .split(' ')
        .where((word) => word.length > 2)
        .toSet();
    Map<String, dynamic>? best;
    var bestScore = 0;

    for (final entry in content.entries) {
      final candidateWords = entry.key
          .split(' ')
          .where((word) => word.length > 2)
          .toSet();
      final score = targetWords.intersection(candidateWords).length;
      if (score > bestScore && score >= 2) {
        bestScore = score;
        best = entry.value;
      }
    }
    return best;
  }

  static Future<Map<String, dynamic>?> _geoapifyDetailsImage(
    Map<String, dynamic> stop,
  ) async {
    if (!GeoapifyConfig.isConfigured) return null;
    final placeId = '${stop['geoapifyPlaceId'] ?? ''}'.trim();
    if (placeId.isEmpty) return null;

    try {
      final uri = Uri.https(
        'api.geoapify.com',
        '/v2/place-details',
        {
          'id': placeId,
          'features': 'details',
          'lang': 'en',
          'apiKey': GeoapifyConfig.apiKey,
        },
      );
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return null;

      for (final rawFeature in decoded['features'] as List) {
        if (rawFeature is! Map || rawFeature['properties'] is! Map) continue;
        final properties = Map<String, dynamic>.from(
          rawFeature['properties'] as Map,
        );
        final media = properties['wiki_and_media'] is Map
            ? Map<String, dynamic>.from(
                properties['wiki_and_media'] as Map,
              )
            : const <String, dynamic>{};
        final imageUrl = _normaliseImageUrl(
          media['image'] ?? properties['image'],
        );
        if (imageUrl.isNotEmpty) {
          return {
            'imageUrl': imageUrl,
            'imageType': 'geoapify_place_photo',
            'imageAttribution': 'Geoapify / Wikimedia Commons',
          };
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _wikimediaImages(
    Map<String, dynamic> stop, {
    int limit = 3,
  }) async {
    final name = '${stop['name'] ?? ''}'.trim();
    final category = '${stop['category'] ?? ''}'.trim();
    final area = '${stop['area'] ?? 'Penang'}'.trim();
    if (name.isEmpty && category.isEmpty) return const [];

    try {
      final nameTokens = _normalize(name)
          .split(' ')
          .where((token) => token.length > 2)
          .toSet();
      final categoryTokens = _normalize(category)
          .split(' ')
          .where((token) => token.length > 2)
          .toSet();
      final searchTerms = <String>[
        if (name.isNotEmpty) '$name Penang Malaysia',
        if (name.isNotEmpty && area.isNotEmpty) '$name $area Malaysia',
        if (category.isNotEmpty) '$category Penang Malaysia heritage',
        if (category.isEmpty) 'Penang Malaysia heritage site',
      ];
      final uniqueTerms = searchTerms
          .map((term) => term.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((term) => term.isNotEmpty)
          .toSet()
          .take(3);

      final scored = <MapEntry<int, Map<String, dynamic>>>[];
      final seen = <String>{};
      for (final term in uniqueTerms) {
        final uri = Uri.https(
          'commons.wikimedia.org',
          '/w/api.php',
          {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': term,
            'gsrnamespace': '6',
            'gsrlimit': '10',
            'prop': 'imageinfo',
            'iiprop': 'url|mime',
            'iiurlwidth': '960',
            'format': 'json',
            'formatversion': '2',
            'origin': '*',
          },
        );
        final response = await http.get(
          uri,
          headers: const {
            'User-Agent':
                'MyHeritageExplorer/1.0 (university tourism project)',
          },
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map ||
            decoded['query'] is! Map ||
            (decoded['query'] as Map)['pages'] is! List) {
          continue;
        }

        final pages = List<Map<String, dynamic>>.from(
          ((decoded['query'] as Map)['pages'] as List)
              .whereType<Map>()
              .map((page) => Map<String, dynamic>.from(page)),
        );
        for (final page in pages) {
          final imageInfo = page['imageinfo'];
          if (imageInfo is! List || imageInfo.isEmpty) continue;
          final info = Map<String, dynamic>.from(imageInfo.first as Map);
          final mime = '${info['mime'] ?? ''}'.toLowerCase();
          if (!mime.startsWith('image/') ||
              mime.contains('svg') ||
              mime.contains('gif')) {
            continue;
          }

          final imageUrl = _normaliseImageUrl(info['thumburl'] ?? info['url']);
          if (imageUrl.isEmpty || !seen.add(imageUrl)) continue;

          final title = _normalize(page['title']);
          final titleTokens = title
              .split(' ')
              .where((token) => token.length > 2)
              .toSet();
          var score = nameTokens.intersection(titleTokens).length * 5;
          score += categoryTokens.intersection(titleTokens).length * 2;
          if (title.contains('penang') ||
              title.contains('george town') ||
              title.contains('pulau pinang')) {
            score += 4;
          }
          for (final unwanted in [
            'logo',
            'map',
            'diagram',
            'icon',
            'flag',
            'poster',
            'ticket',
            'menu',
            'floor plan',
          ]) {
            if (title.contains(unwanted)) score -= 10;
          }
          scored.add(
            MapEntry(score, {
            'imageUrl': _normaliseImageUrl(
              info['thumburl'] ?? info['url'],
            ),
            'imageType': 'wikimedia_place_photo',
            'imageAttribution': 'Wikimedia Commons',
            'imageSourceUrl': '${info['descriptionurl'] ?? ''}',
          }),
          );
        }
      }
      scored.sort((a, b) => b.key.compareTo(a.key));
      return scored.map((entry) => entry.value).take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, double>?> _geocodeStop(
    Map<String, dynamic> stop,
  ) async {
    if (!GeoapifyConfig.isConfigured) return null;
    final name = '${stop['name'] ?? ''}'.trim();
    final address =
        '${stop['formattedAddress'] ?? stop['address'] ?? ''}'.trim();
    final area = '${stop['area'] ?? 'Penang'}'.trim();
    if (name.isEmpty) return null;

    try {
      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/search',
        {
          'text': [
            name,
            if (address.isNotEmpty) address,
            area,
            'Penang',
            'Malaysia',
          ].join(', '),
          'filter': 'countrycode:my',
          'bias': 'proximity:100.3327,5.4141',
          'limit': '5',
          'format': 'json',
          'apiKey': GeoapifyConfig.apiKey,
        },
      );
      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['results'] is! List) return null;

      final results = List<Map<String, dynamic>>.from(
        (decoded['results'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item)),
      );
      if (results.isEmpty) return null;

      Map<String, dynamic>? selected;
      for (final result in results) {
        final searchable = [
          result['formatted'],
          result['state'],
          result['county'],
          result['city'],
        ].join(' ').toLowerCase();
        if (searchable.contains('penang') ||
            searchable.contains('pulau pinang')) {
          selected = result;
          break;
        }
      }
      selected ??= results.first;
      final latitude = selected['lat'];
      final longitude = selected['lon'];
      if (latitude is! num || longitude is! num) return null;
      return {
        'latitude': latitude.toDouble(),
        'longitude': longitude.toDouble(),
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> resolveStop(
    Map<String, dynamic> original,
  ) {
    final cacheKey = '${original['placeId'] ?? ''}|'
        '${original['geoapifyPlaceId'] ?? ''}|'
        '${_normalize(original['name'])}';

    final resolved = _stopCache.putIfAbsent(cacheKey, () async {
      final stop = Map<String, dynamic>.from(original);
      final photoCandidates = <String>[];
      final mapCandidates = <String>[];
      final onlineImageCandidates = <Map<String, dynamic>>[];

      final originalImageType = '${stop['imageType'] ?? ''}'.toLowerCase();
      final existingCandidates = _uniqueUrls([
        stop['imageUrl'],
        stop['photoUrl'],
        stop['thumbnailUrl'],
        stop['wikiImageUrl'],
      ]);
      for (final url in existingCandidates) {
        if (originalImageType == 'map_preview' || _isStaticMapUrl(url)) {
          mapCandidates.add(url);
        } else {
          photoCandidates.add(url);
        }
      }

      final content = await _loadPlaceContent();
      final placeContent = _matchPlaceContent(
        content,
        '${stop['name'] ?? ''}',
      );
      final curatedImage = _normaliseImageUrl(placeContent?['imageUrl']);
      if (curatedImage.isNotEmpty && !photoCandidates.contains(curatedImage)) {
        photoCandidates.add(curatedImage);
      }

      final geoapifyImage = await _geoapifyDetailsImage(stop);
      final geoapifyUrl = _normaliseImageUrl(geoapifyImage?['imageUrl']);
      if (geoapifyUrl.isNotEmpty && !photoCandidates.contains(geoapifyUrl)) {
        photoCandidates.add(geoapifyUrl);
      }

      final needsOnlineFallback =
          photoCandidates.isEmpty || photoCandidates.length < 3;
      if (needsOnlineFallback) {
        final commonsImages = await _wikimediaImages(stop);
        for (final commons in commonsImages) {
          final commonsUrl = _normaliseImageUrl(commons['imageUrl']);
          if (commonsUrl.isNotEmpty && !photoCandidates.contains(commonsUrl)) {
            photoCandidates.add(commonsUrl);
            onlineImageCandidates.add(commons);
          }
        }
      }

      var coordinates = coordinatesFor(stop);
      coordinates ??= await _geocodeStop(stop);
      if (coordinates != null) {
        final generatedMap = staticMapPreview(
          latitude: coordinates['latitude']!,
          longitude: coordinates['longitude']!,
        );
        if (generatedMap.isNotEmpty) mapCandidates.insert(0, generatedMap);
      }

      for (final url in _uniqueUrls([
        stop['fallbackImageUrl'],
        stop['mapPreviewUrl'],
      ])) {
        if (!mapCandidates.contains(url)) mapCandidates.add(url);
      }

      final allCandidates = <String>[
        ...photoCandidates,
        ...mapCandidates,
      ];
      final primary = allCandidates.isEmpty ? '' : allCandidates.first;
      final fallback = mapCandidates.isEmpty ? '' : mapCandidates.first;

      final resolvedStop = {
        ...stop,
        if (primary.isNotEmpty) 'imageUrl': primary,
        if (fallback.isNotEmpty) 'fallbackImageUrl': fallback,
        if (fallback.isNotEmpty) 'mapPreviewUrl': fallback,
        'imageCandidates': allCandidates,
        'imageType': photoCandidates.isNotEmpty
            ? '${geoapifyImage?['imageType'] ??
                placeContent?['imageType'] ??
                (onlineImageCandidates.isNotEmpty
                    ? onlineImageCandidates.first['imageType']
                    : stop['imageType']) ??
                'place_photo'}'
            : fallback.isNotEmpty
                ? 'map_preview'
                : '${stop['imageType'] ?? ''}',
        if ('${placeContent?['imageAttribution'] ?? ''}'.isNotEmpty)
          'imageAttribution': placeContent?['imageAttribution'],
        if ('${placeContent?['imageSourceUrl'] ?? ''}'.isNotEmpty)
          'imageSourceUrl': placeContent?['imageSourceUrl'],
      };
      if (coordinates != null) resolvedStop['location'] = coordinates;
      return resolvedStop;
    });
    return resolved.then((value) => _withLatestStopFields(value, original));
  }

  static List<String> imageCandidatesFor(
    Map<String, dynamic> stop,
  ) {
    return _uniqueUrls([
      ...List<Object?>.from(
        stop['imageCandidates'] ?? const <Object?>[],
      ),
      stop['imageUrl'],
      stop['fallbackImageUrl'],
      stop['mapPreviewUrl'],
    ]);
  }

  static Future<Map<String, dynamic>> resolveAndPrecache(
    BuildContext context,
    Map<String, dynamic> stop,
  ) async {
    final resolved = await resolveStop(stop);
    final candidates = imageCandidatesFor(resolved);
    if (!context.mounted) return resolved;

    for (final candidate in candidates.take(5)) {
      var failed = false;

      try {
        await precacheImage(
          NetworkImage(
            candidate,
            headers: const {
              'Accept':
                  'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              'User-Agent':
                  'MyHeritageExplorer/1.0 (Flutter university tourism project)',
            },
          ),
          context,
          onError: (error, stackTrace) {
            failed = true;
          },
        ).timeout(const Duration(seconds: 12));
      } catch (_) {
        failed = true;
      }
      if (!failed) {
        return {
          ...resolved,
          'imageUrl': candidate,
          'imageCandidates': [
            candidate,
            ...candidates.where((url) => url != candidate),
          ],
        };
      }
    }

    return resolved;
  }

  static void invalidateStop(Map<String, dynamic> stop) {
    final cacheKey = '${stop['placeId'] ?? ''}|'
        '${stop['geoapifyPlaceId'] ?? ''}|'
        '${_normalize(stop['name'])}';
    _stopCache.remove(cacheKey);
  }

  static void clearCache() {
    _stopCache.clear();
    _contentCache = null;
  }
}

class ItineraryPlaceImage extends StatelessWidget {
  const ItineraryPlaceImage({
    super.key,
    required this.stop,
    this.width,
    this.height = 82,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final Map<String, dynamic> stop;
  final double? width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ItineraryImageResolver.resolveStop(stop),
      builder: (context, snapshot) {
        final resolved = snapshot.data ?? stop;
        final candidates = _uniqueCandidateList(resolved);
        Widget child;

        if (snapshot.connectionState == ConnectionState.waiting &&
            candidates.isEmpty) {
          child = _ItineraryImageLoading(
            width: width,
            height: height,
          );
        } else {
          child = _ItineraryCandidateImage(
            candidates: candidates,
            placeName: '${resolved['name'] ?? 'Place'}',
            category: '${resolved['category'] ?? 'Place'}',
            width: width,
            height: height,
            fit: fit,
          );
        }

        if (borderRadius == null) return child;
        return ClipRRect(borderRadius: borderRadius!, child: child);
      },
    );
  }

  static List<String> _uniqueCandidateList(Map<String, dynamic> stop) {
    final imageCand = stop['imageCandidates'];
    final raw = <Object?>[
      if (imageCand is List)
        ...imageCand
      else if (imageCand != null)
        imageCand,
      stop['imageUrl'],
      stop['fallbackImageUrl'],
      stop['mapPreviewUrl'],
    ];
    final result = <String>[];
    final seen = <String>{};
    for (final value in raw) {
      final url = '${value ?? ''}'.trim();
      if (!ItineraryImageResolver._isNetworkUrl(url) || !seen.add(url)) {
        continue;
      }
      result.add(url);
    }
    return result;
  }
}

class _ItineraryCandidateImage extends StatefulWidget {
  const _ItineraryCandidateImage({
    required this.candidates,
    required this.placeName,
    required this.category,
    required this.width,
    required this.height,
    required this.fit,
  });

  final List<String> candidates;
  final String placeName;
  final String category;
  final double? width;
  final double height;
  final BoxFit fit;

  @override
  State<_ItineraryCandidateImage> createState() =>
      _ItineraryCandidateImageState();
}

class _ItineraryCandidateImageState
    extends State<_ItineraryCandidateImage> {
  int index = 0;

  @override
  void didUpdateWidget(covariant _ItineraryCandidateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates.join('|') != widget.candidates.join('|')) {
      index = 0;
    }
  }

  void _useNextCandidate() {
    if (index + 1 >= widget.candidates.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => index += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty || index >= widget.candidates.length) {
      return _ItineraryVisualFallback(
        placeName: widget.placeName,
        category: widget.category,
        width: widget.width,
        height: widget.height,
      );
    }

    return Image.network(
      widget.candidates[index],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _ItineraryImageLoading(
          width: widget.width,
          height: widget.height,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (index + 1 < widget.candidates.length) {
          _useNextCandidate();
          return _ItineraryImageLoading(
            width: widget.width,
            height: widget.height,
          );
        }
        return _ItineraryVisualFallback(
          placeName: widget.placeName,
          category: widget.category,
          width: widget.width,
          height: widget.height,
        );
      },
    );
  }
}

class _ItineraryImageLoading extends StatelessWidget {
  const _ItineraryImageLoading({
    required this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: ExplorerColors.navySoft,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ItineraryVisualFallback extends StatelessWidget {
  const _ItineraryVisualFallback({
    required this.placeName,
    required this.category,
    required this.width,
    required this.height,
  });

  final String placeName;
  final String category;
  final double? width;
  final double height;

  IconData get icon {
    final value = category.toLowerCase();
    if (value.contains('food') || value.contains('restaurant')) {
      return Icons.restaurant_outlined;
    }
    if (value.contains('nature') || value.contains('park')) {
      return Icons.park_outlined;
    }
    if (value.contains('art')) return Icons.palette_outlined;
    if (value.contains('heritage') || value.contains('culture')) {
      return Icons.account_balance_outlined;
    }
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ExplorerColors.navySoft, ExplorerColors.goldSoft],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ExplorerColors.navy, size: 30),
          const SizedBox(height: 7),
          Text(
            placeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
