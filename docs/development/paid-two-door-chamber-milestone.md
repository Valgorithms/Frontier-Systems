# Paid room reinforcement prerequisite and subsequent two-door target

Status: **Coordinator accepted bounded reinforcement prerequisite; implementation awaiting exact-head runtime verification**.
Base: `2b0b8ffca77816658a038f3151dc2eaffdd897ed` (merged PR147).
Worker: `01a16a80-e181-7aa2-92ab-5febf57042a3`, isolated managed worktree
`paid-two-door-chamber`, branch `paid-two-door-chamber-design`.
Coordinator `01a1283c-45d6-7e61-bedd-905e8797f03d` owns scope acceptance,
runtime leases and merges. No Godot import, startup or test has run here.

## Outcome and recommended next milestone

The roadmap target is a player-built chamber with two paid owned manual doors,
two recoverable bypasses, finite habitat/chamber/exterior gas and deliberate
sequential operation through the real player controls. The player closes one
side, equalizes the other, checks its pressure/load, opens that door, passes
through and closes it. Neither the controller nor UI moves gas or doors for free.
This is bulk pressure engineering, not survival, breathability or EVA acceptance.

**Recommendation: review a necessary bounded prerequisite first: a paid,
recoverable pressure-boundary reinforcement kit for the existing one-door room.**
It gives a concrete playable outcome: retain a differential that actually blocks
the 1000 N crowbar, deliberately use the existing paid bypass, then regain manual
door operation. It is not a room registry, pipe framework or another diagnostic.
The two-door target below pins the subsequent outcome and prevents this
prerequisite from becoming unbounded foundation work. Do not implement either
full chamber scope in this PR. The Coordinator accepted only the prerequisite.

## Source evidence and independent constraints

At the pinned base:

- `src/core/pressure/constructed_room_pressure.gd`: `assess` requires exactly one
  door; `valid_room` pins `constructed-room.habitat.prototype.v1` and one door ID;
  `validate_links` allows at most one room. Healthy retention is only 0.5 kPa;
  area is 1.71 m2, safety leakage conductance 1 mol/(s*kPa).
- `src/core/pressure/pressure_system.gd`: commissioning proportionally subdivides
  the existing 1000 m3 habitat, copies its temperature and conserves its moles.
  Every constructed-room transfer currently goes to `habitat_main`. The prototype
  exterior is a finite 1,000,000,000 m3 volume initially at 0 kPa; the habitat is
  initially 101.325 kPa and the existing separate airlock chamber is 10 m3 at 0.
- `src/core/access/access_control_system.gd`: manual available force is 1000 N,
  pressure force is abs(delta kPa) * 1000 * effective area. The exact force
  ceiling is 1000/1710 = about 0.584795 kPa, not the existing controller's 2 kPa
  interlock. The existing controller's force/threshold cannot authorize paid doors.
- `src/core/production/paid_door_geometry.gd`: each frame/leaf costs 2 kg plate;
  door swing envelopes require complete paid floor coverage and cannot overlap.
  `constructed_door_opening_topology.gd` already accepts multiple apertures, but
  that diagnostic alone is not commissioning, endpoint or pressure authority.
- `data/production/catalog.v2.json` has exactly 17 kg finite iron ore. Refining
  yields 60% iron / 40% tails. PR147's complete default route consumes it all:
  7.6 kg enclosure + 0.2 kg seal + 0.2 kg bypass + 2 kg crowbar, leaving 0.2 kg
  iron and 6.8 kg tails. It cannot pay even another 2 kg door.

A second unmodified door facing vacuum cannot isolate the habitat: its safety
leak activates above 0.5 kPa even when closed. Command interlocks cannot stop
that passive leakage. Connecting both doors to the same habitat would avoid the
problem but supply no distinct-pressure transit outcome. Rebinding the existing
room to vacuum or increasing its retained threshold silently is unacceptable.

## Proposed prerequisite: reworkable rated boundary kit

New first-party **prototype tuning proposals**, requiring explicit review:

