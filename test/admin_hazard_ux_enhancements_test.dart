import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:myheritage_explorer/admin/admin_pages.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/core/explorer_ui.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/services/hazard_address_resolver.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';
import 'package:myheritage_explorer/services/place_geocoding_service.dart';

class _FakeGeocodingService extends PlaceGeocodingService {
  _FakeGeocodingService({
    this.completer,
    this.shouldFail = false,
    this.displayName = 'Batu Ferringhi',
    this.address = 'Penang',
  });

  final Completer<NavigationStop>? completer;
  final bool shouldFail;
  final String displayName;
  final String address;
  int callCount = 0;

  @override
  Future<NavigationStop> reverseGeocode(
    latlng.LatLng target, {
    String? preferredLanguage,
  }) async {
    callCount++;
    if (completer != null) {
      return completer!.future;
    }
    if (shouldFail) {
      throw Exception('Reverse geocoding failed');
    }
    return NavigationStop(
      id: 'stop_test',
      displayName: displayName,
      address: address,
      location: target,
    );
  }
}

class _TestReportService implements HazardReportService {
  _TestReportService({
    this.pending = const [],
    this.verified = const [],
    this.resolved = const [],
    this.rejected = const [],
  });

  final List<HazardReport> pending;
  final List<HazardReport> verified;
  final List<HazardReport> resolved;
  final List<HazardReport> rejected;

  List<HazardReport> get all => [
    ...pending,
    ...verified,
    ...resolved,
    ...rejected,
  ];

  @override
  Stream<List<HazardReport>> watchAllReports() => Stream.value(all);

  @override
  Stream<List<HazardReport>> watchPendingReports() => Stream.value(pending);

  @override
  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() =>
      Stream.value(verified);

  @override
  Stream<List<HazardReport>> watchReportsByStatus(String status) {
    return switch (status) {
      HazardReportStatus.pendingReview => Stream.value(pending),
      HazardReportStatus.verified => Stream.value(verified),
      HazardReportStatus.resolved => Stream.value(resolved),
      HazardReportStatus.rejected => Stream.value(rejected),
      _ => Stream.value(const []),
    };
  }

  @override
  Stream<List<HazardReport>> watchResolvedReports() => Stream.value(resolved);

  @override
  Stream<List<HazardReport>> watchRejectedReports() => Stream.value(rejected);

  @override
  Stream<HazardReport?> watchReport(String id) {
    final match = all.where((r) => r.id == id).firstOrNull;
    return Stream.value(match);
  }

