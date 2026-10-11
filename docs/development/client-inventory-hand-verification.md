# Actual-client inventory and hand verification

## Scope and acceptance

This successor starts from integrated PR38/PR43 at `71c7052673b194c5dfaa5fc67517ef14f1428280`. It verifies presentation over existing inventory authority: owned tool equip, active-hand switching, storage transfer, matching rejected-command feedback, explicit retry and item/material conservation. No tutorial readiness, physical human input, world picking, controller or VR acceptance is implied.

The canonical owner remains `InventorySimulationSystem` and its shared coordinator at fixed ticks; UI nodes render detached observations and submit existing commands. Inventory v4, existing principal/body ownership, revision validation and bounded receipts remain unchanged. Failed requests must conserve state; successful operations relocate one item without duplication. Matching pending command IDs and revisions must control rejection/receipt reveal. External callbacks do not mutate canonical state.

## Ordered verification

1. Obtain an exclusive Coordinator lease for loopback 27850. A null reservation holder is not a grant. Re-probe before binding; never stop another chat's listener.
2. Reuse the unmodified PR38 `run-tutorial-readiness-checks.ps1 -ClientOnly -PortsReserved` on the integrated baseline to check PR43 focus/receipt interaction. Capture ignored native output and immutable source revision; preserve profile isolation and cleanup.
3. Extend a dedicated inventory/hand fixture using the real client shell and injected external-effect adapter. Exercise GUI event activation, owned-tool equip, hand changes and transfer; separately identify fixture-selected controls and injected observations. Verify matching rejection/retry feedback and exact before/after canonical item/material conservation.
4. Run only affected versioned checks. Inspect native captures internally. Commit/push the final feature head and report exact CI and graphical evidence; no gallery, upload, deployment or merge.

## Current status

Managed worktree: `C:/Users/valza/.codex/worktrees/client-inventory-hand-verification/Frontier Systems`.
Branch: `client-inventory-hand-verification`, targets `dev-master`.

**Coordinator lease request:** exclusive 27850 for the initial integrated ClientOnly rerun, followed by dedicated inventory/hand verification if needed. No listener has been started by this milestone. The initial native rerun and dedicated fixture remain pending the grant. Existing PR38 evidence is historical and is not represented as a new integrated pass.

Cross-chat send is unavailable without direct human messaging authorization: the messaging tool explicitly says an orchestrator's received request does not itself authorize replying. This request is exposed through chat status for Coordinator polling; no owner approval is requested here. This is an authorization prerequisite, not a demonstrated client failure.

No runtime, schema, authority, shared runner or creative asset changes have been made. New captures will stay ignored/internal; configuration examples are unchanged.
