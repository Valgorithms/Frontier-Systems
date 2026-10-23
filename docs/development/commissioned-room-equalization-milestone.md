# Commissioned room manual equalization: design proposal

Base: `0536a7de178214daf06880475b17c17aae85d9f1` (merged PR146).
Owner: this isolated `commissioned-room-equalization` worker; design/merge owner:
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d`.
Status: Coordinator accepted the bill, manual energy policy and implementation
scope at design head `821a1f05cb5ef9e590bc856ceaf11b53a384836f`. Implementation
in progress; local Godot remains unexecuted pending an exact-head exclusive lease.

Acceptance correction: the existing safety leak already flows above 0.5 kPa
at the proposed valve conductance, and the existing 1000 N manual door can move
at/below 0.5 kPa. This bypass does not uniquely unlock a stuck door or accelerate
over-rating recovery. Its usable new behavior is intentional equalization of
a nonzero subthreshold differential that the closed healthy boundary retains.

## Outcome and smallest slice

An authenticated constructing principal/body installs a paid manual bypass valve
on its commissioned room, opens/closes that valve intentionally, reads both
pressures and the differential, and uses the existing crowbar door operation once
the real force check permits it. Save/reload preserves hardware, valve position,
finite gas and bills. This is passive downhill exchange, never a powered pump,
setpoint refill, generic port network, full airlock, species or breathability work.

## Available source contracts and policy gap

- `src/core/pressure/pressure_system.gd`: one constructed room, finite
  `habitat_main`, phase after existing airlock transfers and before sensors.
  `_step_constructed_room` currently exchanges only through boundary leakage.
- `src/core/pressure/pressure_flow_solver.gd`: equal-temperature bulk-mole pair
  transfer, conductance in mol/(s*kPa), capped at equilibrium with 0.001 kPa epsilon.
  This already supplies the needed conservative passive transfer; no pump work
  model or constructed-room valve registry exists.
- `src/core/pressure/constructed_room_pressure.gd`: pinned habitat subdivision
  policy, 1000 m3 total allocation, 1.71 m2 door area, 0.5 kPa retention plus 1e-9
  comparison tolerance. Keep all values and legacy room semantics unchanged.
- `src/core/production/paid_door_construction.gd`: owner/body, crowbar, reach,
  occupancy, hardware and prepared Access change checks. `_apply_door` in
  Production already coordinates detached Pressure/Access/Production candidates.
- `src/core/pressure/pressure_room_owner.gd`: abstract typed boundary. Add only
  necessary abstract methods; do not introduce a concrete Pressure dependency
  into Production or PreparedDoorChange.
- `src/presentation/production/paid_door_controls.gd`: collapsed contextual
  controls, authenticated queue, state revision, control epoch, pending receipt.
  Reuse the hosted paid-door session/liveness path and own-door observations.
- `data/machinery/catalog.v2.json` has no valve/pump parts. Existing airlock
  valves belong to that controller and cannot authorize an unrelated room path.

New policy needing Coordinator acceptance: a purpose-built hand-operated metal
bypass, separately paid from processed plate, mounted to the existing paid
doorframe without changing its opening, seal or load rating. Proposed fixed bill
200,000 mg plate, closed by default; conductance 1 mol/(s*kPa) when open and zero
when closed. These are new first-party prototype tuning values, not inferred
existing device specifications or a pressure certification. No powered mode.

## Finite material and energy budget

PR146's real bootstrap route in `tests/godot/finite_bootstrap_acquisition_test.gd`
consumes 17 kg finite ore, yields 10.2 kg iron and 6.8 kg tailings, prints 8 kg
plate and makes the 2 kg crowbar. After enclosure/seal/commissioning it retains
200,000 mg plate, 200,000 mg iron and 68,750 J. Proposed valve uses exactly that
remaining plate, leaving 0 plate / 200,000 mg iron / 6,800,000 mg tailings and
68,750 J. Manual fabrication/operation costs zero electrical energy, consistent
with existing manual door/seal assembly; this is an explicit new design choice.
No new stock, recovery grant, ore yield, recipe change or energy refill. If this
bill or manual fabrication policy is not accepted, acquisition/fabrication design
is a prerequisite; a seeded positive test cannot substitute for it.

Production owns the immutable bill/identity and refund, included in its total
mass ledger and reservation-aware spend/capacity checks. Install only on a
commissioned own closed door with real held crowbar. Refund only after closing
the valve and decommissioning; prevent door removal from discarding hardware.
Preserve the part while decommissioned; recommission it closed. No tick wear,
automatic repair, hidden force upgrade or refund of gas. A simpler no-refund
first slice is not acceptable if it silently loses recoverable paid material.

## Authority, saves and presentation

Pressure owns the valve open/closed operational state linked to an installed
Production part; Access continues to own door condition/latch/actuation. Valve
actions require existing constructing principal/body, session liveness, permission,
reach, real tool, exact revision and epoch. Clients supply only door ID and an
explicit operation, never gas, endpoint, area, bill, conductance or pressure.
Replay cannot debit/refund or toggle twice; use explicit open/close operations.
All candidates and cross-owner links validate before the existing non-yielding
compare-and-install commit. Failure leaves receipts, hardware, gas and stock intact.

Each fixed tick uses one pair transfer with conductance = maximum of the existing
leak path and the open-valve path (both are 1 in this policy); never accidentally
double the existing leak rate. A closed valve does not suppress safety leakage.
An open passive valve can reduce differential below 0.5 kPa to equilibrium;
closing it may retain the resulting differential. Existing manual force checks
still decide door movement. Broken/missing links stop flow and retain gas.

Saves: Production v13 adds paid bypass records per door with
an immutable bill; Pressure v3 adds bounded valve state per commissioned room.
Older Production v1-v12 and Pressure v1-v2 retain their absent-valve formats,
granting no material and preserving their gas and allocation. Records with no
paid parts continue to emit Production v11/v12 by original catalog, and Pressure
with no commissioned valve continues to emit v2. Production v13 permits either
existing catalog without changing its origin budget. Use explicit
version dispatch, strict schemas, orphan/duplicate/missing-link rejection and
whole-world prevalidation before assignment. The commissioning geometry copy
must remain stable when a valve is installed; store its bill outside geometry.
Do not mutate the old pinned geometry schema to smuggle hardware into a room.

Observation v15 / paid-door v4 expose installed/open while retaining old decoders.
Derive absolute differential and the existing manual force budget from room
telemetry for display; Access remains the movement authority. Show valve status beside
the existing room pressures; add install/open/close/recover actions to the
collapsed door panel, with cost and pending/error feedback. No new screen or
new custom assets. Bounded counters: installed/open valves and transferred moles;
no per-tick unbounded logs. No environment/configuration additions expected.

## Acceptance and requested verification bounds

Extend the real PR146 acquisition route, without editing owner stock or gas, to
pay/install the valve, command open/close through normal authorization, persist
and reload it, and recover the exact bill after decommissioning. For a meaningful
positive pressure gradient, use existing legitimate airlock habitat transfers
after commissioning; do not call `from_pressure` or seed positive gas snapshots.
Check all-volume moles before/after, invariant 1000 m3 allocation, bounded
flow, equilibrium/no overshoot, closed-valve retention, and
unchanged over-rating leakage. Prove normal crowbar recovery by the real force
check, preserving damaged hardware. Above-rating force rejection/leak parity uses
isolated negative-only finite redistribution fixtures; those cannot fund the
positive path. Whole-world reload while open must resume
finite exchange with the same state; closed reload must retain it.

Negative controls: missing/foreign/uncommissioned hardware, insufficient plate,
active reservations, stale revision/epoch, session loss, out-of-reach, absent tool,
replay/changed payload, refund capacity, removal while commissioned/open, orphan
state, unknown versions, forged bill/endpoint/conductance, legacy no-grant and
all-owner unchanged on rejected restore. Keep original pressure/door/topology,
finite bootstrap and snapshot regressions.

Request a later exact-head exclusive NO-PORT lease only after source/design
acceptance and a fresh Godot process list is empty. Proposed bounded runtime
scripts: new equalization test plus paid_door_pressure_room_test,
finite_bootstrap_acquisition_test and the affected snapshot regression selected
from current CI. Use the AST-extracted versioned helper and stop at the first
diagnostic, with no retry or edits under lease. No import/startup/listener/export/
capture/full runner without an explicit lease. Final CI must actually execute
required Windows/Linux tests at the final head (record synthetic merge revision
separately), plus schema contracts and existing policy checks. Captures only if
material usability uncertainty remains; no deployment/publication or worker merge.
