import 'package:cloud_firestore/cloud_firestore.dart';

class ItineraryStopModel {
  const ItineraryStopModel({
    required this.placeId,
    required this.name,
    required this.stateId,
    required this.stateName,
    required this.area,
    required this.category,
    required this.durationMinutes,
    required this.sequence,
    required this.dayNumber,
    this.tags = const [],
    this.description = '',
    this.formattedAddress = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.budgetLevel = 'Medium',
    this.openingHours = '',
    this.publicRating = 4.5,
    this.imageUrl = '',
    this.imageUrls = const [],
    this.trustLabel = 'Verified Place',
    this.vendorId = '',
    this.culturalTask,
    this.culturalTaskId,
    this.culturalTaskTitle,
    this.culturalTaskRewardPoints,
    this.suggestedTimeLabel,
    this.suggestedStartMinutes,
    this.suggestedEndMinutes,
    this.travelMinutesBefore = 0,
    this.scheduleNotes = const [],
    this.mealRole,
    this.phone = '',
    this.website = '',
  });

  final String placeId;
  final String name;
  final String stateId;
  final String stateName;
  final String area;
  final String category;
  final int durationMinutes;
  final int sequence;
  final int dayNumber;
  final List<String> tags;
  final String description;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String budgetLevel;
  final String openingHours;
  final double publicRating;
  final String imageUrl;
  final List<String> imageUrls;
  final String trustLabel;
  final String vendorId;
  final Map<String, dynamic>? culturalTask;
  final String? culturalTaskId;
  final String? culturalTaskTitle;
  final int? culturalTaskRewardPoints;
  final String? suggestedTimeLabel;
  final int? suggestedStartMinutes;
  final int? suggestedEndMinutes;
  final int travelMinutesBefore;
  final List<String> scheduleNotes;
  final String? mealRole;
  final String phone;
  final String website;

  factory ItineraryStopModel.fromMap(Map<String, dynamic> data) {
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

    final rawTags = data['tags'] ?? data['interestTags'];
    final List<String> tags = [];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null) tags.add(t.toString());
      }
    }

    final rawNotes = data['scheduleNotes'];
    final List<String> notes = [];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        if (n != null) notes.add(n.toString());
      }
    }

    final rawImgs = data['imageUrls'];
    final List<String> imgs = [];
    if (rawImgs is List) {
      for (final i in rawImgs) {
        if (i is String && i.isNotEmpty) imgs.add(i);
      }
    }

    final task = data['culturalTask'] is Map ? Map<String, dynamic>.from(data['culturalTask'] as Map) : null;

    return ItineraryStopModel(
      placeId: '${data['placeId'] ?? ''}',
      name: '${data['name'] ?? 'Stop'}',
      stateId: '${data['stateId'] ?? ''}',
      stateName: '${data['stateName'] ?? ''}',
      area: '${data['area'] ?? ''}',
      category: '${data['category'] ?? 'Heritage'}',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      sequence: (data['sequence'] as num?)?.toInt() ?? 1,
      dayNumber: (data['dayNumber'] as num?)?.toInt() ?? 1,
      tags: tags,
      description: '${data['description'] ?? ''}',
      formattedAddress: '${data['formattedAddress'] ?? ''}',
      latitude: lat,
      longitude: lng,
      budgetLevel: '${data['budgetLevel'] ?? 'Medium'}',
      openingHours: '${data['openingHours'] ?? ''}',
      publicRating: (data['score'] as num?)?.toDouble() ??
          (data['publicRating'] as num?)?.toDouble() ??
          4.5,
      imageUrl: '${data['imageUrl'] ?? data['primaryImageUrl'] ?? ''}',
      imageUrls: imgs,
      trustLabel: '${data['trustLabel'] ?? 'Verified Place'}',
      vendorId: '${data['vendorId'] ?? ''}',
      culturalTask: task,
      culturalTaskId: data['culturalTaskId']?.toString() ?? task?['id']?.toString(),
      culturalTaskTitle: data['culturalTaskTitle']?.toString() ?? task?['title']?.toString(),
      culturalTaskRewardPoints: (data['culturalTaskRewardPoints'] as num?)?.toInt() ??
          (task?['rewardPoints'] as num?)?.toInt(),
      suggestedTimeLabel: data['suggestedTimeLabel']?.toString(),
      suggestedStartMinutes: (data['suggestedStartMinutes'] as num?)?.toInt(),
      suggestedEndMinutes: (data['suggestedEndMinutes'] as num?)?.toInt(),
      travelMinutesBefore: (data['travelMinutesBefore'] as num?)?.toInt() ?? 0,
      scheduleNotes: notes,
      mealRole: data['mealRole']?.toString(),
      phone: '${data['phone'] ?? ''}',
      website: '${data['website'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
    'placeId': placeId,
    'name': name,
    'stateId': stateId,
    'stateName': stateName,
    'area': area,
    'category': category,
    'tags': tags,
    'description': description,
    'formattedAddress': formattedAddress,
    'location': {'latitude': latitude, 'longitude': longitude},
    'latitude': latitude,
    'longitude': longitude,
    'durationMinutes': durationMinutes,
    'estimatedVisitMinutes': durationMinutes,
    'sequence': sequence,
    'dayNumber': dayNumber,
    'budgetLevel': budgetLevel,
    'openingHours': openingHours,
    'score': publicRating,
    'publicRating': publicRating,
    'inAppAverageRating': publicRating,
    'imageUrl': imageUrl,
    'primaryImageUrl': imageUrl,
    'imageUrls': imageUrls,
    'trustLabel': trustLabel,
    'vendorId': vendorId,
    if (culturalTask != null) 'culturalTask': culturalTask,
    if (culturalTaskId != null) 'culturalTaskId': culturalTaskId,
    if (culturalTaskTitle != null) 'culturalTaskTitle': culturalTaskTitle,
    if (culturalTaskRewardPoints != null) 'culturalTaskRewardPoints': culturalTaskRewardPoints,
    if (suggestedTimeLabel != null) 'suggestedTimeLabel': suggestedTimeLabel,
    if (suggestedStartMinutes != null) 'suggestedStartMinutes': suggestedStartMinutes,
    if (suggestedEndMinutes != null) 'suggestedEndMinutes': suggestedEndMinutes,
    'travelMinutesBefore': travelMinutesBefore,
    'scheduleNotes': scheduleNotes,
    if (mealRole != null) 'mealRole': mealRole,
    'phone': phone,
    'website': website,
  };
}

