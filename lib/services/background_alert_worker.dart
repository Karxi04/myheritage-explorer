import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/safety_config.dart';
import '../firebase_options.dart';
import '../models/hazard_report.dart';
import '../services/alert_cooldown_store.dart';
import '../services/background_location_permission_service.dart';
import '../services/confidence_analysis_service.dart';
import '../services/hazard_map_service.dart';
import '../services/hazard_report_service.dart';
import '../services/hazard_vote_service.dart';
import '../services/location_service.dart';
import '../services/mobile_notification_service.dart';
import '../services/safety_alert_priority_service.dart';

/// WorkManager task name for the periodic background safety check.
const _kBackgroundTaskName = 'safety_proximity_check';

/// WorkManager unique task identifier.
const _kBackgroundTaskId = 'com.myheritage.safety.proximity';

/// Top-level WorkManager callback. MUST be a top-level function (not a
/// class method) because WorkManager spawns a fresh Dart isolate.
@pragma('vm:entry-point')
void backgroundAlertDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _kBackgroundTaskName) return true;
    // Step 12 background execution is strictly Android-only.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      await _runBackgroundCheck();
    } catch (e, st) {
      debugPrint('Background safety check failed: $e\n$st');
    }
    return true;
  });
}

/// Registers the periodic background task on Android. Safe to call multiple times;
/// [ExistingPeriodicWorkPolicy.keep] skips re-registration when already scheduled.
Future<void> registerBackgroundSafetyWorker() async {
  // Step 12 background execution is strictly Android-only.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().registerPeriodicTask(
      _kBackgroundTaskId,
      _kBackgroundTaskName,
      // Android enforces a minimum of 15 minutes.
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e, st) {
    debugPrint('Could not register background safety worker: $e\n$st');
  }
}

/// Cancels the periodic background task.
Future<void> cancelBackgroundSafetyWorker() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().cancelByUniqueName(_kBackgroundTaskId);
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Internal implementation
// ---------------------------------------------------------------------------

Future<void> _runBackgroundCheck() async {
  // 1. Check background location permission before performing background work.
  const permissionService = BackgroundLocationPermissionService();
  if (!await permissionService.hasBackgroundPermission()) {
    debugPrint(
      'Background safety check: background permission not granted; skipping.',
    );
    return;
  }

  // 2. Bootstrap Flutter + Firebase in the background isolate.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileNotificationService.instance.initialize();

  // 3. Obtain current position.
  final position = await _safeCurrentPosition();
  if (position == null) {
    debugPrint('Background safety check: position unavailable');
    return;
  }

  // 4. Fetch active Verified hazards directly from the server.
  // Avoids evaluating against a stale-first local cache snapshot and skips
  // the background cycle safely if offline or if the fetch times out.
  List<HazardReport> reports;
  try {
    reports = HazardMapService.activeReports(
      await HazardReportService().getVerifiedReportsFromServer(
        timeout: const Duration(seconds: 10),
      ),
    );
  } catch (e) {
    debugPrint(
      'Background safety check: fresh server hazard fetch failed ($e) — skipping cycle.',
    );
    return;
  }

  if (reports.isEmpty) return;

  // 5. Pre-filter hazards by proximity. Only hazards within danger radius are
  // evaluated further, minimizing downstream vote reads.
  const locationService = LocationService();
  final nearbyCandidates = <({HazardReport report, double distance})>[];
  for (final report in reports) {
    final distance = locationService.distanceBetween(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: report.latitude,
      endLongitude: report.longitude,
    );
    if (distance <= SafetyConfig.dangerRadiusForSeverity(report.severity)) {
      nearbyCandidates.add((report: report, distance: distance));
    }
  }

  if (nearbyCandidates.isEmpty) return;

  // 6. For candidate hazards within danger radius, fetch only necessary lightweight
  // confirmation votes for exact parity with foreground priority calculation.
  const confidenceService = ConfidenceAnalysisService();
  final voteService = HazardVoteService();
  const priorityService = SafetyAlertPriorityService();
  final candidates = <SafetyAlertCandidate>[];

  for (final candidate in nearbyCandidates) {
    double? existsConfirmationScore;
    try {
      final votes = await voteService.getVotes(candidate.report.id);
      final analysis = confidenceService.analyze(votes);
      if (analysis.totalRecentVotes > 0) {
        existsConfirmationScore = analysis.recentExistsConfirmationScore;
      }
    } catch (e) {
      debugPrint(
        'Background vote check fallback for ${candidate.report.id}: $e',
      );
      // Neutral score fallback applies when vote read fails.
    }

    final priority = priorityService.calculate(
      severity: candidate.report.severity,
      distanceMeters: candidate.distance,
      existsConfirmationScore: existsConfirmationScore,
    );
    candidates.add(
      SafetyAlertCandidate(
        report: candidate.report,
        distanceMeters: candidate.distance,
        priority: priority,
      ),
    );
  }

  // 7. Load persisted cooldown timestamps and priorities.
  const cooldownStore = AlertCooldownStore();
  final persistedCooldowns = await cooldownStore.loadAll();
  final persistedPriorities = await cooldownStore.loadPriorities();
  await cooldownStore.pruneInactive(reports.map((r) => r.id).toSet());

  // 8. Select the highest-priority eligible candidate respecting cooldown and escalation.
  final selected = priorityService.selectAlert(
    candidates,
    lastAlertedAt: persistedCooldowns,
    lastPriority: persistedPriorities,
  );

  if (selected == null) return;

  // 9. Deliver notification. Record cooldown ONLY on successful presentation.
  final delivered = await MobileNotificationService.instance.showProximityAlert(
    report: selected.report,
    distanceMeters: selected.distanceMeters,
  );

  if (delivered) {
    await cooldownStore.recordAlert(
      selected.report.id,
      now: DateTime.now(),
      priority: selected.priority.priorityScore,
    );
  } else {
    debugPrint(
      'Background safety alert: notification was not delivered; cooldown not recorded.',
    );
  }
}

Future<dynamic> _safeCurrentPosition() async {
  try {
    return await const LocationService().getCurrentPosition();
  } catch (_) {
    return null;
  }
}
