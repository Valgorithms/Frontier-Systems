# Deferred two-litre chamber storage analysis

Status: Coordinator declined implementation on 2026-10-23. Historical rationale
only: tiny capture and retained filled hardware do not justify this adapter.
Prototype shell reuse remains UNAPPROVED. None of the recommendations below
constitute current scope or authorization. See the replacement
[powered recovery proposal](finite-chamber-gas-storage-milestone.md).
Base: `db74161ab66b38365b9fd76b48de18480a98c036` (PR149).
Owner: chat `01a16ad6-6e04-7503-8e5c-f9377e9fb5cd`, branch
`finite-chamber-gas-storage`, managed worktree `finite-chamber-gas-storage`.
Coordinator: `01a1283c-45d6-7e61-bedd-905e8797f03d` owns design acceptance,
runtime leases and integration. No implementation or Godot execution authorized yet.

## Source findings and dependency decision

The scratch-construction roadmap's remaining atmosphere adapter row explicitly
requires constructable pressure vessels and owner adapters. PR149 supplies a paid
3.6 m3 chamber, finite habitat/exterior endpoints, interlocked manual doors and
bypasses. It does not supply a recoverable gas vessel. Storage is a valid next
foundation, but passive storage cannot provide lossless chamber evacuation.

Reviewed at the pinned base:

| Source | Consequence |
| --- | --- |
| `docs/development/scratch-construction-milestone.md`, remaining adapters | Build through trusted blueprints/owners; never clone fixture contents |
| `src/core/pressure/pressure_system.gd`, `_prepare_chamber`, `_step_paid_chamber`, snapshot decoder | Pressure already owns chamber gas, ordered flow and paired links; retain this owner |
| `src/core/pressure/pressure_flow_solver.gd` | Equal-temperature flow follows the gradient and stops at equilibrium; no compression or uphill return |
| `src/core/pressure/pressure_volume_state.gd` | Runtime bulk mol, m3, K and absolute kPa; no species or molecular mass |
| `data/inventory/canister.v2.json` | Real fabricated carrier has 2000 ml bulk space and 2500 ml external volume; no gas rating or valve |
| `data/production/timed-canister-blueprint.v1.json`, `timed_canister_construction.gd` | 1 kg iron shell, 1000 J fabrication, 120-tick reservation lifecycle; preserve existing blueprint/fingerprint |
| `data/inventory/shared.production.v1.json`, `src/app/first_playable_bootstrap.gd` | Existing physical prototype carriers can be reused after unloading; do not create another starter |
| `src/core/production/production_simulation_system.gd`, `_apply_door`, `validate_inventory_links`, checkpoint guards | Production owns material receipts, Inventory physical identity; prepared cross-owner validation already exists |
| `docs/design/breathing-mixtures-and-pressure-control.md` | Species-aware micromoles are detached groundwork, not a runtime replacement or permission to invent gas composition |
| `docs/development/paid-chamber-sequential-interlocks-milestone.md` | Fresh route uses 39 kg ore, 71750 J and leaves 0.6 kg plate / 0.4 kg iron |

Recommended smallest slice: a **paid manual gas-port insert on one existing,
empty, owned 2-litre canister**, placed and latched beside the chamber. Reuse
Inventory/Production identity and Pressure bulk flow. This is a small physical
storage/transfer/recovery foundation, not a practical chamber recuperator.
Prototype and fabricated shells remain distinguishable with their original
provenance; only explicit fitting creates a gas-rated assembly. No old carrier
becomes gas-rated on load. Approval must explicitly accept using a pre-existing
prototype shell for the fresh route; a fully player-fabricated extra shell does
not fit the current simultaneous chamber budget.

At 101.325 kPa and 293.15 K the chamber has about 149.656 mol. A vacuum
0.002 m3 receiver equilibrates at 101.26874 kPa, receiving about 0.08310 mol:
only 0.05552% of the chamber gas. After venting the chamber it can return gas
downhill, but cannot restore the original pressure. Do not advertise gas savings
large enough to unlock door opening, evacuation, or lossless repeated cycles.
Once at equilibrium it cannot accept further gas without an actual lower-pressure
destination. Existing exterior gas remains in the finite exterior owner.

Alternatives for Coordinator decision:

1. Accept the small adapter as groundwork with the limited outcome above.
2. If useful bulk recovery is the intended next outcome, reject this scope and
   first design a larger paid receiver and its geometry/material bill. A vacuum
   receiver equal to chamber volume captures only 50% on first equilibrium;
   90% needs nine chamber volumes (32.4 m3), not a canister capacity rewrite.
