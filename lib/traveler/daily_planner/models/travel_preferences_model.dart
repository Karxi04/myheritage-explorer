import '../services/malaysia_location_service.dart';

class TravelPreferences {
  TravelPreferences({
    required this.stateId,
    String? stateName,
    this.selectedArea = 'All Areas',
    DateTime? startDate,
    DateTime? endDate,
    this.dailyStartMinutes = 540,
    this.availableHours = 4.0,
    this.interests = const ['Heritage', 'Culture', 'Food'],
    this.budget = 'Medium',
    this.pace = 'Balanced',
    this.foodExplorationEnabled = false,
  })  : stateName = stateName ?? MalaysiaLocationService.getStateName(stateId),
        startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? (startDate ?? DateTime.now());

  final String stateId;
  final String stateName;
  final String selectedArea;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyStartMinutes; // e.g. 9 * 60 = 540
  final double availableHours;
  final List<String> interests;
  final String budget; // 'Low', 'Medium', 'High'
  final String pace; // 'Relaxed', 'Balanced', 'Fast'
  final bool foodExplorationEnabled;

  int get numberOfDays {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = e.difference(s).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  int get dayCount => numberOfDays;

  bool get isValid => validate() == null;

  String get dailyStartTimeLabel {
    final h = (dailyStartMinutes ~/ 60) % 24;
    final m = dailyStartMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  String get dailyEndTimeLabel {
    final endMinutes = dailyStartMinutes + (availableHours * 60).round();
    final h = (endMinutes ~/ 60) % 24;
    final m = endMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  String? validate() {
    if (stateId.trim().isEmpty || stateName.trim().isEmpty) {
      return 'Please select a Malaysian state.';
    }
    if (selectedArea.trim().isEmpty) {
      return 'Please select an area or city in $stateName.';
    }
    if (interests.isEmpty) {
      return 'Please select at least one travel interest.';
    }
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    if (e.isBefore(s)) {
      return 'End date cannot be before start date.';
    }
    if (numberOfDays < 1) {
      return 'Itinerary duration must be at least 1 day.';
    }
    if (availableHours <= 0 || availableHours > 16) {
      return 'Daily available hours must be between 1 and 16 hours.';
    }
    return null;
  }
}
