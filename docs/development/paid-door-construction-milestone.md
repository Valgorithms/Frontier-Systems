# Paid manual door construction checkpoint

Status: implementation in draft PR #141; focused lifecycle and CI acceptance pending.

The initial checkpoint is superseded where necessary by the concrete transaction and geometry details below. The Coordinator accepted the bounded owner, transaction, geometry and restore mechanisms before implementation.

## Bounded outcome

Construct, operate and disassemble one paid floor-mounted manual door in an empty wall gap. The assembly uses a fixed 1000 x 2000 x 100 mm installation envelope on the existing 50 mm wall grid. It does not cut a wall, create an airlock, connect gas volumes or establish pressure sealing. Existing first-party code and data are MIT; no external art or source is imported.

## Ownership and transaction

- Production owns installation identity, floor anchor, orientation, constructing principal and the conserved trusted bill: 2,000,000 mg processed plate for frame and leaf. IDs derive from principal and request identity. Player payloads cannot supply bills, actuator capabilities or owner IDs.
- AccessControlSystem owns the installed manual ActuatorState. Construction commissions one released-latch actuator without a controller, circuit, spare modules, bypass grants or prototype airlock contents. Existing manual actuation validation remains authoritative.
- Inventory owns the actor body and actual held crowbar; Tools owns its usable capability. Reach, permission, revision and actual tool checks precede manual operation. Fixed-tick commands and retained exact-intent receipts prevent duplicate debit/refund.
- Prepare the entire Production and Access candidate before commit. Recheck finite stock, active reservations, output capacity and geometry. Commit synchronously without external effects; reject failures without changing either owner.
- Disassembly requires a closed door and no active bypass work or installed foreign hardware. Refund only the retained trusted bill, never fixture contents, and remove only the commissioned device.

## Geometry and persistence

Reserve the complete installation envelope against existing walls, machines, fixtures and other doors even when open. Closed leaves block canonical movement and produce derived collision; open leaves permit passage. Reject closure onto a body. This floor-mounted prototype occupies an empty wall gap; arbitrary wall openings, surface/ship attachment and swept hinge simulation remain outside scope.

Production save v10 adds a bounded door registry; saves v1-v9 migrate to an empty registry. Validate exact commissioned device/actuator links and supported hardware before any world restore mutates state. Access remains the canonical owner of position and condition. Door geometry never enters the existing geometric closed-room query as a solid wall.

## Concrete cross-owner mechanism

No existing Access construction transaction interface exists. Add a narrow server-only prepared door change type with an Access-owned commit guard. Preparation parses a detached copy of only the affected device through `AccessControlledDeviceState.from_record`, preserving every unrelated live device object. The prepared value retains the expected live affected device reference (or expected absence for creation), its complete detached original record, the candidate device (or removal), and its validated stable key. Before mutation, commit checks expected reference/absence, equality with the original record (including in-place mutations), single-use consumption and capacity; a changed device rejects the whole command. There are no signals, awaits, snapshot restores or restore-generation increments in either phase.

Production handles the four door operations in a dedicated synchronous path after current authorization, body/session epoch, exact-intent replay and revision checks. It prepares its detached registry/stock/receipt candidate, validates the trusted bill, complete support, all occupancy and owner links, reservation coverage, receiving capacity and the Access candidate. The final potentially failing operation is Access commit. Once that succeeds, Production assigns the already validated state candidate with no subsequent call that can reject. A failed Access commit leaves Production untouched and performs no Access write. This path changes neither Inventory nor Tools state. It does not reuse world snapshot rollback, and does not replace the Access device dictionary or unrelated circuit state.

World restore validates the new bidirectional door/device links before `SimulationRunner.restore_snapshot`; empty migrated registries create no hardware. Independent owner restores with live door links must reject mismatched state rather than silently reconstruct or delete a device. Retained bill and identity cannot be edited via Access commands, bypass jobs or client payloads.

## Concrete support, occupancy and contact contract

Use a hinged manual prototype so open state has explicit physical geometry. In local coordinates, the frame is 1000 mm wide, 2000 mm tall and 100 mm deep, with 50 mm jambs and a 100 mm lintel. The leaf is 900 x 1900 x 50 mm; its open pose rotates 90 degrees around the left jamb. Reserve the conservative entire swing AABB (1000 x 2000 x 1000 mm, extending 950 mm forward and 50 mm backward) against installations, fixtures and other door sweeps. Quarter-turn transforms use exact integer millimetres. The 2 kg processed plate bill is an explicit trusted prototype frame/leaf bill, not a density calculation, engineering rating or pressure claim. No separately salvageable components are modeled in this slice.

Require full paid floor coverage of that 1000 x 1000 mm swing/support footprint at height zero using the union of canonical validated floor rectangles. Reject support-panel removal if the remaining union would leave any attached door unsupported. Ceiling panels cannot count as support. Door frame and swing remain independent of geometric room closure.

