# Paid manual-door seal lifecycle: design checkpoint

Base: merged PR142, `3d7c02005b23449d13e2d6bebfe833f4671a3fd5`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns design approval,
merge, ledger and ignored active state. This worker owns the isolated
`paid-manual-door-seal-lifecycle` branch. No local runtime lease is held.

## Observable outcome and bounded scope

A player can install and remove a finite paid prototype metal seal on their
closed paid manual door through the existing production controls, command queue
and authenticated session. Repeated requests cannot duplicate material. Saves
retain its identity and bill. This is preparation for later pressure boundaries;
it creates no pressure connection, volume, port, flow area or airtight-room claim.
PR142 opening topology remains `enclosure_with_unsealed_openings` regardless of
seal installation, condition or leaf position.

## Materials, tools and ownership

Proposed first-party MIT blueprint `door.manual.seal.prototype` revision1 consumes
200,000 mg processed `plate`. This explicitly modeled prototype metal gasket
bill is neither a density calculation nor an elastomer or pressure rating. Plate
comes from the existing finite iron refining/plate processing chain. Do not edit
the catalog, stock, recipes or fixture defaults. Default ore yields6kg iron;
the7.6kg enclosure plus2kg crowbar already exceeds it. Enclosure tests must keep
their bounded explicit seed distinct from the smaller default-resource lifecycle.

Production owns installed seal identity, blueprint/revision and retained exact
material bill on each door. The seal ID derives from authenticated principal and
install request, never from client data. Access alone owns `seal_condition`
(0..1), actuator integrity, latch and position. Inventory/Tools resolve the
current controlled body and real held usable `tool.crowbar` for both installation
and removal, reusing the existing manual fitting/prying tool. No free item,
controller, tool capability, spare or synthetic Inventory object is introduced.
There is no tick wear or new async callback; commands apply on the simulation tick.

Installed condition1 is freshly fitted; any value below1 is degraded and0 is
failed while retaining its paid mass. Opening leaves installation and condition
intact. Opening, degraded integrity, damaged latch or degraded seal never implies
an effective pressure boundary. Removing any condition refunds the exact retained
200,000mg plate once and sets Access condition0. Refitting explicitly reworks and
repairs this prototype metal gasket to condition1 using the real held crowbar;
the recovered plate can pay that bill, so repair has zero net material cost.
There is no persistent gasket damage after this deliberate tool operation and
no tick wear. It never heals actuator integrity, latch, mode or other hardware.
Migration and restore never heal gasket condition. Door disassembly requires seal
removal first, preventing implicit deletion/refund ambiguity. No new damage or
repair command is part of this slice.

## Transaction and restore contract

Add strict `door_seal_install` and `door_seal_remove` operations with the existing
exact revision/control_epoch/door_id intent shape. Require owner principal/body,
current authenticated session, permission, reach, usable held crowbar, closed leaf,
intact usable manual hardware, released latch and no foreign bypass/tamper/override
work. Reject duplicate installation, absent removal, insufficient unclaimed stock,
refund capacity exhaustion and malformed/extra payload fields before mutation.
Removal of degraded seal condition remains allowed on otherwise usable hardware.

Reuse `PaidDoorConstruction.plan`, detached Production candidate and single-device
`PreparedDoorChange` compare-and-swap. Validate support, finite claims, all seal
records, receipt/revision and capacity before Access commit; the immediate
Production assignment remains the only following step. Access failure, stale
prepared state, foreign state and replay failures leave both owners unchanged.

Production save v11 adds a required `seal` object to v11 door records: empty for
absent, otherwise exact seal_id, blueprint_id, blueprint_revision and materials.
Versions1..10 migrate each existing door to empty seal without manufacturing
material or healing condition. Reject fabricated positive condition on absent
seals, orphan/duplicate seal identities, altered bills/blueprints, booleans,
fractions, extra fields and conservation mismatch. Installed seals permit finite
Access-owned condition0..1; area and force stay0. Include retained seal mass in
whole-world conservation. Paired Production/Access restore guards compare the
normalized Production candidate and Access device links before any mutation;
independent mismatched restore rejects. Unknown versions fail closed.

Player paid-door observation v2 exposes own-only installation/condition and
existing pose/identity. Advance outer Production observation to v12 and retain
v11 decoding. Controls show absent/fitted/degraded state and explicit install/
remove actions/cost. Contact geometry/schema, Pressure save v1 and topology remain
unchanged. No settings, dependencies, assets or configuration examples are needed.

## Intended files and acceptance

Changes are bounded to paid-door construction/geometry, Production snapshot/mass/
observation handling, observation decoders/network operation allowlist, paid-door
controls, blueprint, versioned schemas, focused tests and architecture docs.
Existing Access transaction primitive and Pressure algorithms need no new owner.

Versioned focused runtime tests will cover real finite extraction/refining/plate
and crowbar fabrication, install/remove/reinstall, exact mass, replay, save/restore
and v10 migration; stale revision/epoch/session, foreign owner, reach, absent or
broken tool, open/jammed/damaged hardware, reservations/capacity, duplicate/missing
seal, failed prepare/CAS and malformed cross-owner restore must reject atomically.
Include degraded/failed Access condition retention, immutable bills, disassembly
guard, UI submission, old observation decode, unchanged Pressure snapshot and
unchanged PR142 topology for both leaf states. Schema tests exercise emitted v11
save/v12 observation and malformed variants.

Source checks precede runtime. Local Godot import/startup/tests require a fresh
exclusive no-port Coordinator lease after design review and draft PR/head report.
Use the existing bounded CI runner and required Windows/Linux CI. No listeners,
capture/export, Gaia1714, deployment, publication, outreach, PR85 edits, successors
or merge. Actual runtime/CI evidence and remaining limits will replace pending
acceptance claims; no screenshot gate is invented where meaningful tests suffice.
