# Paid panel scene contact design checkpoint

Status: proposed boundary expansion, awaiting Coordinator acceptance before
implementation. Base: PR139 merge `3d4afd589882f9af60799d169e2dd865a20dbdfe`.

## Observed runtime path

`FirstPlayableBootstrap._start_client()` creates `RemoteWorldRuntime` and a
separate `SubViewport` containing `ProceduralHabitatPreview` and the local
`LocalHabitatCharacter`. The remote runtime deliberately owns no canonical
simulation systems. `FirstPlayableHost` owns `WorldRuntime` and authenticated
peer state; its `_publish()` currently sends an own-builder panel projection.
It has no character physics scene. `HorizontalPanelPreview` creates picking
Areas, not physical floors. Promoting this projection would omit other builders.

The PR139 synchronous server-only descriptor API can describe complete geometry
but is not available in the real client. Therefore playable client contact
requires an explicitly accepted observation extension. A server-internal test
scene alone could establish contact but would not integrate the playable client.

## Proposed bounded implementation

Production remains the canonical owner. On each authenticated publish, derive
complete descriptors from the current owner using PR139, with the current
Production revision. A read-only, versioned collision observation carries only
world/region, restore fence, revision/ticks and bounded solid geometry. No
principal, material, invite key, session identifier or command permission is
included. Geometry never becomes an authoritative movement grant.

The current peer registry supplies live authentication. Disconnect/reconnect
invalidates the client's local collision binding. A volatile restore fence
distinguishes same-revision restores. Every publish rederives current geometry;
revision equality never permits reuse of an old descriptor as authority.

Validate the complete incoming observation before creating any bodies. Reject
invalid bounds, unsupported schema, foreign scope, stale lifecycle and malformed
geometry without retaining partial solids. Clear solids on failed/expired input,
disconnect, reconnect, scope change and teardown. Restore transitions dispose
the old solids before rebuilding, including when revision and stable IDs repeat.
Only unchanged complete geometry in the same live lifecycle may retain bodies.

Use environment layer 1 and the existing character mask. Validate the consumer's
global transform as identity; station-to-display mapping is identity axes plus
division by 1000 and `DISPLAY_ORIGIN = (-6, 0, 2)` metres. Floor top remains 0 mm,
center -6 mm; ceiling underside 2000 mm, center 2006 mm; thickness 12 mm. Align
the own-only visual preview with those centers explicitly. Picking remains
separate from physical contact.

## Acceptance and limits

Focused regressions must exercise real Production/Inventory owners, two builders,
own-only observation versus complete collision geometry, current authentication,
invalid/stale/scope inputs, removal, equal-revision changed-geometry restore,
disconnect/reconnect and teardown. A real PhysicsServer3D/CharacterBody3D probe
must establish floor and ceiling contact and removal without fixture floors
masking the result. Keep strict schema coverage and Windows/Linux CI in existing
workflows; report the actual tested revision and export evidence.

No Godot execution until the Coordinator grants an exclusive no-port lease after
a fresh process check. No ports, capture, Gaia1714 interaction, pressure, doors,
assets, movement redesign, publication or deployment. Coordinator owns acceptance
of the observation expansion and all merges. No successor work is authorized.
