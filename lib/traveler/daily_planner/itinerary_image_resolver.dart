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
        lower.contains('staticmap') ||
        lower.contains('openstreetmap.org') ||
        lower.contains('tile.openstreetmap');
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

  static List<String> _uniqueUrls(Iterable<Object?> values, {bool allowMapPreview = false}) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final url = _normaliseImageUrl(value);
      if (url.isEmpty || !seen.add(url)) continue;
      if (!allowMapPreview && _isStaticMapUrl(url)) continue;
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
    ]);

    if (candidates.isNotEmpty) return candidates.first;

    final curated = _matchCuratedImage('${stop['name'] ?? ''}');
    if (curated != null && curated.isNotEmpty) return curated;

    return categoryFallbackPhoto(stop);
  }

  // =========================================================================
  // CURATED HIGH-RESOLUTION UNIQUE PLACE IMAGES (PENANG & MALAYSIA)
  // =========================================================================
  static const Map<String, String> _curatedPlaceImages = {
    // 1. Heritage & Mansions (George Town & Penang)
    'pinang peranakan mansion':
        'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
    'peranakan mansion':
        'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
    'cheong fatt tze the blue mansion':
        'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?auto=format&fit=crop&w=900&q=80',
    'blue mansion':
        'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?auto=format&fit=crop&w=900&q=80',
    'the blue mansion':
        'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?auto=format&fit=crop&w=900&q=80',
    'leong san tong khoo kongsi':
        'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=900&q=80',
    'khoo kongsi':
        'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=900&q=80',
    'wonderfood museum penang':
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
    'wonderfood museum':
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
    'fort cornwallis':
        'https://images.unsplash.com/photo-1599839575945-a9e5af0c3fa5?auto=format&fit=crop&w=900&q=80',
    'chew jetty':
        'https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=900&q=80',
    'tan jetty long wooden pier':
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=900&q=80',
    'tan jetty':
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=900&q=80',
    'lim jetty':
        'https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=900&q=80',
    'lee jetty':
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=900&q=80',
    'hin bus depot':
        'https://images.unsplash.com/photo-1561214115-f2f134cc4912?auto=format&fit=crop&w=900&q=80',
    'penang street art armenian street murals':
        'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=900&q=80',
    'penang street art':
        'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=900&q=80',
    'armenian street':
        'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=900&q=80',
    'sun yat sen museum penang':
        'https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?auto=format&fit=crop&w=900&q=80',
    'sun yat sen museum':
        'https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?auto=format&fit=crop&w=900&q=80',
    'penang state museum art gallery':
        'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=900&q=80',
    'penang state museum':
        'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=900&q=80',
    'suffolk house georgian heritage mansion':
        'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=900&q=80',
    'suffolk house':
        'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=900&q=80',
    'penang war museum batu maung':
        'https://images.unsplash.com/photo-1541872703-74c5e44368f9?auto=format&fit=crop&w=900&q=80',
    'penang war museum':
        'https://images.unsplash.com/photo-1541872703-74c5e44368f9?auto=format&fit=crop&w=900&q=80',
    'penang batik factory':
        'https://images.unsplash.com/photo-1606744824163-985d376605aa?auto=format&fit=crop&w=900&q=80',

    // 2. Religious & Spiritual Landmarks
    'kek lok si temple':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=900&q=80',
    'kek lok si':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=900&q=80',
    'dhammikarama burmese temple':
        'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=900&q=80',
    'burmese temple':
        'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=900&q=80',
    'wat chayamangkalaram reclining buddha':
        'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=900&q=80',
    'wat chayamangkalaram':
        'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=900&q=80',
    'st georges anglican church':
        'https://images.unsplash.com/photo-1548625361-16a7f9202758?auto=format&fit=crop&w=900&q=80',
    'st georges church':
        'https://images.unsplash.com/photo-1548625361-16a7f9202758?auto=format&fit=crop&w=900&q=80',
    'kapitan keling mosque':
        'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=900&q=80',
    'sri mahamariamman temple queen street':
        'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?auto=format&fit=crop&w=900&q=80',
    'sri mahamariamman temple':
        'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?auto=format&fit=crop&w=900&q=80',
    'snake temple ban ka lan temple':
        'https://images.unsplash.com/photo-1577717903315-1691ae25ab3f?auto=format&fit=crop&w=900&q=80',
    'snake temple':
        'https://images.unsplash.com/photo-1577717903315-1691ae25ab3f?auto=format&fit=crop&w=900&q=80',
    'tanjung bungah floating mosque':
        'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=900&q=80',
    'floating mosque':
        'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=900&q=80',
    'minor basilica of st anne':
        'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=900&q=80',
    'st anne bukit mertajam':
        'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=900&q=80',
    'tow boo kong temple butterworth':
        'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?auto=format&fit=crop&w=900&q=80',

    // 3. Nature, Parks & Attractions
    'the habitat penang hill':
        'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=900&q=80',
    'the habitat':
        'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=900&q=80',
    'tropical spice garden':
        'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&w=900&q=80',
    'entopia by penang butterfly farm':
        'https://images.unsplash.com/photo-1535083783855-76ae62b2914e?auto=format&fit=crop&w=900&q=80',
    'entopia':
        'https://images.unsplash.com/photo-1535083783855-76ae62b2914e?auto=format&fit=crop&w=900&q=80',
    'escape penang':
        'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=900&q=80',
    'escape theme park':
        'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=900&q=80',
    'batu ferringhi night market':
        'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=900&q=80',
    'cherok tokun nature park':
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=900&q=80',
    'cherok tokun':
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=900&q=80',
    'mengkuang dam lakeside park':
        'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=900&q=80',
    'mengkuang dam':
        'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=900&q=80',
    'penang bird park':
        'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=900&q=80',
    'butterworth art walk':
        'https://images.unsplash.com/photo-1499781350541-7783f6c6a0c8?auto=format&fit=crop&w=900&q=80',
    'penang national park taman negara pulau pinang':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
    'penang national park':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
    'balik pulau goat farm nutmeg factory':
        'https://images.unsplash.com/photo-1500595046743-cd271d694d30?auto=format&fit=crop&w=900&q=80',
    'karpal singh drive promenade':
        'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=900&q=80',
    'karpal singh drive':
        'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=900&q=80',
    'frog hill bukit katak scenic lake':
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80',
    'frog hill':
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80',

    // 4. George Town Food & Institutions
    'jawi house cafe gallery':
        'https://images.unsplash.com/photo-1552611052-33e04de081de?auto=format&fit=crop&w=900&q=80',
    'chinahouse penang':
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80',
    'chinahouse':
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80',
    'tek sen restaurant':
        'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=80',
    'tek sen':
        'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=80',
    'hameediyah restaurant':
        'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=900&q=80',
    'hameediyah':
        'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=900&q=80',
    'penang road famous teochew chendul':
        'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=900&q=80',
    'teochew chendul':
        'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=900&q=80',
    'ghee hiang macalister road':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=900&q=80',
    'ghee hiang':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=900&q=80',
    'chowrasta market':
        'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=900&q=80',
    'gurney drive hawker centre':
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=900&q=80',
    'air itam asam laksa pasar air itam':
        'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80',
    'air itam asam laksa':
        'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80',
    'siam road charcoal char koay teow':
        'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=900&q=80',
    'siam road char koay teow':
        'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=900&q=80',
    'deen maju nasi kandar':
        'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?auto=format&fit=crop&w=900&q=80',
    'transfer road roti canai roti bakar':
        'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=900&q=80',
    'transfer road roti canai':
        'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=900&q=80',
    'line clear nasi kandar chulia street':
        'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9?auto=format&fit=crop&w=900&q=80',
    'line clear nasi kandar':
        'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9?auto=format&fit=crop&w=900&q=80',
    'balik pulau famous kim laksa':
        'https://images.unsplash.com/photo-1617093727343-374698b1b08d?auto=format&fit=crop&w=900&q=80',
    'raja uda apollo morning market':
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',

    // 5. Bukit Mertajam Food Spots
    'restoran bm yam rice':
        'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=900&q=80',
    'bm yam rice':
        'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=900&q=80',
    'restoran bm cup rice danby cup rice':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=900&q=80',
    'bm cup rice':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=900&q=80',
    'bm famous duck egg char koay teow':
        'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=900&q=80',
    'bm rojak orang hitam putih':
        'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=900&q=80',
    'cheok toi mee jawa bm':
        'https://images.unsplash.com/photo-1557872943-16a5ac26437e?auto=format&fit=crop&w=900&q=80',
    'restoran mei le hwa bm dim sum':
        'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?auto=format&fit=crop&w=900&q=80',
    'bm famous lao hao you curry mee':
        'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=900&q=80',
    'sentosa food court bm':
        'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?auto=format&fit=crop&w=900&q=80',
    'taman sri rambai hawker centre':
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
    'bm famous hakka mee yong tau foo':
        'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=900&q=80',
    'bm best cendol shaved ice':
        'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?auto=format&fit=crop&w=900&q=80',
    'restoran nasi kandar yasmeen bm':
        'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=900&q=80',
    'bm traditional ban chang kuih':
        'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=900&q=80',
    'de antique cafe bm':
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
    'restoran tokun jaya kopitiam':
        'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=900&q=80',
    'pekan bukit mertajam old market street':
        'https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=900&q=80',

    // 6. Kuala Lumpur & Selangor
    'central market pasar seni':
        'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=900&q=80',
    'petaling street heritage market':
        'https://images.unsplash.com/photo-1511884642898-4c92249e20b6?auto=format&fit=crop&w=900&q=80',
    'batu caves lord murugan shrine':
        'https://images.unsplash.com/photo-1580837119756-563d608dd119?auto=format&fit=crop&w=900&q=80',
    'sultan salahuddin abdul aziz mosque blue mosque':
        'https://images.unsplash.com/photo-1565552645632-d725f8bfc19a?auto=format&fit=crop&w=900&q=80',
    'chong kok kopitiam klang':
        'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=900&q=80',
    'sultan abdul aziz royal gallery':
        'https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7?auto=format&fit=crop&w=900&q=80',
    'sekinchan paddy processing gallery':
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=900&q=80',
    'bukit melawati historical park':
        'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=900&q=80',
    'sultan abdul samad building dataran merdeka':
        'https://images.unsplash.com/photo-1549144511-f099e773c147?auto=format&fit=crop&w=900&q=80',
    'national textile museum kl':
        'https://images.unsplash.com/photo-1578925518470-4def7a0f08bb?auto=format&fit=crop&w=900&q=80',

    // 7. Melaka
    'dutch square the stadthuys':
        'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&w=900&q=80',
    'a famosa fortress':
        'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=900&q=80',
    'baba nyonya heritage museum':
        'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=900&q=80',

    // 8. Sabah & Sarawak
    'mari mari cultural village':
        'https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=900&q=80',
    'kota kinabalu handicraft market filipino market':
        'https://images.unsplash.com/photo-1528698827591-e19ccd7bc23d?auto=format&fit=crop&w=900&q=80',
    'desa cattle dairy farm kundasang':
        'https://images.unsplash.com/photo-1516467508483-a7212febe31a?auto=format&fit=crop&w=900&q=80',
    'sepilok orangutan rehabilitation centre':
        'https://images.unsplash.com/photo-1540573133985-87b6da6d54a9?auto=format&fit=crop&w=900&q=80',
    'borneo cultures museum kuching':
        'https://images.unsplash.com/photo-1518998053901-5348d3961a04?auto=format&fit=crop&w=900&q=80',
    'sarawak cultural village living museum':
        'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=900&q=80',
    'kuching waterfront darul hana bridge':
        'https://images.unsplash.com/photo-1508873696983-2df5293cb32f?auto=format&fit=crop&w=900&q=80',
    'siniawan old town night market':
        'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?auto=format&fit=crop&w=900&q=80',

    // 9. Perak & Johor
    'concubine lane ipoh old town':
        'https://images.unsplash.com/photo-1524850011238-e3d235c7d4c9?auto=format&fit=crop&w=900&q=80',
    'kek lok tong cave temple zen gardens':
        'https://images.unsplash.com/photo-1516214104703-d870798883c5?auto=format&fit=crop&w=900&q=80',
    'taiping lake gardens taman tasik taiping':
        'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?auto=format&fit=crop&w=900&q=80',
    'masjid ubudiah kuala kangsar':
        'https://images.unsplash.com/photo-1564769625905-50e93615e769?auto=format&fit=crop&w=900&q=80',
    'hiap joo bakery biscuit factory':
        'https://images.unsplash.com/photo-1586985289688-ca3cf47d3e6e?auto=format&fit=crop&w=900&q=80',
    'sai kee 434 kopi muar':
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=900&q=80',

    // 10. Kedah & Pahang
    'langkawi skybridge cable car':
        'https://images.unsplash.com/photo-1509233725247-49e657c54213?auto=format&fit=crop&w=900&q=80',
    'makam mahsuri cultural sanctuary':
        'https://images.unsplash.com/photo-1528181304800-259b08848526?auto=format&fit=crop&w=900&q=80',
    'masjid zahir alor setar':
        'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?auto=format&fit=crop&w=900&q=80',
    'kuantan 188 tower waterfront':
        'https://images.unsplash.com/photo-1477959858617-67f30bc75b82?auto=format&fit=crop&w=900&q=80',
    'restoran ana ikan bakar petai':
        'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=900&q=80',
    'teluk cempedak coastal promenade':
        'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?auto=format&fit=crop&w=900&q=80',
    'sungai lembing historic underground tin mines':
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=900&q=80',

    // 11. Terengganu & Kelantan
    'pasar payang central heritage market':
        'https://images.unsplash.com/photo-1534723452862-4c874018d66d?auto=format&fit=crop&w=900&q=80',
    'masjid kristal crystal mosque':
        'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=900&q=80',
    'restoran nasi dagang atas tol':
        'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=900&q=80',
    'kampung cina chinatown kuala terengganu':
        'https://images.unsplash.com/photo-1518481612222-68bbe828ecd1?auto=format&fit=crop&w=900&q=80',
    'keropok lekor losong btb 220':
        'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=900&q=80',
    'pasar besar siti khadijah':
        'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=900&q=80',
    'istana jahar museum of royal traditions customs':
        'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=900&q=80',
    'restoran nasi ulam cikgu':
        'https://images.unsplash.com/photo-1543353071-873f17a7a088?auto=format&fit=crop&w=900&q=80',
    'kopitiam kita famous roti titab':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80',
    'wat phothivihan giant reclining buddha':
        'https://images.unsplash.com/photo-1528728329032-2972f65dfb3f?auto=format&fit=crop&w=900&q=80',
  };

  // =========================================================================
  // DIVERSE HIGH-RESOLUTION CATEGORY PHOTO POOLS (AVOIDS DUPLICATES)
  // =========================================================================
  static const Map<String, List<String>> _categoryPhotoPools = {
    'heritage': [
      'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1599839575945-a9e5af0c3fa5?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1548625361-16a7f9202758?auto=format&fit=crop&w=900&q=80',
    ],
    'culture': [
      'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1606744824163-985d376605aa?auto=format&fit=crop&w=900&q=80',
    ],
    'food': [
      'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=900&q=80',
    ],
    'nature': [
      'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1535083783855-76ae62b2914e?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1552728089-57bdde30beb3?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1500595046743-cd271d694d30?auto=format&fit=crop&w=900&q=80',
    ],
    'art': [
      'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1561214115-f2f134cc4912?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1606744824163-985d376605aa?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=900&q=80',
    ],
    'retail': [
      'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',
    ],
  };

  static String? _matchCuratedImage(String placeName) {
    final key = _normalize(placeName);
    if (key.isEmpty) return null;

    final exact = _curatedPlaceImages[key];
    if (exact != null) return exact;

    for (final entry in _curatedPlaceImages.entries) {
      if (entry.key == key) {
        return entry.value;
      }
      if (key.length >= 8 &&
          (key.startsWith(entry.key) || entry.key.startsWith(key))) {
        return entry.value;
      }
    }
    return null;
  }

  static String categoryFallbackPhoto(Map<String, dynamic> stop) {
    final name = '${stop['name'] ?? ''}';
    final category = '${stop['category'] ?? stop['businessCategory'] ?? 'Heritage'}'.toLowerCase();
    final area = '${stop['area'] ?? ''}';

    String poolKey = 'heritage';
    if (category.contains('food') || category.contains('dining') || category.contains('restaurant') || category.contains('cafe')) {
      poolKey = 'food';
    } else if (category.contains('nature') || category.contains('park') || category.contains('beach') || category.contains('garden')) {
      poolKey = 'nature';
    } else if (category.contains('art') || category.contains('gallery') || category.contains('mural')) {
      poolKey = 'art';
    } else if (category.contains('culture') || category.contains('museum')) {
      poolKey = 'culture';
    } else if (category.contains('retail') || category.contains('market') || category.contains('shop')) {
      poolKey = 'retail';
    }

    final pool = _categoryPhotoPools[poolKey] ?? _categoryPhotoPools['heritage']!;
    final hashSeed = _normalize('$name $area $category');
    final hashIndex = hashSeed.hashCode.abs() % pool.length;
    return pool[hashIndex];
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
        if (imageUrl.isNotEmpty && !_isStaticMapUrl(imageUrl)) {
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
    final area = '${stop['area'] ?? 'Penang'}'.trim();
    if (name.isEmpty) return const [];

    try {
      final nameTokens = _normalize(name)
          .split(' ')
          .where((token) => token.length > 2)
          .toSet();
      if (nameTokens.isEmpty) return const [];

      final searchTerms = <String>[
        '$name Penang Malaysia',
        if (area.isNotEmpty && !name.toLowerCase().contains(area.toLowerCase()))
          '$name $area Malaysia',
        '$name Malaysia',
      ];
      final uniqueTerms = searchTerms
          .map((term) => term.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((term) => term.isNotEmpty)
          .toSet()
          .take(2);

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
            'gsrlimit': '8',
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
          if (imageUrl.isEmpty || _isStaticMapUrl(imageUrl) || !seen.add(imageUrl)) {
            continue;
          }

          final title = _normalize(page['title']);
          final titleTokens = title
              .split(' ')
              .where((token) => token.length > 2)
              .toSet();
          final intersection = nameTokens.intersection(titleTokens);
          if (intersection.isEmpty) continue;

          var score = intersection.length * 6;
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
          if (score >= 6) {
            scored.add(
              MapEntry(score, {
                'imageUrl': imageUrl,
                'imageType': 'wikimedia_place_photo',
                'imageAttribution': 'Wikimedia Commons',
                'imageSourceUrl': '${info['descriptionurl'] ?? ''}',
              }),
            );
          }
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
      ], allowMapPreview: true);

      for (final url in existingCandidates) {
        if (originalImageType == 'map_preview' || _isStaticMapUrl(url)) {
          mapCandidates.add(url);
        } else {
          photoCandidates.add(url);
        }
      }

      // 1. Direct Curated Place Photo Lookup
      final curatedMatch = _matchCuratedImage('${stop['name'] ?? ''}');
      if (curatedMatch != null && curatedMatch.isNotEmpty && !photoCandidates.contains(curatedMatch)) {
        photoCandidates.add(curatedMatch);
      }

      // 2. Firestore Place Content
      final content = await _loadPlaceContent();
      final placeContent = _matchPlaceContent(
        content,
        '${stop['name'] ?? ''}',
      );
      final curatedImage = _normaliseImageUrl(placeContent?['imageUrl']);
      if (curatedImage.isNotEmpty &&
          !_isStaticMapUrl(curatedImage) &&
          !photoCandidates.contains(curatedImage)) {
        photoCandidates.add(curatedImage);
      }

      // 3. Geoapify Place Details Photo
      final geoapifyImage = await _geoapifyDetailsImage(stop);
      final geoapifyUrl = _normaliseImageUrl(geoapifyImage?['imageUrl']);
      if (geoapifyUrl.isNotEmpty &&
          !_isStaticMapUrl(geoapifyUrl) &&
          !photoCandidates.contains(geoapifyUrl)) {
        photoCandidates.add(geoapifyUrl);
      }

      // 4. Exact Wikimedia Commons Search
      if (photoCandidates.isEmpty) {
        final commonsImages = await _wikimediaImages(stop);
        for (final commons in commonsImages) {
          final commonsUrl = _normaliseImageUrl(commons['imageUrl']);
          if (commonsUrl.isNotEmpty &&
              !_isStaticMapUrl(commonsUrl) &&
              !photoCandidates.contains(commonsUrl)) {
            photoCandidates.add(commonsUrl);
            onlineImageCandidates.add(commons);
          }
        }
      }

      // 5. Category-Specific High-Resolution Fallback Photo Pool
      if (photoCandidates.isEmpty) {
        final categoryFallback = categoryFallbackPhoto(stop);
        if (categoryFallback.isNotEmpty) {
          photoCandidates.add(categoryFallback);
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
      ], allowMapPreview: true)) {
        if (!mapCandidates.contains(url)) mapCandidates.add(url);
      }

      final primary = photoCandidates.isNotEmpty ? photoCandidates.first : '';
      final fallbackMap = mapCandidates.isNotEmpty ? mapCandidates.first : '';

      final resolvedStop = {
        ...stop,
        if (primary.isNotEmpty) 'imageUrl': primary,
        if (fallbackMap.isNotEmpty) 'fallbackImageUrl': fallbackMap,
        if (fallbackMap.isNotEmpty) 'mapPreviewUrl': fallbackMap,
        'imageCandidates': photoCandidates,
        'imageType': photoCandidates.isNotEmpty ? 'place_photo' : 'map_preview',
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
    final list = _uniqueUrls([
      ...List<Object?>.from(
        stop['imageCandidates'] ?? const <Object?>[],
      ),
      stop['imageUrl'],
      stop['fallbackImageUrl'],
      stop['mapPreviewUrl'],
    ], allowMapPreview: true);

    if (list.isEmpty) {
      final fallback = categoryFallbackPhoto(stop);
      if (fallback.isNotEmpty) list.add(fallback);
    }
    return list;
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
            stop: resolved,
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
      stop['photoUrl'],
      stop['thumbnailUrl'],
      stop['wikiImageUrl'],
    ];
    final result = <String>[];
    final seen = <String>{};
    for (final value in raw) {
      final url = '${value ?? ''}'.trim();
      if (!ItineraryImageResolver._isNetworkUrl(url) ||
          ItineraryImageResolver._isStaticMapUrl(url) ||
          !seen.add(url)) {
        continue;
      }
      result.add(url);
    }
    if (result.isEmpty) {
      final curated = ItineraryImageResolver._matchCuratedImage('${stop['name'] ?? ''}');
      if (curated != null && curated.isNotEmpty) {
        result.add(curated);
      } else {
        final fallback = ItineraryImageResolver.categoryFallbackPhoto(stop);
        if (fallback.isNotEmpty) result.add(fallback);
      }
    }
    return result;
  }
}

class _ItineraryCandidateImage extends StatefulWidget {
  const _ItineraryCandidateImage({
    required this.candidates,
    required this.placeName,
    required this.category,
    required this.stop,
    required this.width,
    required this.height,
    required this.fit,
  });

  final List<String> candidates;
  final String placeName;
  final String category;
  final Map<String, dynamic> stop;
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
      final fallbackUrl = ItineraryImageResolver.categoryFallbackPhoto(widget.stop);
      if (fallbackUrl.isNotEmpty) {
        return Image.network(
          fallbackUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _ItineraryVisualFallback(
            placeName: widget.placeName,
            category: widget.category,
            width: widget.width,
            height: widget.height,
          ),
        );
      }
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
        final fallbackUrl = ItineraryImageResolver.categoryFallbackPhoto(widget.stop);
        if (fallbackUrl.isNotEmpty && fallbackUrl != widget.candidates[index]) {
          return Image.network(
            fallbackUrl,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _ItineraryVisualFallback(
              placeName: widget.placeName,
              category: widget.category,
              width: widget.width,
              height: widget.height,
            ),
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
