# Mining, chemicals and crafting runtime

## Playable local loop

Production observation v10 adds `horizontal_panels` with at most 64 own safe
surface descriptors, a voluntary-capability hint and aggregate geometric closure
status/revision. The authenticated host filters descriptors by principal. Aggregate
closure uses all canonical walls/panels and cannot be reconstructed from the
partial own-only descriptor list. No foreign IDs, principals, payment receipts or
grants enter this projection. V7..10 observations remain readable; a connection
that has accepted v11 rejects a downgrade. Persistence uses strict save v10.

The first-playable machinery drawer includes collapsed floor/ceiling controls.
X/Z minima and width/depth use integer millimetres on the 50 mm grid; each side
is 50..1000 mm. Floor Y=0 and ceiling Y=2000 are fixed. The panel shows the
area-derived 1 mg plate/mm2 cost and shared plate stock, stable own selection,
deliberate placement/removal and host result. Every action queues the existing
`panel_build`/`panel_remove` command with current revision; the host rechecks
scope, voluntary capability, reach, ownership, stock and refund capacity. Hints
and previews grant nothing. Pending, stale, malformed, scope-changed or
disconnected state clears actionable previews; an acknowledgement requires a
fresh observation. Removed selections never switch to another sheet.

Original procedural sheet meshes and a transparent candidate ghost are display
geometry. Area3D picking permits selection without StaticBody collision or
standing support. Closure status establishes geometry only, never sealing,
pressure, load capacity, collision or deployment. See the
[controls milestone](../development/horizontal-panel-controls-milestone.md).

The desktop client exposes **Extract, store, refine and recycle** inside the existing inventory overlay. This follows the [community-selected first playable milestone](../development/first-playable-milestone.md) and the [environmental extraction route](environmental-extraction.md). No external services or proprietary art are required. The procedural habitat shows deposit depletion and constructed wall segments.

1. Select an owned canister and 1000 g transfer mass. Extract from the iron ore source twice, then unload both kilograms into workstation storage. Extraction requires source reach; unloading requires workstation reach.
2. Run `refine.iron` twice. Each kilogram of ore yields 600 g iron and 400 g retained tailings.
3. Run `craft.plate`, consuming 1 kg iron. Build a wall segment with the printed plate.
4. Deconstruct the wall to recover the plate. Run `salvage.plate` to recover its iron and print again.
5. Extract ice into an empty canister, transport/unload it and run `refine.ice` to produce water. Dispense a selected mass into the shared vessel, then return it to storage.
6. Extract regolith into an empty canister, unload it and run `refine.regolith` to separate salts, silicate and retained tailings. Combine 900 g water and 100 g salts with `chemical.nutrients`.
7. Alternatively run `chemical.electrolysis` to separate water into stored hydrogen and oxygen. Dispense small gas quantities while respecting vessel pressure.

The loop is executable runtime code, with command buttons and durable snapshot records. It is a finite shared workstation prototype: the bulk depot and vessel belong to production, separate from wearable/handheld inventory. Payload contents now attach to real inventory canisters through the [portable resource bridge](portable-resource-carriers.md); the same mass is never also minted as duplicate item stacks. Legacy wall segments remain aggregate blueprint mass records. [Physical floor panels](../development/spatial-wall-milestone.md) add owned-plate placement/removal, static collision and server movement validation, with production v7 persistence. Deployed machinery uses [server-owned placement envelopes](../development/machine-placement-authority-milestone.md) for deployment and expanding fits, with deliberate trusted-checkpoint compatibility. Neither path forms atmospheric enclosures; pressure topology remains future work.

## Paid manual doors

Production save v10 adds a bounded registry of paid manual door installations;
v1-v9 records migrate to an empty registry. Production observation v11 adds the
own-only `paid_doors` v1 projection, current body control epoch and operation hint.
The machinery drawer submits build/open/close/remove intents with the current
Production revision and epoch. Production owns the fixed 2 kg processed plate
bill and installation identity. Access owns the single commissioned manual leaf;
Inventory and Tools resolve the actual held usable crowbar. No controller,
fixture spares, pressure ports or sealing capability are commissioned.

Construction requires complete paid floor coverage under the 1 m square swing,
clear installations and mapped canonical body/storage/grip occupancy. Removing
support or operating into an occupied swing rejects before either owner changes.
Closed leaves and permanent frames block canonical motion and derived physical
contact; the open leaf has a distinct hinged box. Disassembly requires a closed,
unoccupied assembly with no added hardware or active bypass work and refunds the
trusted bill once, subject to capacity and existing reservation claims.