- Separate kit identity/policy `constructed-room.habitat.reinforced.v1`, with a
  4 kg processed-plate bill: 2 kg supplemental door/frame/gasket containment and
  2 kg enclosure reinforcement. These are a deliberately budgeted game recipe,
  not inferred existing hardware specifications or a physical certification.
- Rated differential 110 kPa in either direction while the entire paid kit,
  original seal, envelope and actuator are intact and closed. Retain the 1.71 m2
  area and 1000 N manual force. Never upgrade an unreinforced room or old save.
- At missing/failed kit links stop command admission; preserve all gas. At valid
  damaged/open/overrated boundaries use the existing conservative 1 mol/(s*kPa)
  leak. A closed bypass never suppresses leakage. For each boundary use
  max(leak, open bypass) rather than adding the two paths. No pumps or powered
  override. Damage invalidates the upgraded rating without deleting paid parts.
- Fit only to the current complete own commissioned one-door room, closed and
  intact, with a held usable crowbar, current session/body, reach, revision and
  epoch. Debit plate through the reservation-aware Production spend guard.
- Production owns one immutable recoverable kit receipt; Pressure owns its
  selected validated policy. Access retains actuator integrity/latch/position.
  Installing the kit changes no gas, volume, pose, door geometry or force.
- Recover only after safe door opening and normal decommissioning; retain kit
  hardware while decommissioned and refund exactly once with capacity checks.
  Recommission intact retained hardware explicitly, bypass closed. Block removal
  or rework of supporting seal/door/panels until the kit is safely detached. No
  automatic repair on restore, refit or migration; no new repair system here.

This prerequisite deliberately does not create a second room/door/controller or
an exterior endpoint. Its only source edits would be the paid-kit lifecycle,
rating selection, finite acquisition origin, existing controls and their strict
save/restore/schema/test boundaries.

### Prerequisite default-start budget

Preserve catalog v1/v2 bytes and legacy origins. Proposed new-world catalog v3
adds one distinct reachable **7 kg** iron-ore source, rather than refilling the
existing 7 kg outcrop. New worlds have 24 kg ore + 5 kg ice + 10 kg regolith =
39 kg Production origin. Legacy/missing-Production restores receive no new source
or mass. New source ID, fingerprint, reach mapping and initial mass must be
explicit versioned content; no recipe/yield/energy/tool grants. Catalog v3 needs
normal extraction and source selection in the existing UI, not test-only access.

| Step | Matter | Electrical energy |
| --- | --- | ---: |
| Extract and unload | 24 x 1 kg ore, same starter extractor/canister | 6,000 J |
| Refine | 24 kg ore -> 14.4 kg iron + 9.6 kg tails | 24,000 J |
| Craft plate | 12 x 1 kg iron -> 12 kg plate | 12,000 J |
| Fabricate held crowbar | 2 kg iron -> one real crowbar | 2,000 J |
| Existing complete enclosure | 7.6 kg plate | 0 J |
| Original seal and bypass | 0.2 + 0.2 kg plate | 0 J |
| Reinforcement kit | 4 kg plate | 0 J proposed manual assembly |
| Total | 12 kg installed plate + 2 kg crowbar + 0.4 kg iron + 9.6 kg tails | 44,000 J |

Final energy is 56,000 J from the existing 100,000 J supply; no refill/generation.
The acquisition conserves all 24 kg; untouched ice/regolith account for the other
15 kg. Each extraction fits the existing 2 kg carrier and is unloaded before
the next. Depot mass remains below 100 kg. The existing extractor's 24 successful
uses yield head integrity 999976, drive 999994, frame 1000000 (ppm), all above
the existing 50000 usability floor; no repair or spare tool is required. Proposed
manual kit fitting/recovery uses zero electricity, as existing manual fitting does.

The positive route starts at the actual first-playable composition root, picks
up canister-2, equips extractor-2, extracts all sources through authenticated
commands, refines/crafts/fabricates, builds and fits the kit without stock/gas
seed edits. Preserve the original 17 kg v2 acquisition test separately.