3. Near-vacuum recovery into compact storage requires powered compression,
   energy/work accounting and rated components. That is a later separate design,
   outside this task. Species/tank/suit integration is likewise not prerequisite
   for the existing bulk-mole chamber and must not be smuggled into this slice.

## Proposed physical assembly and finite budget

One insert costs exactly 200000 mg processed plate, manual fitting/removal at
zero electrical cost with the existing usable held crowbar. This is explicit
prototype tuning, not pressure-vessel engineering certification. No new ore,
energy, gas, tool, shell or repair grant. Existing sources/catalog bytes unchanged.
Fitting requires an owned empty prototype or fabricated carrier, no nested
payload, no machinery socket and an unreserved shell; it consumes its bulk space
exclusively. Bulk load/unload, nesting, extraction and machinery insertion reject
while fitted. Never count the same 2000 ml as both bulk and gas capacity.

Fresh PR149 route can unload its existing carrier and spend 0.2 of its remaining
0.6 kg plate. Total energy remains 71750 J / 28250 J remaining. Final incremental
matter accounting: installed chamber 20.4 kg + insert 0.2 kg + crowbar 2 kg +
plate 0.4 kg + iron 0.4 kg + tails 15.6 kg = 39 kg acquired ore. Existing starter
shell mass stays in its existing Inventory origin ledger; it is not added to the
ore budget. Fabricated shells retain their existing 1 kg iron structure receipt.
An additional fabricated shell needs 1 kg iron and 1000 J, but only 0.4 kg iron
is left and all 39 kg ore is exhausted. Do not silently add ore or reduce old bills.

Pressure volume is 0.002 m3, initially zero mol and 293.15 K, rated to 110 kPa
absolute under this fixed prototype policy. Vacuum initialization adds empty
capacity, not gas; explicitly account installed vessel volume separately from the
unchanged 1000 m3 habitat/chamber partition. Removal of an empty vessel retires
exactly that empty capacity. Gas transfers conserve all-volume moles.

Propose a bounded fixed socket on the chamber's inner side with an actual 3D
canister, supported position, collision and reachable handle. Final socket
coordinates must be demonstrated against actual door sweeps and the 600 mm body
route before implementation acceptance, rather than assuming a UI anchor proves
placement. Existing panel/door support must prevent removal while mounted.
No arbitrary pipes, cables, free endpoints, general topology or spatial atmosphere.

## Commands, ownership and pressure behavior

Production owns the paid insert receipt, shell/insert association, socket placement
and reservations. Inventory owns the shell and body/control session; Pressure
owns volume, gas, rated port state and flow. Access remains owner of both chamber
actuators and force checks. UI derives actions and never writes pressure.

Proposed explicit operations: fit/remove insert, place/recover assembly, connect/
disconnect chamber port, set port open/closed, and deliberately discharge through
the mounted service outlet to the finite exterior. Only one connection/direction
mode exists at a time; outlet and chamber connection are mutually exclusive.
Closing remains available when opening prerequisites fail, subject to valid owner
identity. No automatic sequencing, target pressure assignment or refill command.

Every operation uses authenticated principal/session/body/world/region, explicit
shell/chamber IDs, expected Production/Inventory/Pressure revisions and restore
epoch, live reach and appropriate hand capability. Fitting/operating requires
held usable crowbar and the existing construction capability; carrying requires
the existing empty/available hand rules. Recheck at enqueue and apply; receipts
bind exact intent. Changed-intent replay, foreign IDs, stale epochs and disconnected
observations reject. Bound receipt/assembly counts and overflow checks.

Opening the chamber connection requires both doors, both bypasses and service
outlet closed with intact chamber boundaries. While open, reject either door,
bypass, decommission, kit recovery and geometry removal. No weakening of 1000 N,
1.71 m2 force admission or original 0.5 kPa legacy room policy. Closed storage
does not change the chamber's existing leakage. Safe closure cannot depend on
opposite hardware being intact. No manual forcing of an unsafe door.

At existing fixed Pressure cadence process prototype flows, chamber flows, then
the single storage connection before sensors; persist deterministic ordering.
Use existing 1 mol/(s*kPa) conductance, equal-temperature equilibrium cap and
0.001 kPa epsilon. Reject nonfinite/negative states, mismatched temperatures,
unknown endpoints, self-links and incompatible policy/rating. No uphill flow,
species conversion, compressor work or hidden electrical debit.