A one-use prepared Access change compares the affected live reference and its
complete original record before committing. Production assigns its validated
candidate immediately after that final fallible step. Whole-world restore uses a
synchronous paired Production/Access scope: pure-decode and cross-link validation
precede mutation, nesting rejects, and independent owner restores must agree with
the other live owner. No session identifier is persisted in the installation.
See [the door milestone](../development/paid-door-construction-milestone.md) for
geometry, failure bounds and verification status. These doors do not contribute
to room closure or pressure topology.

## Ownership and commands

The machinery workbench assembly group includes a collapsed **Timed canister**
control. Start reserves one 1 kg iron bill; Pause, Resume, Cancel and Complete
submit the existing `timed-canister-intent-v1` operations through
`ProductionDevelopmentCommand`. The UI permits one unfinished own job at a time
and disables actions while a request is pending or current telemetry is absent.
It stays inside the existing scrollable contextual panel; it adds no camera overlay.

Production observation v9 adds `timed_canister` (see
`timed-canister-observation-v1.schema.json`). It contains the current reservation
revision and own control epoch, advisory `can_operate` / `can_start`, and at most
16 jobs filtered by authenticated principal, current body, world and region.
Each job exposes only state and completed work ticks. Distant own jobs remain
readable while operations require current workbench capability. A pinned timed
blueprint fingerprint lets clients recognize revision-2 physical structures while
the existing revision-1 factory catalog remains unchanged. Observations expose no
other actor bindings, receipt maps, grants, output identities or writable work ticks.
These fields are read-only telemetry, never command authorization.

The host still binds session identity and scope, then checks current reach,
consciousness, available hand, both revisions and control epoch at fixed-tick
ingress, including retained retries. Ticks and physical outputs remain server
owned. Resume rebinds changed control only through canonical policy. The projection
and controls reject regressing revisions; remote clients also reject regressing
ticks/epochs and changing timed definition identity. Legacy v7/v8 observations
remain readable but provide no timed controls. Reconnect requires fresh host
observation; the UI recovers own retained jobs without creating authenticated grants.

Persistence remains production v8, including bounded retained request identities
and paused-on-restore work. The existing atomic inventory factory and common
finite-stock claim guard are unchanged. Runtime advancement stays at production
priority 300 and the pinned 60 Hz timebase; ticks do no UI or service I/O.
Projection creation is bounded by the existing 16-job ledger. Existing profiling
counters remain available without changing simulation behavior. Stale, incapable,
out-of-reach or malformed intents fail without spending the claimed bill or
creating output. Completion still requires printer power, energy and capacity.

`ProductionSimulationSystem` owns the deposit masses, bulk depot, shared vessel contents, constructed wall mass, finite battery energy, station power flags, one reserved batch and at most 64 request receipts. It runs after health and inventory, at priority 300. The catalog is read once during startup; ticks never perform file or service I/O.

`ProductionDevelopmentCommand` uses the existing fixed-tick command queue. World and region scope are checked before ingress. Inventory resolves the server-bound actor, requires a conscious body, an available unreserved hand and logical reach within 1.5 m of the fixture workstation at `[0,0,0]` mm. Mounted drill and station tools provide processing capabilities; there is no handheld mining tool check. A machine batch continues autonomously if its operator subsequently moves away or becomes unconscious.

An operation commits one whole candidate state or rejects without mutation. The client supplies IDs and quantities, never outputs/yields or material compositions. Commands require the current production revision. Concurrent actors compete on that revision; a stale command fails. Identical retained requests return their receipt without repeating the operation; changed intent under the same retained ID rejects. Evicted old requests remain subject to current revision validation.

Closed operations:

| Operation | Fields in addition to `expected_revision` | Effect |
| --- | --- | --- |
| `extract` | `deposit_id`, `carrier_id`, `amount_milligrams` | Transfer finite environmental matter directly into an owned canister at source reach |
| `mine` | `deposit_id` | Reserve 1 kg from a finite deposit and start mounted drilling |
| `process` | `recipe_id` | Reserve exact recipe inputs and start refining, chemistry, printing or recycling |
| `cancel` | none | Recover reserved original inputs; spent energy remains spent |
| `dispense` / `return` | `material`, `amount_milligrams` | Transfer chemical mass between depot and vessel |
| `load_cargo` / `unload_cargo` | `carrier_id`, `material`, `amount_milligrams` | Transfer resource mass to/from an owned physical canister |
| `build` / `deconstruct` | none | Transfer one 1 kg plate to/from a wall segment |
| `power` | `station`, `enabled` | Change a registered station's power flag |

