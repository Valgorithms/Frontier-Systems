# Paid two-door chamber: implementation proposal

Status: design only, awaiting Coordinator scope review before runtime/schema edits.
Base: `1f2e5a71d0a2a9b6c1ac56ac0c1354ea2b200d58`, following PR148 merge
`25293641ab9263f699768d7d585a42cd80a2ab2d`.
Exclusive implementation owner: chat `01a16aa0-d610-7e41-b5a4-0868e3742b28`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns scope review, exact-head
NO-PORT runtime leases and final CI acceptance/merge. Worktree `paid-chamber-successor`,
branch `paid-chamber-sequential-interlocks`. One implementation chat; no delegation.

## Observable outcome and bounds

A fresh playable world can acquire finite ore, refine and print its own materials,
fabricate and hold a real crowbar, build one 3.6 m3 chamber with two paid manual
doors, fit two seals/two recoverable bypasses and a distinct paid 6 kg containment
kit, then commission and deliberately operate it through hosted player controls.
The chamber is mutually exclusive with the existing commissioned one-door room.
Its inner endpoint is explicitly `habitat_main`; outer is `exterior_reservoir`.
These are logical connections, without spatial atmosphere mapping or implied EVA,
breathability, species, pumps, temperature/species mixing or general networks.

Retain the geometry and independent source analysis in
[the prerequisite design](paid-two-door-chamber-milestone.md#full-successor-target-geometry-and-budget):
four walls, doors at [5050,0,-4000]/[6950,0,-4000] quarter-turn1, interior
x[5100,6900] z[-4500,-3500] y[0,2000], floor x[4100,7000]. Floor and ceiling
are tiled into existing legal panel sizes, never oversized single panels. Actual
topology, PhysicsServer contact, occupancy and clearance must establish usability.
Retain area 1.71 m2 and crowbar 1000 N. Explicit prototype containment tuning is
110 kPa, supported only by existing Access actuator integrity/seal condition and
validated paid geometry/kit links; no invented wall-health model or certification.

## Rechecked finite acquisition budget

At this base `data/production/catalog.v3.json` contains 10+7+7 = 24 kg ore.
`refine.iron` yields 0.6 kg iron/0.4 kg tails per 1 kg input for 1000 J;
`craft.plate` consumes 1 kg iron and 1000 J. Production starts at 100000 J,
charges 250 J per extraction and caps depot mass at 100 kg. The existing
fabrication path costs 2 kg iron and 2000 J for the held crowbar.

| Bill | Mass / energy |
| --- | ---: |
| Four walls / two doors | 4 / 4 kg plate |
| Floor including swings / ceiling | 2.9 / 1.8 kg plate |
| Two seals / two bypasses | 0.4 / 0.4 kg plate |
| Distinct containment kit | 6 kg plate |
| Installed plate | 19.5 kg |
| 37 ore extractions | 9250 J |
| Refine 37 kg ore | 22.2 kg iron + 14.8 kg tails; 37000 J |
| Print 20 kg plate / fabricate crowbar | 20000 / 2000 J |
| Total / remaining electrical energy | 68250 / 31750 J |

Final accounted matter: 19.5 kg installed + 2 kg crowbar + 0.5 kg plate +
0.2 kg iron + 14.8 kg tails = 37 kg. Untouched 5 kg ice/10 kg regolith make
52 kg world origin. One-kg extraction/unload batches fit the 2 kg carrier;
even all acquired material fits depot capacity. Existing conservative wear over
37 completed cycles leaves tools usable. Manual assembly/recovery and passive
gas transfer cost zero electricity; no new power, tool or stock grant.

Propose catalog v4: preserve v1/v2/v3 bytes and add a distinct reachable
`deposit.iron.chamber` with exactly 13000000 mg ore, explicit fingerprint,
source position/reach and selectable UI label. New-world composition opts into
v4. Legacy catalogs, missing-Production migration and depleted sources receive
no added source or refill. Legacy players may only build from their own remaining
stock; this milestone does not promise the full route in existing v3 worlds.
The 6 kg kit is separately paid, with an immutable receipt. The earlier 4 kg
room kit must be recovered normally before reusing its material; it cannot
be interpreted as a chamber kit or pay for a free second door.

## Owners, admission, ticking and recovery

Production owns geometry, kit/seal/bypass materials, finite origin, reservation
claims and exactly-once debit/refund receipts. Access owns both actuator states,
seal condition, collision-safe opening/closing and the unchanged force check.
Pressure owns one separate chamber record, volume, sensors, endpoints and valve
states. Inventory/control owns body, session, held usable tool and reach. UI
owns selection/pending presentation only. Extend existing prepared-owner
transactions and whole-world detached validation, rather than a second authority.

Commission only a complete owned closed intact pair with both bypasses closed,
no existing commissioned room, supported geometry and paid kit. Subdivide 3.6 m3
from the current 1000 m3 habitat proportionally at its actual temperature/moles;
allocate nothing from an infinite reservoir. Decommission only with both doors
closed, both valves closed, intact geometry and both boundaries within the manual
pressure margin; merge chamber gas/volume back into habitat conservatively.
Decommission itself neither moves the body nor opens geometry. Recover the kit
exactly once after decommission with reservation-aware receiving capacity; then
allow ordinary paid-part recovery subject to current occupant/support guards.
Recommission retained hardware explicitly without healing condition.

Commands use explicit desired state, current Production revision and restore
epoch, authenticated session/body/owner and held crowbar/reach. Check both sides
again at apply, including low-level Access admission. Opposite door and bypass
must be closed/intact before opening a selected bypass or door; own bypass must
be closed before door operation. Opening both valves, both doors or a
door-plus-bypass is rejected. Closing remains available when safe for occupancy.
Request replay returns the same receipt; changed intent with reused ID rejects.

Outbound: close inner, open outer bypass, wait for actual force-safe differential,
close bypass, open outer, pass through, close outer. Return: outer closed, inner
bypass open until finite pair equilibrium permits force, close bypass, open inner,
pass through, close inner. No automatic valve sequencing or target-pressure writes.
Damaged opposite boundary leaks and blocks unsafe admission; UI cannot advertise
isolation. Blocked transitions retain gas, stock, receipts and actuator state.

At the fixed pressure tick, retain existing prototype transfers, then process
chamber inner followed by outer before sensors. Per boundary use max(passive
leak, open bypass) at existing conductance 1 mol/(s*kPa), not additive paths.
Open/degraded/overrated boundaries leak; closed valves never suppress leakage.
Use existing equal-temperature equilibrium-capped solver, nonnegative moles and
0.001 kPa epsilon. Persist ordering; bounded transfer/leak/block counters only.
Finite exterior and habitat change each cycle. Compare all-volume total moles
and volume at every lifecycle step; the unrelated prototype may also consume
these reservoirs. No constant101.325kPa refill assumption.

## Save, observation and player control contract

Propose Production save15, observation17, paid-door6 and Pressure save5, with
explicit chamber/kit v1 records. Keep existing room dictionaries and decoders
semantically unchanged. Preserve Access version unless its exact contract needs
new fields; enforce cross-owner pair rules through detached validation. New
chamber records require unique paired IDs, fixed endpoint identities, exact bills,
matching owner/body/world/region/geometry/area, sensor/volume links and valve
states. Validate full Production/Pressure/Access/Inventory candidates before any
assignment. Malformed half-restores must leave every owner, tick, receipt,
revision and epoch unchanged. No permissive union or repair-on-restore.

Extend the existing collapsed paid-door controls with explicit chamber pair,
inner/outer selection, kit cost/fit/recover and commission/decommission actions.
Show three actual pressures, selected delta/load, opposite boundary state,
both valves, pending receipt and exact blocking reason. Actions enqueue existing
authenticated host commands; stale/disconnected/rebound state disables them
until a fresh authority observation. No client pressure writes or sequencing.
Exercise actual source selector, action queue, projection and control paths.

## Acceptance and verification budget

Positive: unseeded fresh first-playable acquire37kg/refine/print/fabricate/build
route, exact68250J and all mass accounted; actual body support/contact through
both apertures; both manual cycle directions; habitat isolated during outer vent;
finite pressure loss over repeated cycles; all-volume mole/volume conservation;
kit recover/refit and whole-world reload with open/closed valve resume.

Negative controls: insufficient/reserved stock, carrier/depot/refund capacity,
power/tool/reach, foreign owner/body/session, stale revision/epoch, replay and
changed intent, malformed paired restore with all-owner equality, false bill/
endpoint/kit/area/rating, missing/orphan links, unsupported/overlapping sweeps,
occupied closure, both-open doors/valves and door-plus-bypass, damaged opposite
seal/actuator, both pressure signs exceeding1000N, overrated leak, closed valve
not suppressing leak, unchanged old0.5kPa policy, depleted/exhausted source reload,
legacy no-grant and recovery with no healing/refill. Preserve finite bootstrap,
room/bypass/reinforcement, UI, snapshot and emitted-schema regressions.

Bound work to this one usable slice and its documentation/schemas/tests. No new
agent chats, generalized networks, repairs, art, dependencies or env variables.
Static design/arithmetic/diff review first; runtime/schema work starts only after
Coordinator accepts this pinned scope. Then smallest meaningful authored checks,
freeze/push exact head, request one bounded exclusive NO-PORT lease with named
stages and time budget. Use versioned AST-extracted Invoke-GodotCheck, empty
preflight inventory, stop on first diagnostic, preserve logs, do not edit/retry
under lease, postflight inventory and explicit release. Required Windows/Linux
CI and emitted-schema negatives must pass on the final head; distinguish tested
merge revision. Capture only if material usability uncertainty remains after real
control/runtime checks. Final task-closeout and matching-head Coordinator review
precede merge. No deployment, publication, media, financial or outreach action.
