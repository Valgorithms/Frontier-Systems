# Desktop controls help and panel navigation

The existing six tabs retain their indices: Workstation 0, Inventory 1, Settings 2,
Construction 3, Terrain 4, Guide 5. A compact selector above the native viewport
offers keyboard access to every tab. Controls help expands in a bounded vertical
scroll area and displays the current InputMap labels, including remapped bindings.
Opening help releases capture; closing it restores focus to its toggle. UI cancel
closes help only when focus is inside this helper and rebinding is inactive.

This presentation helper owns no observed world status, history, persistence,
simulation cadence or commands. Existing disconnect clearing remains unchanged.
Guide and Construction descriptions explain existing behavior rather than adding
actions. Native SubViewport picking and movement bindings are unchanged. Settings
binding buttons clip long labels with complete tooltips and its scroll follows focus.

## Acceptance and verification

Port-free tests cover keyboard opening/closing, forward/backward focus traversal,
all six selector destinations, compact sizing, live labels after an in-memory
remap, native unrelated input remaining unhandled, and rebinding isolation.
Use the existing bounded Godot runner; logs stay ignored in var/ci.
Local and exact-head CI results will be recorded before handoff.
No graphical, human, controller or VR acceptance is claimed without captured evidence.
No media upload, release, deployment, merge or integration-branch push is in scope.