New insert has intact/failed retained state, no invented shell-health simulation.
Above its absolute rating, mark failed and leak through the mounted service outlet
to the finite exterior using the same bounded passive solver, even with its valve
closed. Preserve insert/shell matter and remaining gas; closing is not repair.
Disconnecting is isolated by closed port; filled or failed assemblies stay latched
until explicitly discharged to zero solver residue. Define residue conservatively:
no epsilon deletion; any positive remainder blocks destructive salvage. A final
explicit discharge transaction may move the exact remainder to the finite exterior
without pressure reset, and must reject if that would require uphill transfer.
If exterior pressure prevents emptying, retain the filled hardware and report why.

Loaded portable gas mass cannot be derived from bulk moles without a composition
contract. Therefore prohibit carrying, nesting, salvage or arbitrary relocation
with any positive gas in this slice. This deliberate restriction avoids zero-mass
gas cargo. An empty isolated assembly can be recovered with its original shell ID,
unchanged insert condition and material receipts. Removing an empty insert refunds
its original plate once, subject to capacity/reservations; refitting never heals
failure. A failed retained insert can only be salvaged, not restored as intact.

## Transactions, save and legacy behavior

Extend prepared-owner operations; no second gas owner. Build detached Production,
Inventory, Pressure and relevant Access candidates, check common owner/body,
identity, shell provenance, empty bulk child, exact paid bill, unique volume/sensor,
socket support, chamber association, rating/temperature, capacity and every active
construction claim. Recheck compared revisions before a nonfallible commit.
Allocation/preparation/CAS failure leaves all owners and receipts unchanged.

Whole-world restore must validate the normalized complete candidates before
assignment, including the existing chamber pair and new mounted shell. Reject
orphan/duplicate gas volumes, inserted bulk payload, missing paid receipt, mismatched
condition/valves, false endpoint/rating/bill and unsupported versions. Failure
leaves all owners, tick, epochs, receipts and revisions equal to before restore.
Do not temporarily install one owner to validate another. Preserve exactly the
retained gas and open/closed/failed states through reload.

Expected future version boundaries: Production save16 / observation18 and Pressure
save6, insert/assembly record1, strict emitted schemas and decoder negatives.
Inventory save/definition and UI wire versions must follow the actual chosen
adapter representation; pin them in the accepted implementation amendment before
code changes. Preserve old item/blueprint definitions and fingerprints. Legacy
missing storage records mean absent assemblies, no gas, insert, rating, shell,
source, healing or refund. Never reinterpret prototype mixture fixtures as supply.
No environment variables, new dependencies or remote services proposed.

## Real controls, acceptance and bounded verification

Expose actual canister selection, empty/occupied bulk status, fit cost, physical
socket placement and recover/remove actions through hosted commands. Show shell ID,
actual mol / absolute kPa / 2 L capacity / condition / 110 kPa limit, chamber and
exterior pressures, closed/open/connection state, pending receipt and exact blocker.
State passive-equilibrium limits and retained gas clearly. Disable stale/rebound/
disconnected actions until fresh owner observation. Use normal physical inventory
selection and derived preview/collision, not a test-only pressure setter.

Acceptance after design approval:

- Fresh unseeded finite PR149 acquisition/build plus real existing carrier emptying,
  0.2 kg insert payment, real socket placement and unobstructed body/door traversal.
- Real UI fit/connect/open/close, chamber-to-empty-store transfer, finite chamber
  vent, store-to-lower-pressure-chamber return, retained equilibrium and repeated
  diminishing cycles. Compare every volume's summed moles before/after each step.
- Loaded recovery rejection; explicit finite-outlet discharge or truthful retained
  blocker; empty physical recovery/replacement and exact-once plate refund.
- Reservation, capacity, power/tool/reach/hand, foreign owner/session/body, stale
  revisions/epochs, replay/changed intent, failure injection before each commit,
  absolute overrating and closed-valve leak, no healing, unsupported temperature,
  both flow signs, port/door/bypass interlocks and safe-close negative controls.
- Full-world save/reload open/closed/failed/retained states; malformed multi-owner
  restore equality; old worlds, exhausted sources and old canisters receive nothing.
- Existing chamber, room, reinforcement, force, timed-canister, bulk capacity,
  Inventory, observations and emitted-schema/version negatives remain covered.

This commit is design text only: arithmetic/source/diff review applies. Runtime
acceptance remains unverified. After accepted design and implementation, freeze
and push a head, request Coordinator's explicit exclusive exact-head NO-PORT lease
with named stages/time budget. Use AST-extracted versioned Invoke-GodotCheck,
empty preflight inventory, stop on first diagnostic, no edit/retry under lease,
retain logs and report postflight inventory/release. Final Windows/Linux exact-head
CI and schema negatives are required; distinguish PR head from tested merge SHA.
Capture only if material physical/UI uncertainty remains. No successors, media,
publication, deployment, outreach, spending or merge before Coordinator acceptance.