The Inventory snapshot supplies all canonical body poses, profile bindings, world storage roots and held grip targets. Register only the existing human v1 body mapping (350 x 900 x 350 mm half extents with the same legacy anchor/centre policy as wall movement). Reject an operation if any body lacks its canonical profile or has an unsupported profile. Carried/nested items have no independent world pose and use the containing body's envelope. Existing world tray uses the explicit production fixture keepout; deployed factory storage must match a canonical machinery placement and use its complete expanded machinery envelope. Any unmatched world storage root or unmapped held world target fails closed. No shape is inferred from volume or client geometry.

Installation, opening, closing and removal all require the entire conservative swing envelope to be clear of mapped bodies, world roots and grip targets, including the actor; reach permits operating from outside the swing. Opening/removal cannot erase occupied matter. Fixed frame solids always block movement; the leaf uses its actual closed/open AABB. Canonical movement checks use the same solids and reject unsupported body shapes.

Add a dedicated `DoorContactObservation` v1 and `door_contact` envelope with complete sorted bounded frame/leaf boxes, world/region scope, sequence, Production and Inventory restore fences and ticks. At most 16 doors and four solids per door. Its strict decoder validates IDs, role, exact dimensions, integer transforms, unique ordering and complete grouped assembly geometry. Reuse physical box rendering lifecycle through a distinct binding; do not accept vertical boxes in `PaidPanelContactObservation` or change that schema. Clear on stale/malformed/scope/disconnect/restore input. Player door observation has its own v1 contract; Production observation advances compatibly from v10 to v11, retaining v10 decoding for old servers. Unknown versions fail closed.

Manual operation requires the current real crowbar capability via Inventory/Tools, explicit manual-operate permission and the installing principal/body binding. Each command carries the current body control epoch; the host independently validates its authenticated session when queued and when applied. The installation does not retain an obsolete session or epoch that would prevent its owner operating it after reconnect. Access validates the commissioned manual actuator's integrity, mode and released latch at zero pressure load only because this door has no pressure port. Bypass grants never convey construction, ownership, material recovery or installation identity. Nonempty bypass/hardware state blocks disassembly.

## Shared file ownership requested

Existing owners: `src/core/production/production_simulation_system.gd`, `src/core/access/access_control_system.gd`, `src/core/inventory/inventory_simulation_system.gd`, `src/core/runtime/world_runtime.gd`. Existing adapters: `src/adapters/network/first_playable_host.gd`, `src/adapters/network/remote_world_runtime.gd`, `src/adapters/network/remote_production_projection.gd`, `src/presentation/production/machinery_panel.gd`, `src/app/first_playable_bootstrap.gd`, horizontal control/preview observation compatibility, and `.github/workflows/production-recipe-observations.yml`. New narrow files: trusted door blueprint, paid door planner/geometry, prepared Access change, dedicated door observation/contact codec/presentation, schemas and focused runtime/schema tests. No pressure, terrain, ship, EVA, art or existing circuit owners are in scope.

## Source review evidence

Reviewed against `772a5bb9c27068def68847bf7a83a4b599b14e0c`: `SpatialWallConstruction` defines wall pose, body-envelope and fixture keepouts; `HorizontalPanelConstruction` defines paid rectangles, area bills and capacity checks; Production `apply_local` has the shared claim-coverage guard; Inventory `active_tool` resolves held capabilities through Tools. Access has reusable actuator/device parsing and manual validation, but no prepared construction transaction. `SimulationRunner.restore_snapshot` validates systems before writing them; `WorldRuntime` separately validates cross-owner references. The current contact decoder admits only horizontal 12 mm floor/ceiling boxes, so admitting vertical door boxes there would violate its contract. Existing world inventory records provide containers and positions, not arbitrary item meshes or geometric extents.

Implementation and focused regression/schema checks are present. Import and headless startup passed at `589a2939bb142f845b5e9eeb78a73518a540b221`; the earlier blueprint numeric comparison and contact decoder parse defects were corrected. Expanded lifecycle, actual host reconnect/queued-session rejection, UI submission and physical contact checks await a fresh exclusive runtime lease. CI-export acceptance remains pending; source presence and startup are not lifecycle acceptance.

Door-only hosted commands retain a weak host reference and an opaque per-authentication lease. Both validation and application recheck the exact current peer/slot/session, stable principal and resolved body. Reconnection retains installation ownership while retired queued commands reject. Other Production commands are outside this transport-liveness correction.

## Acceptance

Use finite extracted/refined/processed stock to build, operate, save/restore and disassemble the real assembly. Check exact conservation, request replay, stale revisions, foreign actors, reach, absent/broken tool, insufficient stock, active reservations, occupied closing, overlapping placement, malformed records, orphan/cross-bound links and failed preparation rollback. Preserve the legacy fixture and older saves.

Expose a small player control path through the existing production ingress and owner observations. Reuse Windows/Linux CI and inspect the actual synthetic tested revision and parents plus both export manifests/checksums. Local Godot requires the Coordinator's explicit exclusive bounded no-port lease and a fresh process check. No capture, port, media, deployment or successor work is authorized here.
