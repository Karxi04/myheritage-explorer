import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  const PlaceModel({
    required this.placeId,
    required this.name,
    required this.stateId,
    required this.stateName,
    required this.area,
    required this.category,
    this.interestTags = const [],
    this.description = '',
    this.formattedAddress = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.estimatedVisitMinutes = 60,
    this.estimatedBudget = 'Medium',
    this.openingHours = 'Daily 09:00 - 18:00',
    this.openingTime = '09:00',
    this.closingTime = '18:00',
    this.publicRating = 4.5,
    this.validReviewCount = 0,
    this.primaryImageUrl = '',
    this.imageUrls = const [],
    this.isVerified = true,
    this.isActive = true,
    this.status = 'active',
    this.trustLabel = 'Verified Place',
    this.vendorId = '',
    this.culturalTaskId,
    this.culturalTask,
    this.phone = '',
    this.website = '',
    this.mealRole,
  });

  final String placeId;
  final String name;
  final String stateId;
  final String stateName;
  final String area;
  final String category;
  final List<String> interestTags;
  final String description;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final int estimatedVisitMinutes;
  final String estimatedBudget;
  final String openingHours;
  final String openingTime;
  final String closingTime;
  final double publicRating;
  final int validReviewCount;
  final String primaryImageUrl;
  final List<String> imageUrls;
  final bool isVerified;
  final bool isActive;
  final String status;
  final String trustLabel;
  final String vendorId;
  final String? culturalTaskId;
  final Map<String, dynamic>? culturalTask;
  final String phone;
  final String website;
  final String? mealRole;

  factory PlaceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PlaceModel.fromMap(doc.id, data);
  }

  factory PlaceModel.fromMap(String id, Map<String, dynamic> data) {
    final location = data['location'];
    double lat = 0.0;
    double lng = 0.0;
    if (location is GeoPoint) {
      lat = location.latitude;
      lng = location.longitude;
    } else if (location is Map) {
      lat = (location['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (location['longitude'] as num?)?.toDouble() ?? 0.0;
    } else {
      lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    final rawImages = data['imageUrls'];
    final List<String> imgs = [];
    if (rawImages is List) {
      for (final img in rawImages) {
        if (img is String && img.trim().isNotEmpty) {
          imgs.add(img.trim());
        }
      }
    }

    final primaryImg = '${data['primaryImageUrl'] ?? data['imageUrl'] ?? ''}'.trim();
    if (primaryImg.isNotEmpty && !imgs.contains(primaryImg)) {
      imgs.insert(0, primaryImg);
    }

    final rawTags = data['interestTags'] ?? data['tags'] ?? data['plannerCategories'];
    final List<String> tags = [];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null && t.toString().trim().isNotEmpty) {
          tags.add(t.toString().trim());
        }
      }
    }

    final rawTask = data['culturalTask'];
    final Map<String, dynamic>? task =
        rawTask is Map ? Map<String, dynamic>.from(rawTask) : null;

    final stateStr = '${data['stateName'] ?? data['state'] ?? ''}'.trim();
    final stateIdStr = '${data['stateId'] ?? ''}'.trim();

    return PlaceModel(
      placeId: id,
      name: '${data['name'] ?? data['businessName'] ?? data['displayName'] ?? 'Heritage Place'}',
      stateId: stateIdStr.isNotEmpty ? stateIdStr : _inferStateId(stateStr, data['area']?.toString() ?? ''),
      stateName: stateStr.isNotEmpty ? stateStr : _inferStateName(data['area']?.toString() ?? ''),
      area: '${data['area'] ?? ''}'.trim(),
      category: '${data['category'] ?? data['businessCategory'] ?? 'Heritage'}',
      interestTags: tags.isNotEmpty ? tags : ['${data['category'] ?? 'Heritage'}'],
      description: '${data['description'] ?? data['businessDescription'] ?? ''}',
      formattedAddress: '${data['formattedAddress'] ?? data['address'] ?? data['area'] ?? ''}',
      latitude: lat,
      longitude: lng,
      estimatedVisitMinutes: (data['durationMinutes'] as num?)?.toInt() ??
          (data['estimatedVisitMinutes'] as num?)?.toInt() ??
          60,
      estimatedBudget: '${data['budgetLevel'] ?? data['estimatedBudget'] ?? 'Medium'}',
      openingHours: '${data['openingHours'] ?? data['businessHours'] ?? 'Daily 09:00 - 18:00'}',
      openingTime: '${data['openingTime'] ?? '09:00'}',
      closingTime: '${data['closingTime'] ?? '18:00'}',
      publicRating: (data['publicRating'] as num?)?.toDouble() ??
          (data['score'] as num?)?.toDouble() ??
          (data['rating'] as num?)?.toDouble() ??
          4.5,
      validReviewCount: (data['validReviewCount'] as num?)?.toInt() ??
          (data['inAppReviewCount'] as num?)?.toInt() ??
          0,
      primaryImageUrl: primaryImg.isNotEmpty ? primaryImg : (imgs.isNotEmpty ? imgs.first : ''),
      imageUrls: imgs,
      isVerified: data['isVerified'] == true || data['status'] == 'active' || data['trustLabel'] != null,
      isActive: data['isActive'] != false && data['status'] != 'inactive',
      status: '${data['status'] ?? 'active'}',
      trustLabel: '${data['trustLabel'] ?? 'Verified Place'}',
      vendorId: '${data['vendorId'] ?? ''}',
      culturalTaskId: data['culturalTaskId']?.toString() ?? task?['id']?.toString(),
      culturalTask: task,
      phone: '${data['phone'] ?? data['contactNumber'] ?? ''}',
      website: '${data['website'] ?? data['websiteUrl'] ?? ''}',
      mealRole: data['mealRole']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'placeId': placeId,
    'name': name,
    'stateId': stateId,
    'stateName': stateName,
    'area': area,
    'category': category,
    'interestTags': interestTags,
    'description': description,
    'formattedAddress': formattedAddress,
    'location': GeoPoint(latitude, longitude),
    'latitude': latitude,
    'longitude': longitude,
    'estimatedVisitMinutes': estimatedVisitMinutes,
    'durationMinutes': estimatedVisitMinutes,
    'estimatedBudget': estimatedBudget,
    'budgetLevel': estimatedBudget,
    'openingHours': openingHours,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'publicRating': publicRating,
    'score': publicRating,
    'validReviewCount': validReviewCount,
    'primaryImageUrl': primaryImageUrl,
    'imageUrl': primaryImageUrl,
    'imageUrls': imageUrls,
    'isVerified': isVerified,
    'isActive': isActive,
    'status': status,
    'trustLabel': trustLabel,
    'vendorId': vendorId,
    if (culturalTaskId != null) 'culturalTaskId': culturalTaskId,
    if (culturalTask != null) 'culturalTask': culturalTask,
    'phone': phone,
    'website': website,
    if (mealRole != null) 'mealRole': mealRole,
  };

  Map<String, dynamic> toStopMap({
    int sequence = 1,
    int dayNumber = 1,
    String? timeLabel,
    int? startMinutes,
    int? endMinutes,
    int travelMinutesBefore = 0,
    List<String> scheduleNotes = const [],
  }) {
    return {
      'placeId': placeId,
      'name': name,
      'stateId': stateId,
      'stateName': stateName,
      'area': area,
      'category': category,
      'tags': interestTags,
      'description': description,
      'formattedAddress': formattedAddress,
      'location': {'latitude': latitude, 'longitude': longitude},
      'latitude': latitude,
      'longitude': longitude,
      'durationMinutes': estimatedVisitMinutes,
      'estimatedVisitMinutes': estimatedVisitMinutes,
      'budgetLevel': estimatedBudget,
      'openingHours': openingHours,
      'score': publicRating,
      'publicRating': publicRating,
      'inAppAverageRating': publicRating,
      'inAppReviewCount': validReviewCount,
      'imageUrl': primaryImageUrl,
      'primaryImageUrl': primaryImageUrl,
      'imageUrls': imageUrls,
      'trustLabel': trustLabel,
      'vendorId': vendorId,
      'culturalTask': culturalTask,
      'culturalTaskId': culturalTaskId,
      'culturalTaskTitle': culturalTask?['title'],
      'culturalTaskRewardPoints': culturalTask?['rewardPoints'],
      'phone': phone,
      'website': website,
      'sequence': sequence,
      'dayNumber': dayNumber,
      'travelMinutesBefore': travelMinutesBefore,
      'suggestedTimeLabel': timeLabel,
      'suggestedStartMinutes': startMinutes,
      'suggestedEndMinutes': endMinutes,
      'scheduleNotes': scheduleNotes,
      if (mealRole != null) 'mealRole': mealRole,
    };
  }

  Map<String, dynamic> toItineraryStopMap({
    int sequence = 1,
    int dayNumber = 1,
    String? timeLabel,
    int? startMinutes,
    int? endMinutes,
    int travelMinutesBefore = 0,
    List<String> scheduleNotes = const [],
  }) {
    return toStopMap(
      sequence: sequence,
      dayNumber: dayNumber,
      timeLabel: timeLabel,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      travelMinutesBefore: travelMinutesBefore,
      scheduleNotes: scheduleNotes,
    );
  }

  static String _inferStateId(String stateName, String area) {
    final lower = '$stateName $area'.toLowerCase();
    if (lower.contains('penang') || lower.contains('pulau pinang') || lower.contains('george town') || lower.contains('butterworth') || lower.contains('bukit mertajam')) {
      return 'penang';
    }
    if (lower.contains('melaka') || lower.contains('malacca') || lower.contains('ayer keroh') || lower.contains('jonker')) {
      return 'melaka';
    }
    if (lower.contains('kuala lumpur') || lower.contains('kl') || lower.contains('bukit bintang') || lower.contains('brickfields')) {
      return 'kuala_lumpur';
    }
    if (lower.contains('selangor') || lower.contains('petaling jaya') || lower.contains('shah alam') || lower.contains('klang')) {
      return 'selangor';
    }
    if (lower.contains('perak') || lower.contains('ipoh') || lower.contains('taiping')) {
      return 'perak';
    }
    if (lower.contains('johor') || lower.contains('johor bahru') || lower.contains('muar')) {
      return 'johor';
    }
    if (lower.contains('kedah') || lower.contains('alor setar') || lower.contains('langkawi')) {
      return 'kedah';
    }
    if (lower.contains('pahang') || lower.contains('kuantan') || lower.contains('cameron')) {
      return 'pahang';
    }
    if (lower.contains('terengganu') || lower.contains('kuala terengganu')) {
      return 'terengganu';
    }
    if (lower.contains('kelantan') || lower.contains('kota bharu')) {
      return 'kelantan';
    }
    if (lower.contains('sabah') || lower.contains('kota kinabalu') || lower.contains('sandakan')) {
      return 'sabah';
    }
    if (lower.contains('sarawak') || lower.contains('kuching') || lower.contains('miri')) {
      return 'sarawak';
    }
    return 'penang';
  }

  static String _inferStateName(String area) {
    final lower = area.toLowerCase();
    if (lower.contains('penang') || lower.contains('pulau pinang') || lower.contains('george town') || lower.contains('butterworth') || lower.contains('bukit mertajam')) {
      return 'Penang';
    }
    if (lower.contains('melaka') || lower.contains('malacca') || lower.contains('ayer keroh') || lower.contains('jonker')) {
      return 'Melaka';
    }
    if (lower.contains('kuala lumpur') || lower.contains('kl') || lower.contains('bukit bintang') || lower.contains('brickfields')) {
      return 'Kuala Lumpur';
    }
    if (lower.contains('selangor') || lower.contains('petaling jaya') || lower.contains('shah alam') || lower.contains('klang')) {
      return 'Selangor';
    }
    if (lower.contains('perak') || lower.contains('ipoh') || lower.contains('taiping')) {
      return 'Perak';
    }
    if (lower.contains('johor') || lower.contains('johor bahru') || lower.contains('muar')) {
      return 'Johor';
    }
    if (lower.contains('kedah') || lower.contains('alor setar') || lower.contains('langkawi')) {
      return 'Kedah';
    }
    if (lower.contains('pahang') || lower.contains('kuantan') || lower.contains('cameron')) {
      return 'Pahang';
    }
    if (lower.contains('terengganu') || lower.contains('kuala terengganu')) {
      return 'Terengganu';
    }
    if (lower.contains('kelantan') || lower.contains('kota bharu')) {
      return 'Kelantan';
    }
    if (lower.contains('sabah') || lower.contains('kota kinabalu') || lower.contains('sandakan')) {
      return 'Sabah';
    }
    if (lower.contains('sarawak') || lower.contains('kuching') || lower.contains('miri')) {
      return 'Sarawak';
    }
    return 'Penang';
  }
}
