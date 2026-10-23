# Constructed room pressure boundary: proposed design checkpoint

Base: PR143 merge `a55d5b51f7fa30094f3afc3b1bc81d92e81c0866`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns design acceptance,
merge, ledger and active state. Worker branch: `constructed-room-pressure-boundary`.
Status: Coordinator accepted habitat subdivision and commissioned load area;
implementation authorized with the corrected retention limit below. No runtime lease.

## Smallest usable outcome

An authenticated builder explicitly commissions one complete paid rectangular
enclosure as a finite pressure compartment, reads its pressure and boundary
state, and opens/closes its existing manual door against the actual pressure
load. A commissioned closed intact seal retains gas; opening or degrading its
boundary exchanges gas with a finite surrounding compartment. Save/restore
preserves the allocation, gas and damaged hardware without healing or duplication.

Limit the first policy to one constructed room in `local-habitat`, one owner/body,
and exactly one paid doorway. Retain the current exact rectangular wall-band,
non-overlap and complete floor/ceiling restrictions. Reject other layouts and
foreign panels/doors. Legacy shared region walls remain shared support: recognition
does not transfer ownership. PR142 stays a diagnostic with its existing status;
a separate Pressure-owned commissioning record supplies authority.

## Evidence and explicit policy decisions requiring review

At the base, Pressure owns three finite `PressureVolumeState` compartments and
bulk moles at 293.15 K. `GasMixtureVolume` is a detached species contract, not a
runtime gas owner. No generic runtime pressure-port registry or spatial ambient
map exists. `PressureFlowSolver` supports conservative isothermal pair transfers
in mol/(s*kPa), capped at equilibrium. Existing airlock door motion itself does
not transfer gas. Do not infer breathable species, mass in Production milligrams,
thermal behavior or a generic network from these interfaces.

Proposed server-owned policy `constructed-room.habitat.prototype.v1` explicitly
defines the local construction domain as a subdivision of `habitat_main` for
this prototype. This is a new gameplay allocation rule, not an inference from
current geometry or an existing spatial pressure map. Reject other worlds/regions.
The policy fixes the ambient endpoint to `habitat_main`; no client may select a
source, ambient, pressure, volume, area, conductance, rating or policy revision.
This avoids manufacturing vacuum in an already pressurized habitat or allocating
the same modeled volume twice. Coordinator acceptance of this domain rule is
required before implementing it.

Proposed policy values, also requiring review: 1.71 m2 effective load area
(0.9 x 1.9 m clear opening), 0.5 kPa maximum retained differential, zero modeled
conductance only while closed with installed seal condition exactly 1, full
actuator integrity, released intact latch and usable manual mode. Every open,
missing/degraded/failed seal, damaged/disabled/jammed hardware, or over-rating
state uses conductance 1 mol/(s*kPa). This deliberately conservative binary
leak model has no physical certification, continuum-flow or real gasket claim.
Opening is never an instant deletion of gas. Integrity or seal damage remains
Access-owned; the leak model cannot repair it or manufacture paid material.

Coordinator correction: Access actually supplies 1000 N manual force, so its
1.71 m2 opening becomes inoperable above approximately 0.584795 kPa. The earlier
2 kPa proposal could trap a room above that threshold. Use a stateless threshold
at 0.5 kPa plus 1e-9 kPa comparison tolerance, with no hysteresis or saved leak
latch. Leakage continues above that threshold, and can stop only within the
strictly operable margin. The existing solver's 0.001 kPa equilibrium epsilon
is far below this margin. Test a differential inside the former trap interval,
including restore, and prove conservative leakage reaches an operable state
without a new valve, ignored force, healed hardware or injected gas.

The policy grants pressure service through explicit commissioning, never from
condition 1 alone. Existing uncommissioned PR143 seals/doors retain zero load
area, zero rated force and no flow link. Maximum powered force remains zero;
manual actuation uses Access's existing real-tool check and 1000 N force limit.
For commissioned doors, replace the literal zero differential with authoritative
absolute room/ambient difference, with 1.71 m2 commissioned effective area. Both
opening and closing use that conservative load check. Pressure policy and Access
links must agree; clients and observations cannot install pressure hardware.

## Volume, gas and geometry

Use the validated PR142 interior X/Z bounds and its current floor=0/ceiling=2000
mm contract: volume_m3 = width_mm * depth_mm * 2000 / 1,000,000,000.
These are the existing modeled free-volume planes, not a new interpretation of
panel center/thickness. Require finite positive volume below the available
ambient volume with at least 1 m3 remaining. No resizing or second room.

Commissioning splits ambient gas proportionally to the allocated volume at its
current pressure/temperature: subtract exactly the assigned moles from ambient
and subtract the room volume from ambient's 1000 m3 allocation. Keep the room
plus ambient modeled volume invariant at 1000 m3; chamber/exterior are separate.
Use finite checked arithmetic and documented relative/absolute float tolerances
for bulk-mole conservation. This does not promise exact integer species or gas
mass accounting. Never call `from_pressure` to refill or reset a restored room.

Require a closed intact installed paid seal for commissioning. Fresh server room
and sensor IDs derive from authenticated principal/request; retain canonical
wall, panel and door IDs, poses, bills and policy revision as immutable links.
No cached topology can authorize commissioning, including after same-revision
restore. No material debit/refund accompanies this allocation; paid construction
and the installed 200,000 mg seal remain in Production's existing mass ledger.

