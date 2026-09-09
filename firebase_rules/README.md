# Safety module Firebase rules

This project did not contain checked-in Firestore rules when the safety module
was implemented. `safety_module.firestore.rules` contains scoped, copy-ready
rules for the new module only.

Merge its `match` blocks and helper functions into the rules currently used by
the connected Firebase project. Do not deploy it as the complete project
ruleset: Firestore denies paths that have no matching `allow`, so doing so would
intentionally block unrelated existing modules.

The rules authorize administrators through active `admins/{uid}` documents
whose `role` is `admin`, matching the application's existing role architecture.

Hazard and community-vote photo evidence is compressed to a maximum of 400 KiB
and stored under the relevant Firestore `evidence/photo` subdocument. The safety
module no longer requires Cloud Storage for Firebase or the Blaze billing plan.
Legacy evidence with an `imageUrl` continues to render in the application.

The enhanced evidence flow also stores SHA-256 and perceptual fingerprints,
capture source, and an explainable validation result on the report or vote.
Invalid and known-duplicate images are rejected by the client and the scoped
rules require persisted evidence to be valid and non-duplicate. Community votes
without a photo remain valid when their GPS distance and other vote fields pass
the rules.

The duplicate check reads the signed-in traveler's own hazard reports and own
`votes` collection-group documents. The included vote read rule therefore
allows a traveler to query their own vote documents while preserving access to
verified hazard votes and administrator access.

No composite Firestore index is required by the safety queries in this module.
Collection-scoped `status` and `userId` filters use normal single-field indexes.
The own-vote history query needs the explicit `votes.userId` collection-group
ascending index in `safety_module.indexes.json`. Merge that field override into
your existing index configuration, preserving unrelated indexes.

## Local rule verification

From `firebase_rules/tests`, run `npm ci` followed by `npm test` (Node 22+
and Java 21+ recommended). This uses the isolated demo project and localhost
Firestore emulator; it does not deploy rules or touch production data.

The tests cover role/privacy enforcement, required atomic photos, lifecycle
transitions, GPS-band boundaries, duplicate/concurrent votes and rejected writes.
Rules check declared metadata, not real-world position, decoded image content,
or semantic scene identity. A tamper-resistant system needs trusted server-side
validation. Never describe these client heuristics as AI scene verification.

## Server vote and confidence validation

The `functions-safety` codebase validates each newly created community vote
before any Gemini request. It writes the Admin-SDK-owned
`serverValidationStatus`, `serverValidatedAt`, and `serverValidationReasons`
fields. Clearly invalid votes are retained for auditability, excluded from the
official confidence calculation, and do not incur AI analysis. A lightweight
vote-write trigger recalculates `hazard_reports/{hazardId}.serverConfidence`
from the current vote documents after creation, validation, or AI completion.
The formula is versioned as `safety-confidence-v1` and has shared TypeScript and
Dart golden fixtures under `test/fixtures`.

`VALID` means structurally valid and consistent with the current Safety rules.
It does **not** prove the Tourist's physical location: the backend receives the
client-derived distance, proximity band, and GPS-validation flag without an
independent trusted device-location signal. Step 8 intentionally adds no device
attestation. Likewise, the existing photo checks and AI comparison provide
decision support rather than proof of real-world scene identity.

Both Tourist and Administrator client writes to the validation fields and
`serverConfidence` are denied. The Administrator UI reads a structurally valid,
fresh server summary when available and otherwise falls back to the existing
client calculation, so legacy hazard documents require no migration. These
functions and the scoped rules must still be deployed or merged manually; local
tests do not change the live Firebase project.

Existing legacy records can still display, but new writes must satisfy the stricter
schema. Only the exact `Verified` status is active; review/migrate inconsistent
legacy statuses deliberately before deploying merged rules. Existing broader
allow rules can override these restrictions, so test the merged production
ruleset separately before deployment.