Every payload has exact fields; unknown operations, extra fields, negative/fractional quantities, missing feedstock, exhausted deposits, overcapacity storage and unpowered stations reject. Read-only workstation observations still require identity and reach, but do not grant voluntary actions to an unconscious body.

## Material and energy conservation

All mass is integer milligrams. The default closed fixture starts with 10 kg iron ore, 5 kg ice and 10 kg regolith, with empty storage, vessel and structures. Mining transfers matter from the deposit into a reserved batch, then into bulk storage. Processing reserves feedstock, then atomically replaces it with equal total output mass. Waste remains explicit tailings; it never vanishes. Cancellation recovers input chemistry, not unearned outputs.

Snapshots validate that deposits + bulk stock + vessel + constructed wall mass + reserved batch mass + portable payload mass total exactly the origin budget: historical catalog1 worlds retain 25 kg; new playable catalog2 worlds retain 32 kg (see below). A 100 kg bulk capacity includes reserved future outputs, and a 2 kg vessel capacity bounds all contained matter. Receivers are checked before transfer. The vessel may contain several registered chemicals, each retained separately; dispensing cannot create matter or change its identity.

The fixture battery starts with 100,000 J. Batch energy is charged atomically at acceptance; insufficient energy rejects. Turning off the active station pauses progress without losing its reserved materials. Power-on resumes it. Switching power on does not refill the battery. Power generation and real electrical network integration are future work. Dispensing and construction currently use powered fixtures without a quantified energy debit.

## Vessel pressure

The shared sealed vessel has 2 L internal volume, a fixed 293.15 K temperature and a 1000 kPa absolute pressure limit. Liquid displacement uses prototype water-like density; hydrogen and oxygen use ideal-gas molar quantities. Gas pressure derives from mass and remaining headspace; it is not separately saved. A transfer exceeding capacity or pressure rejects before commit. For example, 100 g oxygen exceeds this vessel's pressure limit; choose a smaller quantity. Filled liquids leave less gas headspace.

This vessel is not a breathing tank and has no atmospheric connection, rupture, leaks, gas reactions, explosive ignition, phase changes or heat exchange. Bulk output gas is stored as abstract sealed stock. Electrolysis and nutrient recipes are mass-balanced gameplay approximations, not a full stoichiometric, thermodynamic or medical chemistry simulation. No SS13 chemistry code or content was copied.

## Cadence, persistence and bounds

The fixed runner advances one active batch by one tick when powered. Recipe durations range from 60 to 180 ticks in the defaults. At 60 Hz these are 1–3 seconds; 72/90 Hz currently shorten wall-clock durations. Saved timebase must match the process, and mid-session rate changes reject advancement/commands. Explicit retuning or migration is required for production rate changes.

The v2 snapshot adds portable cargo records to the original v1 canonical quantities, power, reserved input/output identities, remaining ticks and retained request receipts. Snapshot restore validates exact registries, quantity bounds, conserved total mass, pressure, recipe correspondence, ordered receipt revisions/ticks and supported timebase. A SHA-256 catalog fingerprint prevents silently loading a batch against edited recipe definitions. The runner validates all systems before restoring any.

Legacy worlds without `systems.production` receive the initial finite fixture at their saved tick. This is a one-time schema migration, not a respawn operation; new snapshots include depleted resources. A malformed present production record fails rather than resetting. The cooperative scene now adds authenticated sessions and worker-thread checkpoints; see [adapter contracts](first-playable-adapters.md). Database/journal storage remains future work.

Work is bounded by 32 material types, 16 deposits, 32 recipes, seven stations, one batch and 64 retained receipts. Profiling exposes active batches, stored/vessel mass, remaining energy and receipt count. Desktop observations refresh at 10 Hz and hold detached values only. The HUD clears when the world closes; themes and section visibility continue to work.

## Verification state and remaining integration

Windows cooperative and graphical route checks now pass. See [acceptance evidence](../development/first-playable-acceptance.md) for coverage and remaining unverified chemistry cases.

Remaining broader gameplay includes carrier crafting and detailed equipment damage, freeform terrain excavation/fill, spatial blueprint placement, power generation/network integration, chemistry effects on living bodies, atmospheric pipe connections, arbitrary modular construction and wider multiplayer distribution. The first playable supplies the bounded cooperative workstation loop; those broader systems remain staged.


Command revisions advance on accepted commands and batch output commits. Countdown-only progress changes last_tick and remaining_ticks without changing state_revision, so a remote pause/cancel intent can use the latest published transaction revision. Completion still invalidates competing commands. Cancellation returns reserved input mass; spent energy is not refunded.