## Full successor target geometry and budget

This section is a bounded target design, **not accepted implementation scope**.
Integer-mm geometry, all same constructing principal/body, q = quarter_turn:

| Part | Pose/bounds | Plate bill |
| --- | --- | ---: |
| North/south walls | [5500,0,-4550], [6500,0,-4550], [5500,0,-3450], [6500,0,-3450], q0 | 4 kg |
| Inner/outer doors | [5050,0,-4000], [6950,0,-4000], q1 | 4 kg |
| Paid floor including both swings | x[4100,7000], z[-4500,-3500], y0 | 2.9 kg |
| Ceiling | x[5100,6900], z[-4500,-3500], y2000 | 1.8 kg |
| Two original seals / two bypasses | 0.2 kg each per part | 0.8 kg |
| Distinct containment kit | 2 kg per door + 2 kg shell | 6 kg proposed |
| Installed total | Chamber interior 1.8 x 1 x 2 m = 3.6 m3 | 19.5 kg |

Both door sweeps occupy z[-4500,-3500]; x[4100,5100] and x[6000,7000]
respectively. They do not overlap. The complete floor covers both; a 900 mm
standing zone between them contains the prototype body footprint. Adjacent wall
panel ends meet exactly and door bands cover the two remaining perimeter sides.
These are source-derived candidate dimensions, pending actual topology, occupancy
and PhysicsServer verification under lease. Do not reuse the shorter one-door
layout: its proposed opposite-door sweeps would overlap by 100 mm.

Full build needs 20 kg crafted plate + 2 kg iron crowbar: minimum whole-batch
37 kg ore -> 22.2 kg iron + 14.8 kg tails. Leftovers: 0.5 kg plate + 0.2 kg iron;
19.5 installed + 2 crowbar + 0.5 plate + 0.2 iron + 14.8 tails = 37 kg.
Extract 9,250 J + refine 37,000 J + plate 20,000 J + crowbar 2,000 J =
68,250 J, leaving 31,750 J. Tool head 999963, drive 999991 with remainder250,
frame1000000; one-batch carrier/depot limits still fit. Manual assembly and gas
exchange cost zero electricity. No fixtures may seed the positive path.

This full target needs **20 kg more finite ore than v2** (52 kg total world
origin), or **13 kg more than the prerequisite v3**. Do not add both grants
twice or promise the prerequisite's 7 kg source funds the full chamber. A later
separate content/version decision must account for those additional 13 kg and
legacy v3 worlds; no auto-grant on upgrade. Existing-kit reuse requires explicit
recovery/repayment of the full two-door bill, never a free second reinforcement.

## Full target authority and operation

Add at most one distinct commissioned two-door chamber record, mutually exclusive
with the existing one-door commissioned room. Do not broaden the legacy room
dictionary/schema to mean two unrelated models. Production owns paid doors,
panels, seals, bypasses, kit bills and reservation/refund receipts; Access owns
both actuator records; Pressure owns the chamber volume, sensor, immutable
endpoint pairing and valve positions. Only the selected same principal/body can
pair two current uncommissioned doors from a complete enclosure. No stealing the
prototype controller's free doors or reusing a door in both chamber models.

Pin inner endpoint `habitat_main`, outer endpoint the existing finite prototype
exterior; a new policy explicitly declares these logical prototype connections.
They are not inferred from coordinates and do not establish a spatial atmosphere
map or player exposure model. Display this mapping in the panel. Commissioning
subdivides the existing habitat into 996.4 + 3.6 m3 with proportional existing
moles and equal temperature. Exterior and existing prototype chamber remain
unchanged; total volume and all-volume gas remain invariant. No added reservoir,
gas source, vacuum reset or infinite sink.

