# Dense world inventory tray milestone

Successor to PR111, based on d72476951e5bbec66e736269dbd0c2b7541434e8.

Scope: observation-only ProceduralWorldInventoryPreview tray anchors and regression tests. Separate eight visible item slots so crowbar, extractor and canister silhouettes and pick envelopes do not overlap. Preserve stable selection identities, observed distance, item cap, snapshot/provenance, cached rebuilds and highlight/cleanup behavior. Simulation owners, camera, avatar, bootstrap, panels and schemas remain outside this change.

Acceptance: finite paid no-port construction fixture, dense eight-item tray, complete canonical invariance, physics picking every exposed item without collecting neighbors, removal/highlight/cache regressions, and Windows/Linux CI for the final head. Original MIT procedural geometry only. No videos, deployment or public media. Verification pending.