class ItineraryDayModel {
  const ItineraryDayModel({
    required this.dayNumber,
    required this.date,
    required this.dateLabel,
    required this.stops,
    this.weather = const {},
    this.totalEstimatedMinutes = 0,
    this.remainingMinutes = 0,
    this.budget = 'RM 50 - 150',
    this.budgetLevel = 'Medium',
  });

  final int dayNumber;
  final DateTime date;
  final String dateLabel;
  final List<ItineraryStopModel> stops;
  final Map<String, dynamic> weather;
  final int totalEstimatedMinutes;
  final int remainingMinutes;
  final String budget;
  final String budgetLevel;

  factory ItineraryDayModel.fromMap(Map<String, dynamic> data) {
    final rawStops = data['stops'];
    final List<ItineraryStopModel> parsedStops = [];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is Map) {
          parsedStops.add(ItineraryStopModel.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    final dateVal = data['date'];
    DateTime parsedDate = DateTime.now();
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    }

    return ItineraryDayModel(
      dayNumber: (data['dayNumber'] as num?)?.toInt() ?? 1,
      date: parsedDate,
      dateLabel: '${data['dateLabel'] ?? 'Day 1'}',
      stops: parsedStops,
      weather: data['weather'] is Map ? Map<String, dynamic>.from(data['weather'] as Map) : {},
      totalEstimatedMinutes: (data['totalEstimatedMinutes'] as num?)?.toInt() ?? 0,
      remainingMinutes: (data['remainingMinutes'] as num?)?.toInt() ?? 0,
      budget: '${data['budget'] ?? 'RM 50 - 150'}',
      budgetLevel: '${data['budgetLevel'] ?? 'Medium'}',
    );
  }

  int get plannedActivityMinutes => stops.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  int get travelMinutes => stops.fold<int>(0, (sum, s) => sum + s.travelMinutesBefore);
  int get usedScheduleMinutes => plannedActivityMinutes + travelMinutes;
  int get mealMinutes => stops.where((s) => s.mealRole != null || s.category == 'Food').fold<int>(0, (sum, s) => sum + s.durationMinutes);

  Map<String, dynamic> toMap() => {
    'dayNumber': dayNumber,
    'date': date.toIso8601String(),
    'dateLabel': dateLabel,
    'weather': weather,
    'stops': stops.map((s) => s.toMap()).toList(),
    'totalEstimatedMinutes': totalEstimatedMinutes,
    'remainingMinutes': remainingMinutes,
    'budget': budget,
    'budgetLevel': budgetLevel,
  };
}

