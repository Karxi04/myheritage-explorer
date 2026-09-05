import 'dart:math';
import '../models/place_model.dart';

/// Central service governing Breakfast, Lunch, Dinner, Dessert and Morning Food rules
class MealPlanningService {
  const MealPlanningService._();

  // Configurable standard Malaysian meal time windows (in minutes from midnight)
  static const int breakfastStart = 7 * 60; // 07:00 (420)
  static const int breakfastEnd = 10 * 60 + 30; // 10:30 (630)
  static const int breakfastDefaultDuration = 45; // 45 min

  static const int lunchStart = 11 * 60 + 30; // 11:30 (690)
  static const int lunchEnd = 14 * 60 + 30; // 14:30 (870)
  static const int lunchDefaultDuration = 55; // 55 min

  static const int dinnerStart = 17 * 60 + 30; // 17:30 (1050)
  static const int dinnerEnd = 21 * 60; // 21:00 (1260)
  static const int dinnerDefaultDuration = 65; // 65 min

  static const int dessertDefaultDuration = 40; // 40 min
  static const int dimSumDefaultDuration = 50; // 50 min

  /// Determine eligible meal slots for a given daily window
  static Set<String> getEligibleMealTypes({
    required int startMinutes,
    required int availableMinutes,
    required bool foodInterestSelected,
  }) {
    if (!foodInterestSelected) return const {};

    final endMinutes = startMinutes + availableMinutes;
    final eligible = <String>{};

    // Breakfast eligibility: start window overlaps breakfast and starts before 10:00
    if (startMinutes <= breakfastEnd - 30 && endMinutes >= breakfastStart + 30) {
      if (startMinutes < 10 * 60) {
        eligible.add('Breakfast');
      }
    }

    // Lunch eligibility: window overlaps lunch period
    if (startMinutes <= lunchEnd - 30 && endMinutes >= lunchStart + 30) {
      eligible.add('Lunch');
    }

    // Dinner eligibility: window overlaps dinner period
    if (startMinutes <= dinnerEnd - 30 && endMinutes >= dinnerStart + 30) {
      eligible.add('Dinner');
    }

    return eligible;
  }

  /// Check which meal matches a specific schedule time
  static String? getMealRoleForMinute(int minuteOfDay) {
    if (minuteOfDay >= breakfastStart && minuteOfDay <= breakfastEnd) {
      return 'Breakfast';
    }
    if (minuteOfDay >= lunchStart && minuteOfDay <= lunchEnd) {
      return 'Lunch';
    }
    if (minuteOfDay >= dinnerStart && minuteOfDay <= dinnerEnd) {
      return 'Dinner';
    }
    return null;
  }

  /// Check if a place is classified as a food/restaurant/dining location
  static bool isFoodPlace(PlaceModel place) {
    if (place.category.toLowerCase() == 'food') return true;
    final tags = place.interestTags.map((t) => t.toLowerCase()).toList();
    return tags.any((t) =>
        t.contains('food') ||
        t.contains('restaurant') ||
        t.contains('cafe') ||
        t.contains('hawker') ||
        t.contains('kopitiam') ||
        t.contains('bakery') ||
        t.contains('dessert') ||
        t.contains('chendul') ||
        t.contains('cendol') ||
        t.contains('dim sum') ||
        t.contains('nasi') ||
        t.contains('laksa') ||
        t.contains('roti'));
  }

  /// Check if a place is a dessert or tea/snack stop
  static bool isDessertPlace(PlaceModel place) {
    final tags = place.interestTags.map((t) => t.toLowerCase()).toList();
    final name = place.name.toLowerCase();
    final desc = place.description.toLowerCase();
    return tags.any((t) =>
            t.contains('dessert') ||
            t.contains('chendul') ||
            t.contains('cendol') ||
            t.contains('ice cream') ||
            t.contains('tong shui') ||
            t.contains('pastry') ||
            t.contains('bakery') ||
            t.contains('cafe') ||
            t.contains('tea')) ||
        name.contains('dessert') ||
        name.contains('chendul') ||
        name.contains('cendol') ||
        name.contains('ice cream') ||
        name.contains('tong shui') ||
        desc.contains('dessert') ||
        desc.contains('chendul') ||
        desc.contains('cendol');
  }

  /// Check if a place is a morning dim sum or traditional breakfast place
  static bool isDimSumOrMorningFood(PlaceModel place) {
    final tags = place.interestTags.map((t) => t.toLowerCase()).toList();
    final name = place.name.toLowerCase();
    return tags.any((t) =>
            t.contains('dim sum') ||
            t.contains('kopitiam') ||
            t.contains('roti canai') ||
            t.contains('nasi lemak') ||
            t.contains('breakfast')) ||
        name.contains('dim sum') ||
        name.contains('kopitiam') ||
        name.contains('roti canai');
  }

