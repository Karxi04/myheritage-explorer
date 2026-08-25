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
