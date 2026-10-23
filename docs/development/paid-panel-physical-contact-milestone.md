# Paid panel scene contact design checkpoint

Status: Coordinator accepted the bounded read-only observation extension and
volatile Production restore fence on 2026-10-23. Implementation under focused
verification. Base: PR139 merge `3d4afd589882f9af60799d169e2dd865a20dbdfe`.

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

## Accepted bounded implementation

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

Godot execution requires the Coordinator's exclusive no-port lease after
a fresh process check. No ports, capture, Gaia1714 interaction, pressure, doors,
assets, movement redesign, publication or deployment. Coordinator owns acceptance
of the observation expansion and all merges. No successor work is authorized.

## Lifecycle details

The host binds actual WorldRuntime, Inventory and Production instances and scope
on first publication. Replacement closes the authenticated peer rather than
rebinding an old connection. Each peer owns a nonwrapping publication sequence.
Inventory's existing volatile restore counter and Production's new volatile
counter advance only after a validated successful restore. Production validates
counter exhaustion in the whole-world prevalidation phase as well as direct
restore, so failure cannot partially mutate state or advance a fence. No save
schema changes. Counters are bounded to the shared exact JSON integer range.

The envelope `paid-panel-contact-observation-v1` wraps the descriptor value with
both owner fences and the publication sequence. Decoder validation reconstructs
temporary synthetic paid records solely to reuse the existing grid, bounds,
overlap and capacity validator; this proves shape consistency, never payment or
authentication. Payment provenance comes only from the live canonical host API.
The same complete content retains bodies only within a current lifecycle;
changed fences retire every old RID before rebuilding. The client resets its
production projection on an accepted restore transition so a legitimate lower
revision or tick does not masquerade as a stale publication.

RemoteWorldRuntime pins world/region at authentication, allocates its own local
connection generation and creates a new WebSocketPeer queue for reconnect.
Transport callbacks carry that local generation outside the payload. Old queues
cannot revive a newer connection. Invalid input retires contact and invalidates
authentication; a snapshot alone cannot authenticate. A missing fresh publish
for 0.5 seconds removes scene solids. This timeout and the 0.1-second host
publication cadence affect presentation contact assistance, not server movement
acceptance. Owner replacement is observed at publication, disconnect on transport
poll, and changes/removals on the next accepted complete snapshot.

SimulationRunner permits atomic world restore only on a fresh, never-started
runtime. The regression follows that policy: restore into a fresh runtime,
reject the old binding, disconnect, then authenticate a fresh connection.
Independent Production restore is separately exercised on the bound runtime.
No hot world restore capability is introduced.

## Verification record

Focused Windows Godot 4.7.2 import, startup and contact regression passed (3/3)
in `var/ci/contact-retry2`; emitted envelope schema checks, Windows runtime policy
and 24 CI-policy contract cases passed. Initial duplicate-teardown parse error
and the first regression's fixture tick mismatch remain recorded in
`var/ci/contact-initial` and `var/ci/contact-retry1`. Final affected regression
suite and exact-head Windows/Linux CI/export evidence are recorded in the PR.
The fixture injects transport output and exercises real authentication,
publication, JSON decoding, canonical paid owners and physics bodies; no ports
are opened. Character contact uses a separate empty scene to avoid habitat
fixture floors masking paid-floor removal. A further check verifies the actual
playable bootstrap binds the same remote observation into its viewport.
Graphical/controller/VR usability and deployed behavior are not established.