Ordinary operation permits at most one open door or open bypass across the two
sides. To open either bypass require both doors closed and the opposite bypass
closed. To open a door require both bypasses closed, opposite door closed,
healthy paid rated boundary on the opposite side, and the actual Access 1000 N
force test on this side. Use a conservative <=0.5 kPa command interlock as well
as Access validation; that threshold does not increase hardware force. Explicit
close remains available for recovery and still obeys occupancy/force validation;
never trap recovery behind an 'opposite healthy' opening rule.

Use explicit open/close commands, not toggles. Revalidate session, body, held
crowbar, reach, geometry, both sides, Production revision and restore epoch at
apply. Direct low-level Access paths must not bypass chamber interlocks. UI only
queues server commands. Idempotent receipts cannot charge twice or invert valves.
On damaged opposite boundary do not advertise safe isolation: leak physically,
reject new unsafe opening and show the failure; interlocks cannot certify a
broken assembly. Recovery never teleports a body or ignores a blocking occupant.

At each fixed tick, after the existing prototype transfers and before sensors,
process the chamber inner then outer boundary in fixed order. Per side use the
existing equal-temperature solver with max(leak, open bypass) conductance 1.
Open doors are a passive path too. Retain this order on restore. Pair transfer
is capped by equilibrium, nonnegative source moles and 0.001 kPa solver epsilon;
log only bounded counters, including leaked/transferred moles and blocked reasons.
For an isolated pair, P_eq = (P1*V1 + P2*V2)/(V1+V2). No setpoint or refill.

Initial full-target venting transfers roughly 149.7 mol from the 3.6 m3 chamber
to the finite exterior at the existing prototype temperature, not into deletion.
Its initial near-vacuum pressure rises to roughly 3.65e-7 kPa. Return equalization
consumes habitat gas and lowers its pressure by roughly 0.365 kPa on the first
cycle. Exact values must use the runtime's actual constants. Repeated cycles
consume a finite reservoir and cannot claim perpetual restoration to101.325 kPa.
The existing unrelated prototype airlock can also exchange those reservoirs;
validate against current pressures, never assume either endpoint is constant.

## Persistence, UI and acceptance for either selected scope

Introduce explicit new versions only when implementation is accepted. The next
available Production save is v14 and Pressure save v4; observation is v16 / paid
door v5. Preserve v1/v2 catalogs and all currently supported save/observation
decoders. New kit-origin records require exact catalog ID/fingerprint/initial
mass. Old v1-v13 Production and v1-v3 Pressure records keep original absent-kit
and one-door semantics and gas, without grants or a forced upgrade. Missing
Production world migrations remain historical. A later full chamber may require
another explicit version; do not reserve optional fields in legacy schemas.

Use detached Production/Pressure/Access/Inventory validation before any live
assignment, extending the existing prepared owner transaction and whole-world
prevalidation. Validate exact bills, policy, ownership/body, original seal links,
geometry, area/force, unique endpoint/door IDs, gas allocation, sensor and valve
states together. Any malformed half must reject with all owners, receipts and
ticks unchanged. Legacy and upgraded snapshots roundtrip without healing,
refilling or changing finite origin. Open bypass reload resumes physical flow;
closed reload retains healthy pressure. For full scope reject both-open doors,
both-open bypasses, door-plus-bypass states, orphan endpoint/kit and reuse of an
old one-door room ID. New records normalize only through an explicitly tested
version decoder, never permissive schema unions.

Extend the existing collapsed paid-door panel and real hosted action queue.
Prerequisite: exact kit cost, fit/recover, base-versus-rated state, current
pressures, delta/load, valve state, pending receipt and specific block reason.
Full scope additionally needs explicit own inner/outer selection, paired IDs,
three pressures and sequential close/equalize/close-valve/open actions on either
selected door. Pending/stale/rebind states disable actions until fresh authority
observations; no UI-owned sequencing or pressure writes. Source UI wiring is not
proof of usable player controls: exercise actual enqueue/projection/control paths.

