import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/safety_config.dart';

enum OffRouteState { onRoute, suspect, confirmed }

/// Filters route deviation into a persistent, accuracy-aware off-route signal.
///
/// The detector deliberately owns no GPS stream. The navigation session feeds
/// it fixes from the one existing foreground stream.
class OffRouteDetector {
  OffRouteDetector({
    this.offRouteDistanceMeters = SafetyConfig.navigationOffRouteDistanceMeters,
    this.recoveryDistanceMeters =
        SafetyConfig.navigationOffRouteRecoveryDistanceMeters,
    this.requiredConsecutiveFixes =
        SafetyConfig.navigationOffRouteConsecutiveFixes,
    this.minimumDuration = SafetyConfig.navigationOffRouteMinimumDuration,
    this.minimumMovementMeters =
        SafetyConfig.navigationOffRouteMinimumMovementMeters,
    this.maximumAccuracyMeters =
        SafetyConfig.navigationRerouteMaximumAccuracyMeters,
  });

  final double offRouteDistanceMeters;
  final double recoveryDistanceMeters;
  final int requiredConsecutiveFixes;
  final Duration minimumDuration;
  final double minimumMovementMeters;
  final double maximumAccuracyMeters;

  OffRouteState _state = OffRouteState.onRoute;
  int _consecutiveFixes = 0;
  DateTime? _firstSuspectAt;
  LatLng? _firstSuspectPosition;

  OffRouteState get state => _state;
  int get consecutiveFixes => _consecutiveFixes;

  /// Returns the updated state. [confirmed] is sticky until the user returns
  /// within the recovery boundary or [reset] is called after route replacement.
  OffRouteState evaluate({
    required double distanceFromRouteMeters,
    required LatLng position,
    required DateTime timestamp,
    double? accuracyMeters,
  }) {
    if (!distanceFromRouteMeters.isFinite || distanceFromRouteMeters < 0) {
      return _state;
    }
    final accuracyIsUsable =
        accuracyMeters != null &&
        accuracyMeters.isFinite &&
        accuracyMeters >= 0 &&
        accuracyMeters <= maximumAccuracyMeters;
    if (!accuracyIsUsable) {
      _clearSuspect();
      return _state;
    }

    final recoveryBoundary = recoveryDistanceMeters + accuracyMeters;
    if (distanceFromRouteMeters <= recoveryBoundary) {
      reset();
      return _state;
    }

    // Reported accuracy expands the trigger boundary so normal GPS scatter
    // cannot create a false wrong-turn event.
    final triggerBoundary = offRouteDistanceMeters + accuracyMeters;
    if (distanceFromRouteMeters <= triggerBoundary) {
      if (_state != OffRouteState.confirmed) _clearSuspect();
      return _state;
    }
    if (_state == OffRouteState.confirmed) return _state;

    _state = OffRouteState.suspect;
    _consecutiveFixes++;
    _firstSuspectAt ??= timestamp;
    _firstSuspectPosition ??= position;
    final elapsed = timestamp.difference(_firstSuspectAt!);
    final moved = const Distance().as(
      LengthUnit.Meter,
      _firstSuspectPosition!,
      position,
    );
    if (_consecutiveFixes >= requiredConsecutiveFixes &&
        elapsed >= minimumDuration &&
        moved >= minimumMovementMeters) {
      _state = OffRouteState.confirmed;
    }
    return _state;
  }

  void reset() {
    _state = OffRouteState.onRoute;
    _consecutiveFixes = 0;
    _firstSuspectAt = null;
    _firstSuspectPosition = null;
  }

  void _clearSuspect() {
    if (_state == OffRouteState.confirmed) return;
    reset();
  }

  @visibleForTesting
  DateTime? get firstSuspectAt => _firstSuspectAt;
}