Production snapshot validation rejects non-object machinery records with a structured failure before copying them. A rejected startup restore preserves all live system state. Checkpoint SHA256 validation remains a separate earlier guard; this domain validation also protects callers of the direct world restore API.

## Complete paid panel geometry boundary

`ProductionSimulationSystem.paid_panel_collision_descriptors(context,
expected_revision)` is a synchronous server-internal read of all validated paid
floor and ceiling records, including other builders' geometry. It differs from
the own-only UI projection and exposes no principal or material details. The
detached integer-mm boxes are not physics bodies or reusable authority; restore
may repeat a revision, and transport ingress owns session revocation. See the
[collision boundary contract](../development/paid-panel-collision-boundary-milestone.md)
for geometry, coordinates, provenance and the deferred scene lifecycle gates.

## Paid manual-door gasket lifecycle

Production save v11 retains an optional installed prototype metal gasket record
on each paid door: stable install-request identity, pinned blueprint/revision and
200,000mg processed plate. Earlier saves migrate to absent seals; migration and
restore never heal Access condition. Mass is retained even when condition reaches0.
Production owns provenance/material, Access owns condition, and Inventory/Tools
resolve the real usable held crowbar and current controlled body. Install/remove
use the existing detached candidate and single-device compare-and-swap transaction,
with current session/epoch/revision, owner, reach, closed usable released manual
hardware, foreign-work, claim and capacity checks before commit.

Removing a gasket recovers its exact retained plate once. Refitting deliberately
reworks/repairs this prototype gasket to condition1 using the crowbar at zero net
material cost; it preserves all other hardware damage. No tick wear or permanent
gasket damage is claimed. Remove the gasket before disassembling its door.
Observation v12 carries paid-door v2 installation/condition fields; legacy v11
observations still decode. The controls expose fitting/reworking and recovery.

No pressure port, area, force, room, gas connection or airtightness is granted.
PR142 topology always retains its unsealed-opening semantics, including fitted
or failed gaskets and either leaf position. See the
[design and acceptance checkpoint](../development/paid-door-seal-lifecycle-milestone.md).


## Finite playable ore commissioning

The shared playable-world factory enables `new_world_ore_outcrop_enabled` before
WorldRuntime initializes Production. Catalog v2 adds only the separately selected
7 kg `deposit.iron.outcrop`, sharing the original iron reach anchor at
`[-3000, 0, -1000]` mm. Existing source content, recipes, yields, energy and tools
are unchanged. The source depletes through the same fixed-tick transaction paths
and has no refill path. Inventory owns pickup/equip/reach/carrier authorization;
Tools owns completed-work wear; Production owns source, payload and refined mass.
Existing bounded profiling counters and receipt bounds apply.

Persistence v12/catalog2 pins v2's exact fingerprint and four source keys with
32 kg closed conservation. Historical v1–v11 snapshots retain catalog1/v1
fingerprint, three source keys and 25 kg; missing historical Production also gets
only that original budget. Restore normalizes old records to v11 and never adds
the outcrop. Unknown identities, shapes or mass reject before owner mutation.
Observation v14/catalog2 and the existing player source selectors expose the
outcrop; historical observation v13/catalog1 remains accepted. No environment
variable or external service is added.

The [finite acquisition contract](../development/finite-bootstrap-acquisition-milestone.md)
records the exact 17 kg acquisition route, 31,250 J cost and remaining material.
Its regression starts with the actual playable composition factory, uses real
pickup/equip and command ingress, and commissions the existing enclosure through
paid construction and seal commands without seeded Production stock.

## Paid manual room equalization

The [manual bypass contract](../development/commissioned-room-equalization-milestone.md)
adds an optional 200,000 mg processed-plate hand valve on a commissioned paid
doorframe. It spends PR146's remaining plate, consumes no electrical energy,
starts closed and exchanges only existing gas with the finite surrounding habitat.
Opening it intentionally reduces a subthreshold differential; above the existing
0.5 kPa retention limit the same safety leakage remains in effect at the same
rate. Closing the valve cannot suppress boundary leakage. No pump, pressure
setpoint, new source, species mixture, breathing guarantee or generic network
is introduced. Door area, 1000 N manual force and 1000 m3 subdivision stay unchanged.

Production owns the pinned blueprint, recoverable part and mass ledger; Pressure
owns its commissioned open/closed state and applies one bounded conservative
pair transfer each fixed tick before sensors. Access remains authoritative for
the door. Commands use the existing authenticated door session, exact revision,
control epoch, real crowbar, owner/body and reach checks. The detached prepared
transaction and whole-world restore validate all three owners before assignment;
the abstract `PressureRoomOwner` prevents concrete dependency cycles.