Prerequisite positive acceptance: complete 24 kg unseeded acquisition/build,
fit kit at existing equal pressure, use the existing authorized prototype airlock
exchange to lower habitat pressure until this retained room differs by >0.6 kPa
but stays below110 kPa; close that exchange. Verify closed kit retains gas while
the unchanged crowbar rejects with `actuator_force_exceeded`. Open paid bypass,
conserve all-volume moles, approach finite pair equilibrium, close bypass and
successfully operate the same real crowbar/door. Decommission/recover/refit and
reload at both open/closed valve states without mass/energy/gas grants.

Full positive acceptance: independently acquire its full37kg budget, build both
doors with genuine occupancy/support, pair/commission, vent through the outer
bypass with inner fully isolated, close bypass/open outer, close outer, refill
from finite habitat through inner bypass, close bypass/open inner. Prove the
habitat remains isolated while venting, both cycle directions, conservation and
finite pressure loss over repeated cycles. Verify real player command/UI paths
and actual body contact/clearance. No seeded resources or rewritten gas snapshot
may establish either positive route.

Negative controls: unchanged old0.5kPa leak/rating; new overrated/damaged leak;
1000N rejection in both pressure signs; closed valve not suppressing leakage;
insufficient/reserved stock; full carrier/depot/refund capacity; power/tool/reach;
wrong owner/body/session/epoch/revision; duplicate request/changed intent; false
kit/area/rating/endpoint/bill; unsupported or overlapping swings; occupied close;
partly depleted/exhausted sources on reload; legacy no-grant; malformed paired
restore with exact all-owner unchanged state. Retain existing finite bootstrap,
bypass, room, paid-door, snapshot and schema regressions.

## Accepted implementation and verification handoff

The Coordinator accepted the distinct recoverable 4 kg processed-plate kit,
new-world-only 7 kg ore seam (catalog3, 39 kg origin), zero electrical manual
assembly/recovery and explicit first-party 110 kPa prototype game tuning.
The full two-door chamber above remains subsequent design, outside this PR.

Supported assembly condition is the existing Access actuator integrity and
original seal condition only. Geometry, kit identity/bill and original seal links
must also match. There is no independent wall/panel damage model or hidden kit
health. Fitting never writes condition; seal rework/removal requires kit recovery.
Damaged supported hardware loses reinforced retention and leaks through the
existing baseline path. This is game tuning, with no physical certification.

Implementation uses Production save14 / observation16 / paid-door5 and Pressure
save4 with constructed-room2. Old catalogs and pressure policies remain separate;
loading them never adds the new seam, kit, gas, energy or condition. New content
is selected only by fresh playable commissioning. V14 also supports older origins
which later pay their own kit bill; its origin mass remains unchanged.

The new regression acquires 24 kg ore through real pickup/equip and queue paths,
prints 12 kg plate and a 2 kg iron crowbar, then pays 7.6 kg geometry, 0.2 kg seal,
0.2 kg bypass and 4 kg kit. Leftovers are 0.4 kg iron and 9.6 kg tails, with
5 kg ice and 10 kg regolith untouched. Extraction/refining/printing/fabrication
spends 44,000 J and leaves 56,000 J. Door UI commands fit the kit, demonstrate
>0.6 kPa retention and 1000 N rejection, open/close passive bypass, then operate
the same crowbar. Tests include refit/recovery, open/closed whole-world reload,
both differential signs, overrating, supported damage/no-heal and malformed
three-owner restore. Existing catalog2 acquisition and bypass regressions remain
separate. Tests are authored; execution is not yet acceptance evidence.

Before any local Godot operation, freeze/push the implementation and obtain an
exclusive Coordinator NO-PORT lease for its exact head. Use approved bounded
scripts, fresh empty process inventory, stop on the first diagnostic, preserve
logs and release the lease. Do not edit or retry under the lease. GitHub CI may
run normally. Final acceptance requires exact-head Windows/Linux CI and accepted
runtime evidence, with synthetic tested revisions recorded separately. Captures
resolve material uncertainty only. Coordinator alone reviews/merges. No deployment
or external publication is authorized.
