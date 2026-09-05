import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services.dart';
import '../models/place_model.dart';
import 'malaysia_location_service.dart';

class PlaceRepository {
  static final Map<String, List<PlaceModel>> _statePlacesCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _ttl = Duration(minutes: 5);

  /// Clear repository cache
  static void clearCache() {
    _statePlacesCache.clear();
    _cacheTime.clear();
  }

  /// Load places from Firestore 'places' collection for a given state
  static Future<List<PlaceModel>> getPlacesForState(
    String stateId, {
    bool forceRefresh = false,
  }) async {
    final normStateId = stateId.toLowerCase().trim();
    final normStateName = MalaysiaLocationService.getStateName(normStateId).toLowerCase();

    if (!forceRefresh &&
        _statePlacesCache.containsKey(normStateId) &&
        _cacheTime.containsKey(normStateId) &&
        DateTime.now().difference(_cacheTime[normStateId]!) < _ttl) {
      return _statePlacesCache[normStateId]!;
    }

    List<PlaceModel> results = [];

    try {
      // 1. Query Firestore 'places' collection
      final placesSnap = await AppServices.db.collection('places').get();

      for (final doc in placesSnap.docs) {
        final place = PlaceModel.fromFirestore(doc);
        if (!place.isActive) continue;

        final pStateId = place.stateId.toLowerCase().trim();
        final pStateName = place.stateName.toLowerCase().trim();

        // Strictly check that place belongs to the selected state
        if (pStateId == normStateId ||
            pStateName == normStateName ||
            pStateName == normStateId ||
            pStateId == normStateName) {
          results.add(place);
        }
      }

      // 2. Query Firestore 'vendors' collection for active registered vendors in same state
      try {
        final vendorsSnap = await AppServices.db.collection('vendors').get();
        for (final doc in vendorsSnap.docs) {
          final data = doc.data();
          if (data['status'] != null && data['status'] != 'active') continue;

          final vState = '${data['state'] ?? data['stateName'] ?? ''}'.toLowerCase().trim();
          final vAddress = '${data['address'] ?? data['formattedAddress'] ?? data['area'] ?? ''}'.toLowerCase();

          bool stateMatch = vState == normStateId || vState == normStateName;
          if (!stateMatch && (vAddress.contains(normStateName) || vAddress.contains(normStateId))) {
            stateMatch = true;
          }

          if (stateMatch) {
            final vendorPlace = PlaceModel.fromMap('vendor_${doc.id}', {
              ...data,
              'vendorId': doc.id,
              'stateId': normStateId,
              'stateName': MalaysiaLocationService.getStateName(normStateId),
              'trustLabel': 'Verified Vendor',
            });
            // Avoid duplicate vendor names
            if (!results.any((p) => p.name.toLowerCase() == vendorPlace.name.toLowerCase())) {
              results.add(vendorPlace);
            }
          }
        }
      } catch (_) {
        // Vendors collection optional
      }
    } catch (_) {
      // Firestore query failed or empty
    }

    _statePlacesCache[normStateId] = results;
    _cacheTime[normStateId] = DateTime.now();
    return results;
  }

  /// Search places for adding in edit itinerary screen strictly for a given state
  static Future<List<PlaceModel>> searchPlacesForAdding({
    required String stateId,
    String area = '',
    List<String> interests = const [],
    String query = '',
    List<String> excludedPlaceIds = const [],
  }) async {
    final allPlaces = await getPlacesForState(stateId);
    final excludedSet = excludedPlaceIds.toSet();
    final qLower = query.toLowerCase().trim();
    final areaLower = area.toLowerCase().trim();

    return allPlaces.where((place) {
      if (excludedSet.contains(place.placeId)) return false;

      // Filter by search query if provided
      if (qLower.isNotEmpty) {
        final searchable = '${place.name} ${place.category} ${place.area} ${place.description} ${place.interestTags.join(" ")}'.toLowerCase();
        if (!searchable.contains(qLower)) return false;
      }

      // If area is specified and no text query, prioritize same area / state
      if (areaLower.isNotEmpty && qLower.isEmpty && interests.isNotEmpty) {
        final matchesInterest = place.interestTags.any((t) => interests.any((i) => i.toLowerCase() == t.toLowerCase())) ||
            interests.any((i) => i.toLowerCase() == place.category.toLowerCase());
        if (!matchesInterest) return false;
      }

      return true;
    }).toList();
  }