  @override
  Stream<List<HazardAuditEntry>> watchAuditTrail(String id) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestVoteService implements HazardVoteService {
  @override
  Stream<List<HazardVote>> watchVotes(String id) => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HazardReport _makeReport({
  required String id,
  required String status,
  double lat = 5.4660,
  double lon = 100.2450,
  String category = 'Pothole',
  String description = 'Deep pothole on the main street.',
}) {
  return HazardReport(
    id: id,
    userId: 'user_1',
    category: category,
    severity: 'High',
    description: description,
    latitude: lat,
    longitude: lon,
    status: status,
    createdAt: DateTime(2026, 9, 8, 14, 30),
    hasPhotoEvidence: false,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    HazardAddressResolver.clearCache();
  });

  tearDown(() {
    HazardAddressResolver.clearCache();
  });

  group('Enhancement 1: Human-Readable Location & Caching', () {
    test(
      'HazardAddressResolver deduplicates in-flight requests for identical coordinates',
      () async {
        final completer = Completer<NavigationStop>();
        final geocoder = _FakeGeocodingService(completer: completer);

        // Initiate first call
        final future1 = HazardAddressResolver.resolve(
          latitude: 5.4660,
          longitude: 100.2450,
          geocodingService: geocoder,
        );

        // Initiate second call with identical coordinates while first is still pending
        final future2 = HazardAddressResolver.resolve(
          latitude: 5.4660,
          longitude: 100.2450,
          geocodingService: geocoder,
        );

        // geocoder should have only been invoked once
        expect(geocoder.callCount, 1);

        // Complete the pending request
        completer.complete(
          NavigationStop(
            id: 'stop_dedup',
            displayName: 'Batu Ferringhi',
            address: 'Penang',
            location: const latlng.LatLng(5.4660, 100.2450),
          ),
        );

        final result1 = await future1;
        final result2 = await future2;

        expect(result1.primaryName, 'Batu Ferringhi');
        expect(result2.primaryName, 'Batu Ferringhi');
        expect(geocoder.callCount, 1);

        // Subsequent call hits cache directly
        final result3 = await HazardAddressResolver.resolve(
          latitude: 5.4660,
          longitude: 100.2450,
          geocodingService: geocoder,
        );
        expect(result3.primaryName, 'Batu Ferringhi');
        expect(geocoder.callCount, 1);
      },
    );

    testWidgets(
      'Admin list card displays clean resolving state while address is loading',
      (tester) async {
        final completer = Completer<NavigationStop>();
        final geocoder = _FakeGeocodingService(completer: completer);

        final report = _makeReport(
          id: 'test_resolving',
          status: HazardReportStatus.pendingReview,
          lat: 5.4660,
          lon: 100.2450,
        );

        // Initiate resolve in resolver using the controlled geocoder
        HazardAddressResolver.resolve(
          latitude: 5.4660,
          longitude: 100.2450,
          geocodingService: geocoder,
        );

        final service = _TestReportService(pending: [report]);

        await tester.pumpWidget(
          _wrap(AdminPendingReportsTab(reportService: service)),
        );
        await tester.pump();

        // While resolving, shows clean neutral indicator with GPS secondary info
        expect(
          find.textContaining('Resolving location... • GPS: 5.4660, 100.2450'),
          findsOneWidget,
        );

        // Complete geocoding
        completer.complete(
          NavigationStop(
            id: 'stop_1',
            displayName: 'Batu Ferringhi',
            address: 'Penang',
            location: const latlng.LatLng(5.4660, 100.2450),
          ),
        );

        await tester.pumpAndSettle();

        // Resolves to human-readable address with GPS secondary info
        expect(
          find.textContaining('Batu Ferringhi, Penang • GPS: 5.4660, 100.2450'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Admin list card immediately renders cached address without resolving flicker',
      (tester) async {
        // Pre-populate cache
        HazardAddressResolver.setCacheEntry(
          5.4660,
          100.2450,
          const HazardAddressDetails(
            primaryName: 'Batu Ferringhi',
            secondaryAddress: 'Penang',
            coordinatesText: '5.46600, 100.24500',
            isGeocoded: true,
          ),
        );

        final report = _makeReport(
          id: 'test_cached',
          status: HazardReportStatus.pendingReview,
          lat: 5.4660,
          lon: 100.2450,
        );

        final service = _TestReportService(pending: [report]);

        await tester.pumpWidget(
          _wrap(AdminPendingReportsTab(reportService: service)),
        );
        await tester.pump();

        // Directly shows cached name without showing resolving message
        expect(
          find.textContaining('Batu Ferringhi, Penang • GPS: 5.4660, 100.2450'),
          findsOneWidget,
        );
        expect(find.textContaining('Resolving location...'), findsNothing);
      },
    );

    testWidgets(
      'Admin list card falls back to Location unavailable on geocoding failure',
      (tester) async {
        final geocoder = _FakeGeocodingService(shouldFail: true);

        final report = _makeReport(
          id: 'test_fail',
          status: HazardReportStatus.pendingReview,
          lat: 5.4660,
          lon: 100.2450,
        );

        // Populate in-flight failure via resolver
        await HazardAddressResolver.resolve(
          latitude: 5.4660,
          longitude: 100.2450,
          geocodingService: geocoder,
        );

        final service = _TestReportService(pending: [report]);

        await tester.pumpWidget(
          _wrap(AdminPendingReportsTab(reportService: service)),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Location unavailable • GPS: 5.4660, 100.2450'),
          findsOneWidget,
        );
      },
    );
  });

  group('Enhancement 2: Interactive Metric Cards & Status Tabs', () {
    testWidgets(
      'ExplorerMetricCard responds to onTap and displays selected state',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _wrap(
            ExplorerMetricCard(
              label: 'Test Metric',
              value: '42',
              icon: Icons.star,
              isSelected: true,
              onTap: () => tapped = true,
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);
        expect(find.text('Test Metric'), findsOneWidget);

        await tester.tap(find.byType(ExplorerMetricCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'AdminHazardsPage renders all 4 metric cards and 4 tabs',
      (tester) async {
        final service = _TestReportService(
          pending: [_makeReport(id: 'p1', status: HazardReportStatus.pendingReview)],
          verified: [_makeReport(id: 'v1', status: HazardReportStatus.verified)],
          resolved: [_makeReport(id: 'r1', status: HazardReportStatus.resolved)],
          rejected: [_makeReport(id: 'x1', status: HazardReportStatus.rejected)],
        );

        await tester.pumpWidget(
          _wrap(AdminHazardsPage(reportService: service)),
        );
        await tester.pumpAndSettle();

        // 4 metric card labels exist
        expect(find.text('Pending Review'), findsOneWidget);
        expect(find.text('Verified Hazards'), findsOneWidget);
        expect(find.text('Resolved Reports'), findsOneWidget);
        expect(find.text('Rejected Reports'), findsOneWidget);

        // Tab headers exist
        expect(find.text('Pending Reports (1)'), findsOneWidget);
        expect(find.text('Verified Hazards (1)'), findsOneWidget);
        expect(find.text('Resolved Reports (1)'), findsOneWidget);
        expect(find.text('Rejected Reports (1)'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping metric cards animates to the corresponding tab',
      (tester) async {
        final service = _TestReportService(
          pending: [_makeReport(id: 'p1', status: HazardReportStatus.pendingReview)],
          verified: [_makeReport(id: 'v1', status: HazardReportStatus.verified)],
          resolved: [_makeReport(id: 'r1', status: HazardReportStatus.resolved)],
          rejected: [_makeReport(id: 'x1', status: HazardReportStatus.rejected)],
        );

        await tester.pumpWidget(
          _wrap(AdminHazardsPage(reportService: service)),
        );
        await tester.pumpAndSettle();

        // Default tab is Pending
        expect(find.text('Review Report'), findsOneWidget);

        // Tap Resolved Reports metric card
        await tester.tap(find.text('Resolved Reports'));
        await tester.pumpAndSettle();

        // Resolved tab is visible with View Report action
        expect(find.text('RESOLVED'), findsOneWidget);
        expect(find.text('View Report'), findsOneWidget);

        // Tap Rejected Reports metric card
        await tester.tap(find.text('Rejected Reports'));
        await tester.pumpAndSettle();

        // Rejected tab is visible with View Report action
        expect(find.text('REJECTED'), findsOneWidget);
        expect(find.text('View Report'), findsOneWidget);
      },
    );

    testWidgets(
      'initialStatusFilter navigates directly to requested status tab',
      (tester) async {
        final service = _TestReportService(
          resolved: [_makeReport(id: 'r_direct', status: HazardReportStatus.resolved)],
        );

        await tester.pumpWidget(
          _wrap(
            AdminHazardsPage(
              initialStatusFilter: 'resolved',
              reportService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('RESOLVED'), findsOneWidget);
        expect(find.text('View Report'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminHazardManagementPage with initialStatusFilter renders AdminHazardsPage',
      (tester) async {
        final service = _TestReportService(
          rejected: [_makeReport(id: 'rej_1', status: HazardReportStatus.rejected)],
        );

        await tester.pumpWidget(
          _wrap(
            AdminHazardManagementPage(
              initialStatusFilter: 'rejected',
              reportService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('REJECTED'), findsOneWidget);
        expect(find.text('Rejected Reports'), findsOneWidget);
      },
    );

    testWidgets(
      'Resolved and Rejected hazards in detail view are read-only (only Close button)',
      (tester) async {
        final resolvedReport = _makeReport(
          id: 'resolved_detail',
          status: HazardReportStatus.resolved,
        );
        final service = _TestReportService(resolved: [resolvedReport]);
        final voteService = _TestVoteService();

        await tester.pumpWidget(
          _wrap(
            AdminHazardManagementPage(
              hazardId: 'resolved_detail',
              reportService: service,
              voteService: voteService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Action bar has only Close, no Verify or Reject buttons
        expect(find.text('Close'), findsOneWidget);
        expect(find.text('Verify & Publish'), findsNothing);
        expect(find.text('Reject'), findsNothing);
        expect(find.text('Mark Resolved'), findsNothing);
      },
    );
  });
}