  /// Find candidate food stops suitable for a specific meal
  static List<PlaceModel> filterPlacesForMeal({
    required List<PlaceModel> availablePlaces,
    required String mealType,
    required Set<String> excludedPlaceIds,
  }) {
    return availablePlaces.where((p) {
      if (!p.isActive || excludedPlaceIds.contains(p.placeId)) return false;
      if (!isFoodPlace(p)) return false;

      final mealLower = mealType.toLowerCase();
      final tags = p.interestTags.map((t) => t.toLowerCase()).toSet();
      final name = p.name.toLowerCase();

      if (mealLower == 'breakfast') {
        return tags.contains('breakfast') ||
            tags.contains('kopitiam') ||
            tags.contains('dim sum') ||
            tags.contains('roti canai') ||
            tags.contains('nasi lemak') ||
            tags.contains('hawker') ||
            tags.contains('cafe') ||
            name.contains('kopitiam') ||
            name.contains('dim sum') ||
            name.contains('roti') ||
            p.category.toLowerCase() == 'food';
      }

      if (mealLower == 'lunch') {
        return tags.contains('lunch') ||
            tags.contains('restaurant') ||
            tags.contains('hawker') ||
            tags.contains('nasi kandar') ||
            tags.contains('laksa') ||
            tags.contains('local food') ||
            p.category.toLowerCase() == 'food';
      }

      if (mealLower == 'dinner') {
        return tags.contains('dinner') ||
            tags.contains('restaurant') ||
            tags.contains('night market') ||
            tags.contains('seafood') ||
            tags.contains('street food') ||
            p.category.toLowerCase() == 'food';
      }

      return true;
    }).toList();
  }

  /// Select the single best dessert stop that fits into remaining schedule time
  static PlaceModel? selectDessertCandidate({
    required List<PlaceModel> availablePlaces,
    required Set<String> alreadyUsedIds,
    required int remainingMinutes,
    PlaceModel? referenceLocation,
  }) {
    final candidates = availablePlaces.where((p) {
      if (!p.isActive || alreadyUsedIds.contains(p.placeId)) return false;
      return isDessertPlace(p);
    }).toList();

    if (candidates.isEmpty) return null;

    PlaceModel? bestCandidate;
    double bestScore = -1.0;

    for (final candidate in candidates) {
      final travel = referenceLocation != null
          ? estimateTravelMinutes(referenceLocation, candidate)
          : 10;
      final requiredTime = candidate.estimatedVisitMinutes + travel;

      if (requiredTime > remainingMinutes) continue;

      double score = candidate.publicRating * 10.0;
      if (candidate.isVerified) score += 5.0;
      if (travel <= 15) score += 5.0;

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  /// Distance-based Haversine travel calculation between two locations
  static int estimateTravelMinutes(PlaceModel from, PlaceModel to) {
    if (from.latitude == 0 || to.latitude == 0) return 12;
    final dLat = (to.latitude - from.latitude) * 111.0;
    final dLng = (to.longitude - from.longitude) * 111.0 * cos(from.latitude * pi / 180);
    final distanceKm = sqrt(dLat * dLat + dLng * dLng);

    if (distanceKm <= 1.0) return 6;
    if (distanceKm <= 3.0) return 10;
    if (distanceKm <= 7.0) return 15;
    if (distanceKm <= 15.0) return 22;
    return 30;
  }
}

/// Independent tracker for daily meal slots to prevent cross-day pollution
class DayMealTracker {
  bool hasBreakfast = false;
  bool hasLunch = false;
  bool hasDinner = false;
  bool hasDessert = false;
  bool hasDimSum = false;

  void reset() {
    hasBreakfast = false;
    hasLunch = false;
    hasDinner = false;
    hasDessert = false;
    hasDimSum = false;
  }

  bool canServe(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return !hasBreakfast;
      case 'lunch':
        return !hasLunch;
      case 'dinner':
        return !hasDinner;
      case 'dessert':
        return !hasDessert;
      case 'dim sum':
      case 'dim_sum':
        return !hasDimSum && !hasBreakfast;
      default:
        return true;
    }
  }

  void markServed(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        hasBreakfast = true;
        break;
      case 'lunch':
        hasLunch = true;
        break;
      case 'dinner':
        hasDinner = true;
        break;
      case 'dessert':
        hasDessert = true;
        break;
      case 'dim sum':
      case 'dim_sum':
        hasDimSum = true;
        hasBreakfast = true;
        break;
    }
  }
}