While commissioned, prevent removal/reposition of linked walls, floor, ceiling,
door or seal through every applicable Production path. Opening/closing stays
available through the real held crowbar and existing session/reach/occupancy
checks. Decommissioning requires the door open and usable, then merges all room
moles and volume back into ambient atomically and removes the room/link/sensor.
Allow gas-free or unequal-pressure merge only as this explicit finite-volume
abstraction; it conserves moles and volume and does not claim physical vent timing.
Never silently delete a gas-bearing room on failed geometry validation.

## Owners, transactions, ticks and restore

Pressure owns room identity, allocated volume/gas, policy revision and runtime
link. Production owns paid geometry, seal identities/bills, revision and durable
command receipt; Access owns actuator position, condition, latch, force and area.
Inventory/Tools retain body, authorization, reach and real held-tool ownership.
Use exact revision/control_epoch intents with no geometry/pressure supplied by
the caller. Commission/decommission must use the existing authenticated command
queue, scoped replay receipt and transport liveness checks, not a direct UI call.

Prepare detached candidates for all affected owners. Check capacities, stable
links, revisions and restore generations before the first mutation. Extend the
existing prepared-door transaction to compare the Pressure candidate as well as
the Access device; perform a non-yielding all-owner commit with no fallible work
after its first assignment. If that cannot be guaranteed, implement rollback and
test injected failure at each commit boundary before calling it atomic. Stale
CAS, permission, reach, tool, topology, arithmetic or link failures leave all
owners, receipts, stock, gas and sensors unchanged.

Each fixed tick derives conductance from current Access state and validated
commissioning links, then performs sorted bounded pair flow after the existing
airlock transfers and before sensor sampling. No async service callback mutates
gas. At most one constructed link; count active rooms, leakage transfers and
commission/decommission rejects using bounded counters. Existing airlock order
stays stable. Damage applied through Access before the Pressure phase affects
that phase; damage after it affects the following tick. No new damage UI is needed.

Pressure save v2 adds strict room/policy/link allocation records; v1 migrates to
zero rooms without changing existing gas. Production save v11 can stay unchanged
if the durable command ledger already accepts the new operations; verify that
assumption before schema work. Existing Access v1 records can encode the area,
but paid-door validators must require 1.71 only for a matching commissioned link
and zero otherwise. Persist no duplicate gas in Production or observations.

Extend WorldRuntime's normalized cross-system prevalidation and paired restore
guards to Pressure/Production/Access, before any owner assignment. Decode all
candidates against each other, not against a mixture of live and restored owners.
Reject missing/duplicate/orphan links, wrong policy/domain/owner/body, changed
geometry/bill/area, incomplete surfaces, invalid allocations, sensor mismatch,
nonfinite gas and incompatible temperatures. Independent owner restores must
reject inconsistency too. Validate the 1000 m3 allocation invariant; do not invent
a fixed total-mole invariant because existing airlocks legitimately exchange gas
with chamber/exterior. Unknown versions fail closed. Damaged commissioned doors
restore with leakage and their actual gas, never with healed seals or reset pressure.

## Bounded implementation files and acceptance

Expected scope: `src/core/pressure/pressure_system.gd`, new small room policy/state
types under `src/core/pressure/`, paid-door planning and Production guards/commands,
`src/core/access/prepared_door_change.gd` and paid-door link validation,
`src/core/runtime/world_runtime.gd`, existing production transport allowlists and
own-only observation codecs, paid-door controls, versioned schemas and relevant
architecture documentation. Add focused owner-integration runtime and schema
tests; reuse existing helpers and automatically discovered CI test runners.
No generic port system, airlock automation, pumps, breathing integration, asset,
dependency, environment configuration, catalog or bootstrap stock change.

Player acceptance: commission/decommission actions and own pressure/status in
the existing production controls; real finite paid construction and installed
seal, actual loaded manual operation and visible leakage status. Changing the
ambient pressure through existing finite airlock transfers supplies an integrated
test differential; an explicit test-only gas redistribution may provide larger
negative controls while preserving total moles. Neither is a free gameplay gas
injection or tank integration claim.

Tests must cover geometry in both orientations, current-owner inclusion, split
and merge conservation, closed retention, open/degraded/failed/over-rating leakage,
equilibrium capping, 1000 N actuation rejection, next-tick condition changes,
replay/reconnect, reservations, unsupported geometry and every linked removal
path; stale prepared states and injected commit failures; whole-world and
independent restore, v1 migration, same-revision changed geometry, malformed
policy/area/bills/sensors and degraded-state round trips. Require unchanged
PR142 diagnostic behavior and uncommissioned PR143 zero-area behavior.

Retain the default 6 kg refined-iron limit versus the 7.6 kg example enclosure
plus 2 kg crowbar and 0.2 kg seal. A positive full-room test uses the existing
explicit mass-conserving seeded owner fixture, clearly separate from the default
ore lifecycle. Do not increase free stock or ore, or claim default ore-to-room
feasibility. No local runtime until an exact-head exclusive bounded no-port
Coordinator lease; no listeners, capture, export or Gaia1714. Required Windows/
Linux CI remains necessary for implementation acceptance. Screenshots only if
meaningful tests leave material uncertainty. No merge, successor, deployment,
publication, outreach or PR85 changes in this worker scope.