  /// Seed initial heritage places into Firestore if the places collection is empty
  static Future<int> seedInitialPlacesIfEmpty({bool force = false}) async {
    try {
      final snap = await AppServices.db.collection('places').limit(5).get();
      if (snap.docs.isNotEmpty && !force) {
        return 0; // Already seeded
      }

      final initialData = _getHeritageCatalogue();
      final batch = AppServices.db.batch();

      for (final item in initialData) {
        final docRef = AppServices.db.collection('places').doc(item['placeId']);
        batch.set(docRef, {
          ...item,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      clearCache();
      return initialData.length;
    } catch (e) {
      return 0;
    }
  }

  /// Authentic catalog of Malaysian heritage attractions across states
  static List<Map<String, dynamic>> _getHeritageCatalogue() {
    return [
      // === PENANG ===
      {
        'placeId': 'penang_chew_jetty',
        'name': 'Clan Jetties of Penang (Chew Jetty)',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Heritage',
        'interestTags': ['Heritage', 'Culture', 'Local Business'],
        'description': 'Historic 19th-century wooden stilt village built over the sea by early Chinese clan immigrants.',
        'formattedAddress': 'Weld Quay, George Town, 10300 Penang',
        'latitude': 5.4128,
        'longitude': 100.3402,
        'location': const GeoPoint(5.4128, 100.3402),
        'estimatedVisitMinutes': 60,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 09:00 - 21:00',
        'openingTime': '09:00',
        'closingTime': '21:00',
        'publicRating': 4.7,
        'validReviewCount': 38,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_armenian_street',
        'name': 'Armenian Street Heritage Trail',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Art',
        'interestTags': ['Art', 'Heritage', 'Culture'],
        'description': 'Iconic UNESCO heritage core known for world-famous Ernest Zacharevic street art murals and antique shops.',
        'formattedAddress': 'Lebuh Armenian, George Town, 10200 Penang',
        'latitude': 5.4150,
        'longitude': 100.3365,
        'location': const GeoPoint(5.4150, 100.3365),
        'estimatedVisitMinutes': 75,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 24 Hours',
        'openingTime': '08:00',
        'closingTime': '22:00',
        'publicRating': 4.8,
        'validReviewCount': 52,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1544644181-1484b3fdfc62?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1544644181-1484b3fdfc62?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_kek_lok_si',
        'name': 'Kek Lok Si Temple',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Culture',
        'interestTags': ['Culture', 'Heritage', 'Nature'],
        'description': 'The largest Buddhist temple in Malaysia, featuring the 7-tier Pagoda of Ten Thousand Buddhas and towering Guanyin statue.',
        'formattedAddress': 'Tingkat Lembah Ria 1, 11500 Ayer Itam, Penang',
        'latitude': 5.3995,
        'longitude': 100.2737,
        'location': const GeoPoint(5.3995, 100.2737),
        'estimatedVisitMinutes': 90,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 08:30 - 17:30',
        'openingTime': '08:30',
        'closingTime': '17:30',
        'publicRating': 4.9,
        'validReviewCount': 64,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1563911302283-d2bc129e7570?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1563911302283-d2bc129e7570?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_line_clear_nasi_kandar',
        'name': 'Line Clear Nasi Kandar',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Food',
        'interestTags': ['Food', 'Culture', 'Local Business'],
        'description': 'Legendary Penang alleyway eatery serving rich, aromatic mixed curry gravies and spiced fried chicken since 1930.',
        'formattedAddress': 'Alleyway 177, Jalan Penang, 10000 George Town, Penang',
        'latitude': 5.4198,
        'longitude': 100.3323,
        'location': const GeoPoint(5.4198, 100.3323),
        'estimatedVisitMinutes': 45,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 07:00 - 23:00',
        'openingTime': '07:00',
        'closingTime': '23:00',
        'publicRating': 4.6,
        'validReviewCount': 45,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_teochew_chendul',
        'name': 'Penang Road Famous Teochew Chendul',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Food',
        'interestTags': ['Food', 'Local Business', 'Culture'],
        'description': 'Legendary roadside dessert stall founded in 1936 serving signature Teochew chendul with fresh coconut milk, pandan jelly noodles, and fragrant Gula Melaka syrup.',
        'formattedAddress': '27 & 29 Lebuh Keng Kwee, 10100 George Town, Penang, Malaysia',
        'latitude': 5.4183,
        'longitude': 100.3310,
        'location': const GeoPoint(5.4183, 100.3310),
        'estimatedVisitMinutes': 30,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 10:30 - 19:00',
        'openingTime': '10:30',
        'closingTime': '19:00',
        'publicRating': 4.7,
        'validReviewCount': 58,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_chinahouse',
        'name': 'ChinaHouse Penang',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Food',
        'interestTags': ['Food', 'Art', 'Culture'],
        'description': 'Traditional heritage shophouse complex linking Beach Street and Victoria Street, known for artisan cakes, live music, and art spaces.',
        'formattedAddress': '153, Beach St, George Town, 10300 Penang',
        'latitude': 5.4147,
        'longitude': 100.3392,
        'location': const GeoPoint(5.4147, 100.3392),
        'estimatedVisitMinutes': 60,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 09:00 - 00:00',
        'openingTime': '09:00',
        'closingTime': '00:00',
        'publicRating': 4.7,
        'validReviewCount': 49,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_hameediyah',
        'name': 'Hameediyah Restaurant (Est. 1907)',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Food',
        'interestTags': ['Food', 'Culture', 'Heritage', 'Local Business'],
        'description': 'The oldest surviving Nasi Kandar establishment in Malaysia, serving signature curries, spice roasts, and murtabak on Campbell Street since 1907.',
        'formattedAddress': '164, Campbell Street, 10100 George Town, Penang',
        'latitude': 5.4172,
        'longitude': 100.3330,
        'location': const GeoPoint(5.4172, 100.3330),
        'estimatedVisitMinutes': 45,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 10:00 - 22:00',
        'openingTime': '10:00',
        'closingTime': '22:00',
        'publicRating': 4.8,
        'validReviewCount': 56,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1589302168068-964664d93dc0?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_pinang_peranakan_mansion',
        'name': 'Pinang Peranakan Mansion',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Heritage',
        'interestTags': ['Heritage', 'Culture', 'Art'],
        'description': 'Opulent 19th-century Peranakan Baba Nyonya mansion showcasing ornate antiques, gold leaf woodwork, and ancestral customs.',
        'formattedAddress': '29, Church Street, George Town, 10200 Penang',
        'latitude': 5.4182,
        'longitude': 100.3408,
        'location': const GeoPoint(5.4182, 100.3408),
        'estimatedVisitMinutes': 75,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 09:30 - 17:00',
        'openingTime': '09:30',
        'closingTime': '17:00',
        'publicRating': 4.8,
        'validReviewCount': 42,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_penang_hill_nature',
        'name': 'Penang Hill Biosphere Nature Reserve',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'George Town',
        'category': 'Nature',
        'interestTags': ['Nature', 'Heritage'],
        'description': 'Lush UNESCO Biosphere rainforest peak accessed via funicular railway with panoramic island views and nature trails.',
        'formattedAddress': 'Bukit Bendera, 11500 Ayer Itam, Penang',
        'latitude': 5.4244,
        'longitude': 100.2687,
        'location': const GeoPoint(5.4244, 100.2687),
        'estimatedVisitMinutes': 120,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 06:30 - 22:00',
        'openingTime': '06:30',
        'closingTime': '22:00',
        'publicRating': 4.7,
        'validReviewCount': 50,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_mengkuang_dam',
        'name': 'Mengkuang Dam Lakeside Park',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Bukit Mertajam',
        'category': 'Nature',
        'interestTags': ['Nature', 'Local Business'],
        'description': 'Serene mainland Penang reservoir park framed by green hill peaks, ideal for morning jogs and lake views.',
        'formattedAddress': 'Mukim 18, Mengkuang, 14000 Bukit Mertajam, Penang',
        'latitude': 5.4012,
        'longitude': 100.4930,
        'location': const GeoPoint(5.4012, 100.4930),
        'estimatedVisitMinutes': 75,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 07:00 - 19:00',
        'openingTime': '07:00',
        'closingTime': '19:00',
        'publicRating': 4.7,
        'validReviewCount': 29,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_bm_yam_rice',
        'name': 'Restoran BM Yam Rice',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Bukit Mertajam',
        'category': 'Food',
        'interestTags': ['Food', 'Local Business', 'Culture'],
        'description': 'Famous Bukit Mertajam fragrant yam rice paired with salted vegetable pork rib soup.',
        'formattedAddress': '7, Jalan Murthy, 14000 Bukit Mertajam, Penang',
        'latitude': 5.3644,
        'longitude': 100.4608,
        'location': const GeoPoint(5.3644, 100.4608),
        'estimatedVisitMinutes': 50,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 09:00 - 15:00',
        'openingTime': '09:00',
        'closingTime': '15:00',
        'publicRating': 4.6,
        'validReviewCount': 34,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_batu_ferringhi_beach',
        'name': 'Batu Ferringhi Beach & Coastal Trail',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Batu Ferringhi',
        'category': 'Nature',
        'interestTags': ['Nature', 'Beach'],
        'description': 'Famous white sand coastline along northern Penang with coastal sea breezes, water activities, and sunset viewpoints.',
        'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang',
        'latitude': 5.4744,
        'longitude': 100.2472,
        'location': const GeoPoint(5.4744, 100.2472),
        'estimatedVisitMinutes': 60,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 24 Hours',
        'openingTime': '06:00',
        'closingTime': '22:00',
        'publicRating': 4.7,
        'validReviewCount': 44,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_tropical_spice_garden',
        'name': 'Tropical Spice Garden',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Batu Ferringhi',
        'category': 'Nature',
        'interestTags': ['Nature', 'Culture', 'Heritage'],
        'description': 'Award-winning eco-sanctuary showcasing over 500 species of living tropical herbs, spices, and jungle paths.',
        'formattedAddress': 'Lot 595 Mukim 2, Jalan Teluk Bahang, 11050 Penang',
        'latitude': 5.4628,
        'longitude': 100.2289,
        'location': const GeoPoint(5.4628, 100.2289),
        'estimatedVisitMinutes': 75,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 09:00 - 16:30',
        'openingTime': '09:00',
        'closingTime': '16:30',
        'publicRating': 4.8,
        'validReviewCount': 37,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_ferringhi_kopitiam',
        'name': 'Batu Ferringhi Heritage Kopitiam',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Batu Ferringhi',
        'category': 'Food',
        'interestTags': ['Food', 'Breakfast', 'Kopitiam', 'Local Business'],
        'description': 'Traditional morning kopitiam serving charcoal-toasted kaya butter toast, half-boiled kampung eggs, and aromatic Hainanese Nanyang coffee.',
        'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang',
        'latitude': 5.4715,
        'longitude': 100.2450,
        'location': const GeoPoint(5.4715, 100.2450),
        'estimatedVisitMinutes': 40,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 07:00 - 14:00',
        'openingTime': '07:00',
        'closingTime': '14:00',
        'publicRating': 4.6,
        'validReviewCount': 31,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'penang_long_beach_cafe',
        'name': 'Long Beach Food Court & Seafood',
        'stateId': 'penang',
        'stateName': 'Penang',
        'area': 'Batu Ferringhi',
        'category': 'Food',
        'interestTags': ['Food', 'Dinner', 'Lunch', 'Local Business'],
        'description': 'Bustling open-air food center offering char koay teow, satay skewers, grilled seafood, and refreshing fresh coconut water.',
        'formattedAddress': 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang',
        'latitude': 5.4730,
        'longitude': 100.2465,
        'location': const GeoPoint(5.4730, 100.2465),
        'estimatedVisitMinutes': 50,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 11:30 - 23:00',
        'openingTime': '11:30',
        'closingTime': '23:00',
        'publicRating': 4.7,
        'validReviewCount': 52,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },

      // === MELAKA ===
      {
        'placeId': 'melaka_stadthuys',
        'name': 'The Stadthuys & Red Square',
        'stateId': 'melaka',
        'stateName': 'Melaka',
        'area': 'Melaka City (Bandar Hilir)',
        'category': 'Heritage',
        'interestTags': ['Heritage', 'Culture', 'Art'],
        'description': 'Oldest surviving Dutch colonial building in the East, built in 1650 with striking terracotta red walls.',
        'formattedAddress': 'Gereja St, Bandar Hilir, 75000 Melaka',
        'latitude': 2.1944,
        'longitude': 102.2492,
        'location': const GeoPoint(2.1944, 102.2492),
        'estimatedVisitMinutes': 60,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 09:00 - 17:30',
        'openingTime': '09:00',
        'closingTime': '17:30',
        'publicRating': 4.8,
        'validReviewCount': 40,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'melaka_a_famosa',
        'name': 'A Famosa Fortress (Porta de Santiago)',
        'stateId': 'melaka',
        'stateName': 'Melaka',
        'area': 'Melaka City (Bandar Hilir)',
        'category': 'Heritage',
        'interestTags': ['Heritage', 'Culture'],
        'description': '16th-century Portuguese fortress gate standing as one of the oldest European architectural remains in Southeast Asia.',
        'formattedAddress': 'Jalan Parameswara, Bandar Hilir, 78000 Melaka',
        'latitude': 2.1919,
        'longitude': 102.2505,
        'location': const GeoPoint(2.1919, 102.2505),
        'estimatedVisitMinutes': 45,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 24 Hours',
        'openingTime': '08:00',
        'closingTime': '20:00',
        'publicRating': 4.7,
        'validReviewCount': 35,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'melaka_jonker_walk',
        'name': 'Jonker Street Heritage & Night Market',
        'stateId': 'melaka',
        'stateName': 'Melaka',
        'area': 'Jonker Walk & Heritage Core',
        'category': 'Food',
        'interestTags': ['Food', 'Local Business', 'Culture', 'Art'],
        'description': 'Bustling historic street lined with heritage shophouses, authentic Nyonya eateries, antique stalls, and vibrant weekend street food.',
        'formattedAddress': 'Jalan Hang Jebat, 75200 Melaka',
        'latitude': 2.1972,
        'longitude': 102.2475,
        'location': const GeoPoint(2.1972, 102.2475),
        'estimatedVisitMinutes': 90,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 10:00 - 23:00',
        'openingTime': '10:00',
        'closingTime': '23:00',
        'publicRating': 4.8,
        'validReviewCount': 55,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },

      // === KUALA LUMPUR ===
      {
        'placeId': 'kl_sultan_abdul_samad',
        'name': 'Sultan Abdul Samad Building & Merdeka Square',
        'stateId': 'kuala_lumpur',
        'stateName': 'Kuala Lumpur',
        'area': 'KLCC & City Centre',
        'category': 'Heritage',
        'interestTags': ['Heritage', 'Culture', 'Art'],
        'description': 'Late 19th-century Moorish-style landmark building with a 41-metre clock tower facing Dataran Merdeka.',
        'formattedAddress': 'Jalan Raja, City Centre, 50050 Kuala Lumpur',
        'latitude': 3.1486,
        'longitude': 101.6939,
        'location': const GeoPoint(3.1486, 101.6939),
        'estimatedVisitMinutes': 60,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 24 Hours',
        'openingTime': '08:00',
        'closingTime': '22:00',
        'publicRating': 4.7,
        'validReviewCount': 44,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1582650625119-3a31f8418b7d?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'kl_petaling_street',
        'name': 'Petaling Street (KL Chinatown)',
        'stateId': 'kuala_lumpur',
        'stateName': 'Kuala Lumpur',
        'area': 'Chinatown / Petaling Street',
        'category': 'Food',
        'interestTags': ['Food', 'Local Business', 'Culture', 'Heritage'],
        'description': 'Vibrant historical Chinatown street with heritage kopi stalls, traditional herbal tea shops, and street markets.',
        'formattedAddress': 'Jalan Petaling, City Centre, 50000 Kuala Lumpur',
        'latitude': 3.1438,
        'longitude': 101.6978,
        'location': const GeoPoint(3.1438, 101.6978),
        'estimatedVisitMinutes': 75,
        'estimatedBudget': 'Medium',
        'openingHours': 'Daily 09:00 - 23:00',
        'openingTime': '09:00',
        'closingTime': '23:00',
        'publicRating': 4.6,
        'validReviewCount': 48,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
      {
        'placeId': 'kl_batu_caves',
        'name': 'Batu Caves Temple & Murugan Statue',
        'stateId': 'kuala_lumpur',
        'stateName': 'Kuala Lumpur',
        'area': 'KLCC & City Centre',
        'category': 'Culture',
        'interestTags': ['Culture', 'Heritage', 'Nature'],
        'description': 'Limestone hill featuring 272 colourful steps leading to temple caves and the colossal golden Lord Murugan statue.',
        'formattedAddress': 'Gombak, 68100 Batu Caves, Selangor / KL',
        'latitude': 3.2379,
        'longitude': 101.6840,
        'location': const GeoPoint(3.2379, 101.6840),
        'estimatedVisitMinutes': 90,
        'estimatedBudget': 'Low',
        'openingHours': 'Daily 07:00 - 21:00',
        'openingTime': '07:00',
        'closingTime': '21:00',
        'publicRating': 4.8,
        'validReviewCount': 62,
        'primaryImageUrl': 'https://images.unsplash.com/photo-1563911302283-d2bc129e7570?auto=format&fit=crop&w=900&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1563911302283-d2bc129e7570?auto=format&fit=crop&w=900&q=80'],
        'isVerified': true,
        'isActive': true,
        'status': 'active',
        'trustLabel': 'High Trust',
      },
    ];
  }
}