Production v13 and Pressure v3 persist paid parts and commissioned valve state;
legacy absent-valve records retain v11/v12 and v2 without grants. Decommission
requires a closed valve and retains its paid part; recommission starts it closed.
Recover the part after decommissioning before removing the door, refunding its
exact plate once. Observation v15 / paid-door v4 expose own valve status; the
collapsed manual-door controls display pressures, differential and force load.
No new configuration variable, service, asset or external dependency is required.


## Paid reinforced prototype boundary

Fresh playable worlds now select catalog3: historical 25 kg origin plus the
separate 7 kg outcrop and separate 7 kg reinforcement seam, for 39 kg total
(24 kg ore). Catalog1 and catalog2 saves retain their original deposits and
25/32 kg conservation; restore never grants new content. The actual source
pickers expose the new reachable seam at the existing ore worksite.

A commissioned one-door room can pay 4 kg processed plate for a recoverable
`room.reinforcement.prototype` kit linked to its original seal. Production owns
identity/bill and refunds, Access retains actuator and seal condition, Pressure
owns the explicit reinforced room policy. Intact closed manual hardware retains
up to 110 kPa under first-party prototype game tuning; unsupported condition
uses the existing leak path. No independent wall/panel damage detection or
physical certification is claimed. The original 0.5 kPa policy, 1.71 m2 area,
1000 N crowbar and max(leak, valve) conductance1 remain unchanged.

Fit/recover require the actual crowbar, ownership/body, reach, revision/epoch,
clear swing and available unreserved stock/capacity. Fitting requires an intact
closed commissioned room. Recovery requires safe open decommissioning first.
Manual assembly/recovery cost zero electricity and never modify condition.
Seal rework/removal is blocked while a kit remains linked. Production save14,
Pressure save4/room2, observation16/paid-door5 encode this without upgrading
legacy records. No service or external dependency is added. The
[accepted prerequisite](../development/paid-two-door-chamber-milestone.md)
records the finite 44,000 J route and the separately scoped subsequent chamber.

Local UI request IDs include a random runtime-session prefix and a monotonic
sequence. Saved production receipts retain their original IDs for idempotent
retry; creating a runtime to reload a snapshot cannot restart those identities.
The prefix is transport identity only and grants no simulation authority.

The default first-playable factory now selects catalog4 explicitly. Its distinct
15 kg chamber iron seam extends the previous 24 kg ore origin to 39 kg; unchanged
ice/regolith make 54 kg total origin. Catalog1/2/3 saves and explicit old factory
modes receive no seam grant. The complete two-door route prints 21 kg plate,
installs 20.4 kg, fabricates the 2 kg iron crowbar and spends 71,750 J. It leaves
0.6 kg plate, 0.4 kg iron, 15.6 kg tailings and 28,250 J.

`PaidChamber` owns synchronous pair validation and detached transaction planning;
Production owns its 6 kg paid kit and geometry. Access owns both original sealed
manual actuators. PreparedDoorChange validates both device comparisons before
the first write. Pressure owns a 3.6 m3 finite allocation split from habitat_main,
its sensor and two manual valve states. Each simulation tick exchanges inner
then outer with finite habitat_main/exterior_reservoir at conductance1, using
one path when leakage and an open valve coincide. This is logical prototype
pressure service, with no spatial atmosphere or EVA capability claim.

Opening either boundary requires its own valve closed and the opposite boundary
closed, intact and valve closed. Closing retains only its own force/occupancy
guards so an unsafe opposite cannot prevent isolation. Both pressure signs use
the unchanged 1000 N crowbar limit over 1.71 m2. Closed intact kit boundaries
retain up to 110 kPa; seal/actuator damage or overrating leaks even with valves
closed. No extra health field or automatic repair is introduced. Decommissioning
requires both boundaries force-safe and both valves closed; ordinary vacuum
cycling does not supply this precondition. Recovery/refit preserves original
seals, actuator damage and finite gas without refill.

Production15/observation17/paid-door6 and Pressure5/chamber1 persist the explicit
pair, bills, endpoints, geometry and sensor/volume links. Whole-world restore
validates detached Production/Pressure/Access/Inventory candidates before any
owner assignment; half pairs, orphan links and incompatible open states reject.
The collapsed paid-door controls show the pair, three pressures, opposite state,
valves and force load, and enqueue authenticated commands with current revision
and epoch. Rejections retain owner state and expose the host reason. Existing
bounded simulation counters remain available; no per-frame diagnostic tracing
or external service is added. See the
[chamber milestone](../development/paid-chamber-sequential-interlocks-milestone.md)
for pinned geometry, accepted physical corrections and verification scope.
