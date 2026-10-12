# Machinery contextual captions

Scope: machinery preview and a bounded presentation card only. Replace persistent overlapping machine/canister captions with hover or existing placement selection details. Preserve exact picking, canonical state, commands, activity freshness and unconfirmed batch outcomes.

Acceptance: paid no-port runtime and real-shell tests cover context changes, reset/disconnect, narrow viewport and activity uncertainty. Windows/Linux exact-head CI required. Native stills only if visual uncertainty remains. No new artwork or external references; first-party code under the repository MIT license.

Status: implementation and verification pending.

Implementation: one passive screen card uses native StaticBody3D hover and the existing placement-feedback selection. Persistent machine/socket Label3D captions are hidden. Stable identity, last observed buffer/state, recipe/progress and freshness-qualified activity appear contextually; the original full observation text remains available in the machinery panel. GUI focus suppresses hover, teardown/reset/disconnect clear context, off-screen/behind-camera targets hide the card, and geometry rebuilds require fresh hover. No collider dimensions, picking callbacks, simulation commands, schemas, paid host behavior, rotor gates or shared input/camera/bootstrap files changed.

Verification in progress: Windows Godot 4.7.2 paid real-shell test plus machinery preview, activity, placement-feedback and operation-feedback regressions. Tests exercise real finite paid extraction, exact center-ray collider identity, observed progress, stale timeout, host disable, actual snapshot restore pause, cancellation outcome uncertainty, focus, narrow shell and actual client disconnect. Native still review and exact-head CI pending.

Provenance: ordinary Godot controls and drawn line/circle geometry, independently authored first-party MIT code. No artwork, copied upstream code, new assets, AI imagery, video, upload, release or deployment.
