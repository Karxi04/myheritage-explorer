# Safety module audit — 5 September 2026

Scope: Crowdsourced Safety Mapping & Hazard Alerts only. Existing uncommitted work is preserved. Initial classifications are based on source inspection, not a live Firebase/device certification.

## A. Initial feature inventory

| # | Feature | Initial status | Relevant files (under lib unless noted) | Initial issue |
|---|---|---|---|---|
| 1 | Create Hazard Report | PARTIALLY IMPLEMENTED | traveler/safety/create_hazard_page.dart; services/hazard_report_service.dart | Inline validation, stale GPS, submission guard |
| 2 | Danger Zone Map | PARTIALLY IMPLEMENTED | traveler/safety/danger_zone_map_page.dart; services/hazard_map_service.dart | No recenter/retry/attribution; caller-only status filtering |
| 3 | Hazard Details | PRESENT BUT BROKEN | traveler/safety/hazard_detail_page.dart | Null document trapped in loading; no back control on error |
| 4 | My Reports / status history | PARTIALLY IMPLEMENTED | traveler/safety/my_hazard_reports_page.dart | Null auth assertion; crowded mobile rows |
| 5 | Report status notification | PARTIALLY IMPLEMENTED | services/notification_service.dart; services/mobile_notification_service.dart | Atomic inbox notification exists; device tap route absent |
| 6 | Automatic safety alert | PARTIALLY IMPLEMENTED | traveler/safety/hazard_proximity_monitor.dart | Nearest hazard masks others, uncaught listener failures, lifecycle leaks |
| 7 | Review Hazard Alert | PARTIALLY IMPLEMENTED | traveler/safety/safety_alert_page.dart | Missing-document loading; stale location; no refresh |
| 8 | GPS-validated voting | PARTIALLY IMPLEMENTED | services/hazard_vote_service.dart | Transaction checks status/duplicate; negative/nonfinite input not rejected locally |
| 9 | Hazard Still Exists | COMPLETE | models/hazard_vote.dart; services/hazard_vote_service.dart | HAZARD_EXISTS persisted |
| 10 | Hazard Appears Resolved | COMPLETE | same as above | HAZARD_RESOLVED persisted; admin remains final authority |
| 11 | Optional vote photo | PARTIALLY IMPLEMENTED | widgets/evidence_picker_card.dart | Camera only; gallery callback ignored |
| 12 | Evidence validation | PARTIALLY IMPLEMENTED | services/evidence_image_validation_service.dart | Quality/hash heuristics exist; semantic recognition absent |
| 13 | Smart alert priority | PARTIALLY IMPLEMENTED | services/safety_alert_priority_service.dart | Formula exists but monitor chooses nearest before scoring |
| 14 | Itinerary warning | COMPLETE | services/itinerary_safety_service.dart; traveler/daily_planner/itinerary_detail_page.dart | Warning only when nonempty; malformed coordinates can throw |
| 15 | Pending request list | COMPLETE | admin/hazards/admin_pending_reports_tab.dart | Responsive row and error-state polish needed |
| 16 | Manage request | COMPLETE | admin/hazards/admin_hazard_management_page.dart | Repeated reporter reads, technical errors |
| 17 | Verify | COMPLETE | services/hazard_report_service.dart | Transaction writes Verified plus owner notification |
| 18 | Reject | COMPLETE | same as above | Transaction writes Rejected plus owner notification |
| 19 | Verified list | COMPLETE | admin/hazards/admin_verified_reports_tab.dart | Per-row vote streams; error can appear as zero evidence |
| 20 | Manage verified hazard | COMPLETE | admin/hazards/admin_hazard_management_page.dart | Working decision controls |
| 21 | Review community evidence | PARTIALLY IMPLEMENTED | admin/hazards/admin_hazard_shared_widgets.dart | Missing image error handling; misleading similarity percentage |
| 22 | Resolution analytics | PARTIALLY IMPLEMENTED | services/confidence_analysis_service.dart | Old/future/negative-distance votes; 60-minute count labelled 15 minutes |
| 23 | Keep Verified | COMPLETE | admin/hazards/admin_hazard_management_page.dart | Closes review, intentionally no status mutation/audit event |
| 24 | Mark Resolved | COMPLETE | services/hazard_report_service.dart | Transaction hides report from Verified queries; owner notified |
| 25 | Firebase Auth | PARTIALLY IMPLEMENTED | core/services.dart; firebase_rules/safety_module.firestore.rules | Client auth + role rules exist; deployed rules not inspected |
| 26 | Firestore storage | COMPLETE | services/hazard_report_service.dart; services/hazard_vote_service.dart | Atomic report/photo and vote/photo writes |
| 27 | Firebase Storage upload | NOT IMPLEMENTED | services/hazard_report_service.dart | Deliberately uses Firestore blobs (400 KiB); legacy URLs still render |
| 28 | Location permission handling | PARTIALLY IMPLEMENTED | services/location_service.dart; core/helpers.dart | Timeout exists, permission messaging and lifecycle retry needed |
| 29 | Distance calculation | PARTIALLY IMPLEMENTED | services/location_service.dart | Geolocator used; invalid coordinates not filtered |
| 30 | OpenStreetMap | PARTIALLY IMPLEMENTED | services/hazard_map_service.dart | flutter_map configured; attribution/control gaps |
| 31 | Notification handling | PARTIALLY IMPLEMENTED | services/mobile_notification_service.dart | Local notifications only; no remote push/background tracking |
| 32 | Cooldown | PARTIALLY IMPLEMENTED | traveler/safety/hazard_proximity_monitor.dart | Per-hazard memory cooldown; no stationary re-evaluation |
| 33 | Duplicate vote prevention | COMPLETE | services/hazard_vote_service.dart; rules | Transaction + UID document + immutable votes |
| 34 | Duplicate image detection | PARTIALLY IMPLEMENTED | evidence_image_validation_service.dart; hazard_report_service.dart | SHA/average hash against own history; not globally verified |
| 35 | Evidence quality | COMPLETE | services/evidence_image_validation_service.dart | Format/size/resolution/sharpness/exposure; low quality allowed without bonus |
| 36 | Confidence calculation | PARTIALLY IMPLEMENTED | services/confidence_analysis_service.dart | Sample floor exists, freshness defects |
| 37 | Tourist mobile UI | PARTIALLY IMPLEMENTED | traveler/safety/*; widgets/evidence_picker_card.dart | Crowded rows, tiny text, raw errors, uneven severity widths |
| 38 | Admin web UI | PARTIALLY IMPLEMENTED | admin/hazards/* | Narrow overflow, redundant analytics panels, misleading AI wording |

## Initial workflow and UI findings

The source connects creation → Pending Review → admin Verify/Reject → owner notification → Verified query → map/alert → confirmation transaction → live analytics → admin Resolve → removal from Verified queries. Main broken connections: missing documents never leave loading, device notification taps do not navigate, stale GPS authorizes confirmations, nearest cooling-down hazard masks others, listener errors can interrupt alerts, and old votes can masquerade as current confidence. The actual deployment and physical-device workflow remain to be tested.

Before UI edits: landing page leads with a large instructional card and a small map; severity gap padding makes High wider; descriptions can dominate lists; photo picker is camera-only with verbose diagnostics; alert review uses red regardless of priority; admin calls a deterministic formula “AI” and presents discrete hash buckets as a similarity percentage; reporter UID leaks into fallback display; narrow admin rows and status/date rows can overflow.

## Implementation and verification

Completed in source and in local automated verification. Live Firebase deployment and physical-device certification were intentionally not performed.

## A. Current feature inventory

`Complete` below means the source path is connected and locally verified. It does not replace the device and deployed-Firebase checks called out in sections H and I.

| # | Feature | Final status | Result |
|---|---|---|---|
| 1 | Create Hazard Report | Complete | Required photo, fresh GPS, validation, guarded submit and atomic report/evidence write |
| 2 | Danger Zone Map | Complete | Only literal `Verified` reports with valid coordinates; severity radii, recenter, retry and attribution |
| 3 | Hazard Details | Complete | Missing/error/loading states terminate correctly and navigation remains available |
| 4 | My Reports / status history | Complete | Nullable authentication, readable mobile layout and status history |
| 5 | Report status notification | Partial | Atomic in-app notification and local-device tap routing; no background push service |
| 6 | Automatic safety alert | Partial | Foreground lifecycle, priority, radius, cooldown and escalation work; closed-app monitoring is not implemented |
| 7 | Review Hazard Alert | Complete | Fresh GPS, latest-status recheck, retry and disabled busy states |
| 8 | GPS-validated voting | Partial | Client and rules enforce declared distance/band/status; GPS truth is still supplied by the client |
| 9 | Hazard Still Exists | Complete | Persisted once per user in a Firestore transaction |
| 10 | Hazard Appears Resolved | Complete | Persisted as advisory evidence; administrator remains final authority |
| 11 | Optional vote photo | Complete | Camera and gallery paths, quality feedback, remove/retry and guarded controls |
| 12 | Evidence validation | Partial | Decode, format, size, resolution, sharpness, exposure and duplicate heuristics; no semantic hazard recognition |
| 13 | Smart alert priority | Complete | All candidates are scored before selection; cooling hazards cannot mask another valid alert |
| 14 | Itinerary warning | Complete | Verified valid hazards within 500 m only; malformed stops are ignored safely |
| 15 | Pending request list | Complete | Cached stream, loading/error/empty states and responsive layout |
| 16 | Manage request | Complete | Reporter details, evidence, confirmation dialogs and stale-decision protection |
| 17 | Verify | Complete | Allowed transition, audit fields and owner notification are atomic |
| 18 | Reject | Complete | Allowed transition, removal from pending flow and owner notification are atomic |
| 19 | Verified list | Complete | Community evidence loading failures no longer appear as zero evidence |
| 20 | Manage verified hazard | Complete | Community analytics and guarded Keep Verified / Mark Resolved actions |
| 21 | Review community evidence | Complete | Recoverable images, quality metadata and honest visual-pattern labels |
| 22 | Resolution analytics | Complete | Exact 15-minute sample, one-hour weighting and invalid/future vote exclusion |
| 23 | Keep Verified | Complete | Leaves official state unchanged after administrator review |
| 24 | Mark Resolved | Complete | Atomic transition/notification and immediate removal from active queries |
| 25 | Firebase Auth | Partial | Active traveler/admin role rules are supplied and emulator-tested; production rules were not inspected or deployed |
| 26 | Firestore storage | Complete | Report/photo, vote/photo and status/notification writes are atomic |
| 27 | Firebase Storage upload | Missing by design | Evidence is stored as a compressed Firestore blob; legacy URL evidence still renders |
| 28 | Location permission handling | Partial | Denied/forever/service-off/timeout/accuracy states are handled; device permission dialogs need physical testing |
| 29 | Distance calculation | Complete | Finite coordinates, fresh accurate position, Geolocator distance and inclusive 100/300/500 m boundaries |
| 30 | OpenStreetMap | Complete | `flutter_map` tiles, markers, circles, attribution, retry and map expansion |
| 31 | Notification handling | Partial | Foreground local alerts and status tap routes; no remote push/background delivery |
| 32 | Cooldown | Complete in foreground | 30-minute per-hazard cooldown, score escalation and stationary GPS refresh; memory resets after process restart |
| 33 | Duplicate vote prevention | Complete | UID document, immutable rule and transaction/concurrency protection |
| 34 | Duplicate image detection | Partial | Exact SHA-256 and 64-bit average-hash check against the user's report/vote history; not a global or tamper-proof check |
| 35 | Evidence quality | Complete as a heuristic | Low quality is retained without a confidence bonus; invalid content is rejected |
| 36 | Confidence calculation | Complete as advisory logic | Minimum recent sample and explainable weighted support; never auto-resolves a report |
| 37 | Tourist mobile UI | Complete in local layout tests | Commercial hierarchy, friendly states and 320/390 px plus 200% text-scale coverage |
| 38 | Admin web UI | Complete in local layout tests | Responsive 390/1200 px review layout and concise, non-misleading analytics |

## B. Bugs found and fixes

| Severity | Bug / root cause | File(s) | Fix implemented |
|---|---|---|---|
| High | Missing Firestore documents were treated as “still loading” because `hasData` is false for a valid null event | hazard_detail_page.dart; safety_alert_page.dart; admin_hazard_management_page.dart | Separate waiting, missing, error and data states; keep the AppBar/back path outside async content |
| High | A stale or inaccurate GPS fix could authorize a confirmation | location_service.dart; safety_alert_page.dart | Require valid finite coordinates, ≤100 m accuracy and ≤2-minute age; fetch again immediately before the vote transaction |
| High | The nearest hazard was selected before priority/cooldown, allowing it to mask a more urgent or eligible hazard | safety_alert_priority_service.dart; hazard_proximity_monitor.dart | Score every active in-radius candidate, apply cooldown/escalation per hazard, then sort by priority and distance |
| High | Old, future-dated and invalid-distance votes could inflate “current” resolution confidence | confidence_analysis_service.dart | Exact 15-minute recent sample, one-hour weighted window, zero future/old weight and rejection of invalid/outside GPS evidence |
| High | Status decisions could be submitted from a stale administrator screen | hazard_report_service.dart | Transaction re-reads the report and verifies the expected current state and allowed transition |
| High | Evidence/photo writes were not fully bound by rule schema, timestamps and parent identity | safety_module.firestore.rules | Whitelist fields, bind owner/hazard/hash/source metadata, require atomic photo existence and enforce server timestamps |
| High | Nullable scene-match score was passed through a non-null-only copy API, causing a compile error | evidence_validation_result.dart | Add a nullable-safe `withSceneMatchScore` copy path |
| Medium | Duplicate checking loaded only the user's reports and missed their prior vote photos | hazard_report_service.dart; hazard_vote_service.dart | Include the signed-in user's `votes` collection-group fingerprints |
| Medium | Negative, non-finite or >500 m confirmations could reach service logic | safety_config.dart; hazard_vote_service.dart; rules | Centralize inclusive proximity bands and reject `OUTSIDE` locally and in Firestore rules |
| Medium | Alert/report/vote/location listener errors and notification initialization could interrupt the Safety shell | hazard_proximity_monitor.dart; mobile_notification_service.dart | Isolate listener errors, keep UI alerts working if local notifications fail, and dispose/pause subscriptions correctly |
| Medium | Notification taps did not route to hazard details/review | mobile_notification_service.dart; hazard_proximity_monitor.dart | Add validated `hazard:` and `review:` payload routing, including launch-time pending payloads |
| Medium | Vote-stream errors on the Verified list silently appeared as zero community evidence | admin_verified_reports_tab.dart | Cache per-hazard streams and show a retryable error card |
| Medium | Admin UI exposed reporter UID fallback and described deterministic hashing as AI/similarity certainty | admin_hazard_management_page.dart; admin_hazard_shared_widgets.dart | Remove UID fallback and use explicit “visual-pattern comparison” categories and limitations |
| Medium | Malformed hazard/itinerary coordinates could throw or create markers at `(0,0)` | hazard_report.dart; hazard_map_service.dart; itinerary_safety_service.dart | Preserve missing values as invalid, validate bounds and filter before map/distance use |
| Low | Camera-only evidence flow ignored the existing gallery callback | evidence_picker_card.dart; create_hazard_page.dart; safety_alert_page.dart | Implement camera and gallery actions with busy guards and source metadata |
| Low | High severity was wider than Medium and Low due to per-option padding/content sizing | create_hazard_page.dart | Use three equal `Expanded` children, identical padding/border/height behavior and accessible semantics |
| Low | Dropdown, list rows, status/date rows and admin actions overflowed at narrow widths or large text | traveler/safety pages; admin/hazards pages | Use expanded/ellipsized dropdown content, Wrap/Flex breakpoints, scroll-safe states and constrained sticky actions |
| Low | Map lacked retry, recenter and clear attribution states | danger_zone_map_page.dart | Add location/tile retry, recenter control and OpenStreetMap attribution |

No unresolved Critical bug was found in the locally exercised Safety-module code. Security limitations that cannot be solved by client rules alone are in section I.

## C. Functional improvements

- Centralized coordinate, distance-band, alert-radius, cooldown, recency and evidence thresholds in `SafetyConfig`.
- Made only the exact `Verified` status active and deduplicated map input by report ID.
- Added fresh-position validation and periodic refresh for stationary travelers whose movement stream does not emit.
- Reworked automatic alerts around a tested candidate selector with escalation and per-hazard cooldown.
- Added lifecycle-safe subscription cleanup, pause/resume behavior and live closure of an alert when its report is no longer active.
- Revalidated the report state and GPS immediately before community confirmation.
- Kept official resolution administrator-only; community confidence is advisory and requires a meaningful recent sample.
- Made photo evidence validation explainable: decoded format, source size, dimensions, sharpness, exposure, SHA-256 and coarse perceptual hash.
- Included both reports and prior confirmations in the user's duplicate-evidence history.
- Preserved report/photo, vote/photo and status/notification atomicity.
- Added transactional stale-state and duplicate/concurrent-vote protection.
- Filtered malformed itinerary stops and inactive/invalid hazards before proximity warnings.
- Replaced raw Firebase/location errors with safe, actionable traveler/admin messages while logging technical details for developers.

## D. UI/UX problems found before redesign

- Oversized instructional content pushed the main Safety map and actions below the fold.
- High severity had a visibly larger control than Medium and Low.
- Photo capture was camera-only and used verbose validation/debug language.
- Technical enum names, raw errors, hashes and reporter identifiers appeared in user-facing areas.
- Every proximity alert used danger-red styling even when calculated priority was lower.
- Missing documents could display a spinner forever with no usable back path.
- Descriptions and horizontal metadata rows dominated small screens and could overflow.
- Admin analytics duplicated information, called deterministic calculations “AI”, and showed an unjustified similarity percentage.
- Administrator action rows and evidence cards did not adapt cleanly between phone-width and desktop-width layouts.
- Map failures lacked recenter/retry feedback and attribution was incomplete.

## E. UI/UX improvements by page

| Page | Before problem | Change and UX reason |
|---|---|---|
| Safety landing | Large intro, small map, prototype-like density | Compact introduction, prominent live map, full-map route, concise two-line reports and clear Report CTA |
| Create Hazard | Unequal severity sizes, camera only, stale location and raw failures | Equal selector cards, gallery choice, photo-first evidence, fresh submit GPS, inline validation and disabled busy controls |
| Danger Zone Map | No recenter/retry/attribution and inconsistent filtering | Active-report filtering, recenter, tile/location recovery, empty state, legend and attribution |
| Hazard Details | Infinite spinner on missing report; crowded status/date | Stable AppBar, explicit missing/error/retry states and responsive metadata Wrap |
| My Reports | Nullable-auth crash risk and crowded rows | Safe signed-out handling, stacked mobile content and clearer status hierarchy |
| Priority alert sheet | Could remain actionable after resolution | Live status watch and unavailable/closed presentation when the report changes |
| Review Safety Alert | Always-red tone, stale GPS, enum-like distance data | Priority-aware banner, refreshable plain-language location state, latest-report check and guarded confirmation |
| Pending admin list | Desktop row assumptions | Responsive vertical/horizontal layout and quieter visual hierarchy |
| Verified admin list | Vote error looked like zero evidence | Cached streams, explicit retry and reliable evidence summary |
| Admin management | Redundant analytics, raw identity/technical details, fragile action bar | Responsive evidence/reporter panels, concise resolution analysis, expandable technical explanation and guarded sticky actions |
| Daily Planner integration | Malformed stop/hazard coordinates could break warning computation | Keep the existing compact warning only when valid warnings exist; no broader planner redesign |

## F. Files

Created for the Safety module/audit:

- `docs/safety-module-audit.md`
- `firebase_rules/emulator.json`
- `firebase_rules/tests/.gitignore`
- `firebase_rules/tests/analysis_options.yaml`
- `firebase_rules/tests/package.json`, `package-lock.json`, `safety-rules.test.mjs`
- `lib/core/safety_error_message.dart`
- `lib/models/evidence_validation_result.dart`
- `lib/services/evidence_image_validation_service.dart`
- `lib/traveler/safety/safety_priority_sheet.dart`
- `lib/widgets/evidence_picker_card.dart`, `safety_loading_state.dart`
- `test/evidence_image_validation_service_test.dart`
- `test/itinerary_safety_service_test.dart`
- `test/safety_pages_test.dart`
- `test/safety_widgets_test.dart`

Modified in Safety scope:

- `firebase_rules/README.md`, `safety_module.firestore.rules`, `safety_module.indexes.json`
- `lib/core/safety_config.dart`
- `lib/models/hazard_report.dart`, `hazard_vote.dart`
- `lib/services/confidence_analysis_service.dart`, `hazard_map_service.dart`, `hazard_report_service.dart`, `hazard_vote_service.dart`, `itinerary_safety_service.dart`, `location_service.dart`, `mobile_notification_service.dart`, `safety_alert_priority_service.dart`
- `lib/traveler/safety/create_hazard_page.dart`, `danger_zone_map_page.dart`, `hazard_detail_page.dart`, `hazard_proximity_monitor.dart`, `my_hazard_reports_page.dart`, `safety_alert_page.dart`, `safety_page.dart`
- `lib/admin/admin_pages.dart`
- `lib/admin/hazards/admin_hazard_management_page.dart`, `admin_hazard_shared_widgets.dart`, `admin_hazards_page.dart`, `admin_pending_reports_tab.dart`, `admin_verified_reports_tab.dart`
- `test/confidence_analysis_service_test.dart`, `safety_alert_priority_service_test.dart`, `safety_zone_config_test.dart`

Files removed: none. Existing unrelated dirty-worktree changes were preserved and were not cleaned up or claimed as part of this audit.

## G. Firebase

Collections and relevant data:

- `hazard_reports/{hazardId}`: owner, category, severity, description, coordinates, exact lifecycle status, timestamps/history, review metadata and evidence summary/fingerprints.
- `hazard_reports/{hazardId}/evidence/photo`: compressed JPEG blob (maximum 400 KiB), content type/length, owner/hazard identity, source, hashes, validation level and server timestamp.
- `hazard_reports/{hazardId}/votes/{uid}`: immutable vote type, declared distance/band, GPS flag, timestamp and optional evidence/scene-pattern metadata.
- `hazard_reports/{hazardId}/votes/{uid}/evidence/photo`: optional vote-photo blob with metadata bound to its parent vote.
- `notifications/{notificationId}`: recipient, message/type/status, hazard reference, read flags and server timestamp.
- Existing `travelers/{uid}` and `admins/{uid}` documents supply `active` and `role` authorization.

Index: merge the `votes.userId` ascending `COLLECTION_GROUP` field override in `firebase_rules/safety_module.indexes.json` into the project's deployed index configuration. Normal collection-level status/user filters use single-field indexes.

Storage: no new Firebase Storage path is used. Photos are compressed and stored in Firestore evidence subdocuments. Legacy `imageUrl` content remains readable.

Security rules: the supplied rules enforce active traveler/admin roles, ownership/privacy, strict field sets, literal statuses, allowed lifecycle transitions, server timestamps, coordinate/distance boundaries, parent-child evidence identity, required atomic report photos, optional atomic vote photos, immutable UID votes and private notifications.

Manual Firebase steps:

1. Merge the helper functions and `match` blocks from `safety_module.firestore.rules` into the project's complete production rules. Do not deploy this fragment as the whole ruleset because unrelated paths would be denied.
2. Merge the collection-group index override, preserving all existing indexes, then deploy rules/indexes through the project's normal release process.
3. Run the same emulator tests against the complete merged ruleset; broader existing `allow` statements can otherwise weaken scoped restrictions.
4. Review/migrate legacy status spellings before release. Only exact `Verified` records are active.
5. Confirm Android/iOS location, camera, gallery and notification permission descriptions/configuration, then complete the device matrix in section H.

No Firebase rules, indexes or data were deployed by this task.

## H. Testing results

| Test | Result | Detail |
|---|---|---|
| Flutter dependency resolution | PASS | `flutter pub get` completed |
| Safety-scoped Dart analysis | PASS | Zero issues across changed Safety source and tests |
| Whole-project `flutter analyze --no-pub` | PARTIAL | Command completed; 69 existing issues remain in unrelated auth/cultural/planner/profile/rewards/vendor code. No Safety-scope issue was reported |
| Full Flutter test suite | PASS | 59/59 tests passed |
| Evidence validation | PASS | Decode/type/size/resolution/exposure/sharpness, exact duplicate, re-encode fixture, hash thresholds and malformed hashes |
| Confidence/priority/distance logic | PASS | Old/future/invalid evidence, recent sample, boundaries, candidate ordering, cooldown and escalation |
| GPS validation | PASS | Valid/invalid coordinates, 100/101 m accuracy and two-minute/future freshness boundaries |
| Responsive widget/page tests | PASS | Evidence picker and Create/Admin screens at 320, 390, 1024/1200 widths and up to 200% text scaling; equal severity dimensions asserted |
| Missing/error states | PASS | Details, alert and admin pages terminate loading and retain navigation/retry paths |
| Firestore emulator rules | PASS | 14/14 tests: lifecycle, privacy/roles, atomic photos, schema, GPS bands, concurrency, immutability, inactive reports and owner notifications |
| Flutter web build | PASS | `flutter build web --no-pub` completed successfully, including Wasm dry run |
| Rendered UI inspection | PASS | Mobile Create and mobile/desktop Admin captures inspected; controls, icons, wrapping and sticky actions render consistently |
| Live Firebase project | PARTIAL | Not connected/deployed/tested to avoid altering production state |
| Android/iOS camera, GPS and notification matrix | PARTIAL | Requires physical devices and OS permission flows |
| Background/terminated-app hazard alerts | PARTIAL | Not implemented; current proximity monitoring is foreground-only |

Useful local commands:

```powershell
flutter test --no-pub
dart analyze lib/core/safety_config.dart lib/core/safety_error_message.dart lib/models/hazard_report.dart lib/models/hazard_vote.dart lib/models/evidence_validation_result.dart lib/services/confidence_analysis_service.dart lib/services/evidence_image_validation_service.dart lib/services/hazard_map_service.dart lib/services/hazard_report_service.dart lib/services/hazard_vote_service.dart lib/services/itinerary_safety_service.dart lib/services/location_service.dart lib/services/mobile_notification_service.dart lib/services/safety_alert_priority_service.dart lib/traveler/safety lib/admin/hazards lib/widgets/evidence_picker_card.dart lib/widgets/safety_loading_state.dart test
cd firebase_rules/tests
npm ci
npm test
```

## I. Remaining issues and honest limitations

- “Photo evidence matching” is a coarse 64-bit average-hash visual-pattern comparison. It can catch exact reuse and some simple re-encoding, but changes in angle, crop, lighting or a visually similar unrelated scene can cause false negatives/positives. It is not semantic AI recognition and cannot prove the hazard is present.
- Evidence quality, GPS distance and hashes are computed/declared by the client. Firestore rules can validate shape, consistency and bounds, but cannot inspect decoded pixels or independently establish a device's real-world position. Trusted server-side attestation/validation is required for adversarial fraud resistance.
- Automatic proximity checks and local notifications work while the traveler shell is running in the foreground. Reliable background or terminated-app alerts need a separately authorized push/geofencing backend and platform background configuration.
- Cooldown is in process memory and resets when the app process restarts. Persist it locally or server-side if cross-restart suppression is required.
- Report submission uses an atomic Firestore batch, but an offline queued write can remain pending; there is no durable client outbox/idempotency key or visible sync queue yet.
- Photos use Firestore blobs rather than Firebase Storage and are capped at 400 KiB. This is simple and atomic but should be cost/load-tested at production scale.
- OpenStreetMap tiles require network access and must comply with the selected tile provider's production usage policy.
- Exact `Verified` matching intentionally excludes inconsistent legacy status spellings until a deliberate migration is run.
- The confidence score is a transparent decision-support heuristic, not an automatic resolution engine. Administrators remain responsible for the official status.
- Physical-device camera/gallery, GPS accuracy, permission-denied/forever flows and local notification taps still require Android/iOS acceptance testing. The production merged ruleset also needs staging verification before release.