class ItineraryModel {
  const ItineraryModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.stateId,
    required this.stateName,
    required this.selectedArea,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.dailyStartTime,
    required this.dailyEndTime,
    required this.availableHours,
    required this.interests,
    required this.budget,
    required this.pace,
    required this.days,
    required this.stops,
    this.status = 'saved',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String stateId;
  final String stateName;
  final String selectedArea;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final String dailyStartTime;
  final String dailyEndTime;
  final double availableHours;
  final List<String> interests;
  final String budget;
  final String pace;
  final List<ItineraryDayModel> days;
  final List<ItineraryStopModel> stops;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ItineraryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ItineraryModel.fromMap(doc.id, data);
  }

  factory ItineraryModel.fromMap(String id, Map<String, dynamic> data) {
    final startVal = data['startDate'] ?? data['targetDate'];
    DateTime start = DateTime.now();
    if (startVal is Timestamp) {
      start = startVal.toDate();
    } else if (startVal is String) {
      start = DateTime.tryParse(startVal) ?? DateTime.now();
    }

    final endVal = data['endDate'] ?? startVal;
    DateTime end = start;
    if (endVal is Timestamp) {
      end = endVal.toDate();
    } else if (endVal is String) {
      end = DateTime.tryParse(endVal) ?? start;
    }

    final rawDays = data['days'];
    final List<ItineraryDayModel> parsedDays = [];
    if (rawDays is List) {
      for (final d in rawDays) {
        if (d is Map) {
          parsedDays.add(ItineraryDayModel.fromMap(Map<String, dynamic>.from(d)));
        }
      }
    }

    final rawStops = data['stops'];
    final List<ItineraryStopModel> parsedStops = [];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is Map) {
          parsedStops.add(ItineraryStopModel.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    final rawInterests = data['interests'];
    final List<String> parsedInterests = [];
    if (rawInterests is List) {
      for (final i in rawInterests) {
        if (i != null) parsedInterests.add(i.toString());
      }
    }

    final createdVal = data['createdAt'];
    DateTime? created;
    if (createdVal is Timestamp) created = createdVal.toDate();

    final updatedVal = data['updatedAt'];
    DateTime? updated;
    if (updatedVal is Timestamp) updated = updatedVal.toDate();

    final numDays = (data['numberOfDays'] as num?)?.toInt() ??
        (data['dayCount'] as num?)?.toInt() ??
        (parsedDays.isNotEmpty ? parsedDays.length : 1);

    return ItineraryModel(
      id: id,
      userId: '${data['userId'] ?? ''}',
      title: '${data['title'] ?? 'Malaysia Tour'}',
      stateId: '${data['stateId'] ?? 'penang'}',
      stateName: '${data['stateName'] ?? data['state'] ?? 'Penang'}',
      selectedArea: '${data['selectedArea'] ?? data['area'] ?? 'George Town'}',
      startDate: start,
      endDate: end,
      numberOfDays: numDays,
      dailyStartTime: '${data['dailyStartTime'] ?? '09:00'}',
      dailyEndTime: '${data['dailyEndTime'] ?? '17:00'}',
      availableHours: (data['availableHours'] as num?)?.toDouble() ??
          (data['dailyHours'] as num?)?.toDouble() ??
          4.0,
      interests: parsedInterests,
      budget: '${data['budgetPreference'] ?? data['budgetLevel'] ?? data['budget'] ?? 'Medium'}',
      pace: '${data['travelPace'] ?? data['pace'] ?? 'Balanced'}',
      days: parsedDays,
      stops: parsedStops,
      createdAt: created,
      updatedAt: updated,
    );
  }

  ItineraryModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? stateId,
    String? stateName,
    String? selectedArea,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfDays,
    String? dailyStartTime,
    String? dailyEndTime,
    double? availableHours,
    List<String>? interests,
    String? budget,
    String? pace,
    List<ItineraryDayModel>? days,
    List<ItineraryStopModel>? stops,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      selectedArea: selectedArea ?? this.selectedArea,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      dailyStartTime: dailyStartTime ?? this.dailyStartTime,
      dailyEndTime: dailyEndTime ?? this.dailyEndTime,
      availableHours: availableHours ?? this.availableHours,
      interests: interests ?? this.interests,
      budget: budget ?? this.budget,
      pace: pace ?? this.pace,
      days: days ?? this.days,
      stops: stops ?? this.stops,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'stateId': stateId,
    'stateName': stateName,
    'selectedArea': selectedArea,
    'area': selectedArea,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'numberOfDays': numberOfDays,
    'dayCount': numberOfDays,
    'dailyStartTime': dailyStartTime,
    'dailyEndTime': dailyEndTime,
    'availableHours': availableHours,
    'dailyHours': availableHours,
    'interests': interests,
    'budget': budget,
    'budgetLevel': budget,
    'budgetPreference': budget,
    'travelPace': pace,
    'pace': pace,
    'days': days.map((d) => d.toMap()).toList(),
    'stops': stops.map((s) => s.toMap()).toList(),
    'status': status,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
