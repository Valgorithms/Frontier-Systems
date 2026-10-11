# Observed owned-container controls milestone

## Dependency gate

Planning base: origin/dev-master `f9f7085`. Dependency: PR #77, read-only contract reviewed at `b2ff932cc5baaa00eecc9a3ae69ca1671c9092e0`. Implementation waits for Coordinator confirmation that #77 is merged, then updates this isolated branch from current origin/dev-master. This document is a plan, not evidence of implemented behavior or acceptance.

## Scope and interfaces

Extend the existing PlayerInventoryPanel and its presentation helper with an explicit stable owned-container selection, observed closure status, and separate Open container / Close container actions. Browsing owned knowledge remains distinct from physical opening. Preserve the selected ID when observations reorder; retain an unavailable selected ID without choosing another target when it disappears.

Consume existing detailed own-inventory container records and inventory revision. Only an explicit boolean `is_open` establishes observed open/closed state; absent, malformed, stale or disconnected fields mean unavailable. Legacy knowledge remains visible but cannot establish closure prerequisites. Full owned descendant knowledge and aggregate mass do not imply physical access, a lock, another body's access, or world-container control.

Submit the merged authenticated `open_container` / `close_container` operations with exactly `{container_id, expected_revision}` through the existing remote inventory intent route. The host owns closure, ancestry, hands, revision, work cancellation and receipts. Pin operation, selected ID, revision and returned request ID while pending; correlate only the exact receipt. Do not optimistically alter observations, retry, retarget, or infer closure from receipt arrival alone. Preserve uncertainty across disconnect and reconcile only actual observations and exact retained receipts.

No changes to schemas, inventory owner, commands, bootstrap, movement, first_playable_acceptance, shared authority, services or assets. Presentation may explain observed closed source/destination ancestors but never replaces host validation.

## Verification plan

After the dependency gate, add a focused real-domain panel regression using the merged inventory queue and disposable isolated fixture state. Verify open/closed nested ancestor transfer refusal and later acceptance, interrupted/ongoing work refusal and conservation using actual runtime commands and the existing closed-container runtime regression. Exercise stale revision rejection, exact request/receipt correlation, a mismatched receipt, disconnect uncertainty, missing closure fields, unavailable targets, reorder refresh and preserved selection.

Verify keyboard selection and activation, focus reachability/reveal, wrapped status and full pending IDs at desktop/narrow panel sizes. Reuse existing inventory handoff, feedback, usability, transfer-preview and integrated panel regressions where applicable. Use the repository pinned Godot runner and existing Windows/Ubuntu CI matrix; report exact pushed head and CI evidence. Capture only if these checks leave material visual uncertainty. No live service, human, physical controller/VR, Linux graphical or network acceptance is implied by automated checks.

## Workflow

Isolated managed worktree; descriptive branch `observed-container-controls`; attached draft PR to dev-master while work continues. Scope includes this own milestone document and relevant inventory presentation architecture documentation. Coordinator receives dependency wait and final evidence; genuine human acceptance routes through Coordinator. No merge, release or deployment is authorized for this task.
