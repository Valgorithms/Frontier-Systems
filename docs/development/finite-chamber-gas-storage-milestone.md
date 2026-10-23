# Bounded powered chamber gas recovery: revised design

Status: revised outcome/budget/power binding accepted by Coordinator at
`05e79b6a0c53b6f6b97fdec815c3da04def50141`; implementation amendment below awaits
separate pinned acceptance. No runtime/schema
implementation or Godot execution authorized. Revised on 2026-10-23 after the
Coordinator declined the [two-litre receiver](deferred-two-litre-chamber-storage-design.md).
Prototype shell reuse remains UNAPPROVED and is unnecessary here.
Base: `db74161ab66b38365b9fd76b48de18480a98c036` (PR149).
Owner chat: `01a16ad6-6e04-7503-8e5c-f9377e9fb5cd`; Coordinator:
`01a1283c-45d6-7e61-bedd-905e8797f03d`. Retain draft PR150 and descriptive
branch/worktree `finite-chamber-gas-storage`; no successor or branch rename.

## Observable outcome and source decision

Fit one paid fixed pump/interface to the existing chamber, close both doors and
bypasses, then deliberately recover a bounded amount of chamber gas directly
into the finite existing habitat using real controls and finite electricity.
The fresh finite acquisition route should recover 20% of the initial chamber
gas before stopping, retaining every remaining mole in the chamber. The player
then uses the existing manual bypass/force-safe door sequence. This reduces gas
lost on one outward cycle; it does not promise vacuum evacuation, lossless
cycles, breathing, portable gas, powered door movement or free subsequent energy.

The roadmap's atmosphere-owner adapter dependency remains appropriate, but a
receiver is not needed for this outcome. Pressure remains sole owner of all gas.
No new pressure volumes, shell conversion, species inference, inventory gas mass,
general pump/network framework, pipes, suits, ships, thermal simulation or release.

Reviewed at the base:

| Source | Finding |
| --- | --- |
| `src/core/production/production_simulation_system.gd`, `initial_record`, `_decode`, `apply_local` | Production owns the existing integer 100000 J bank, powered station flags, material stock, receipts and revisions. Save validates energy in [0,100000]. Existing spending is finite; do not introduce recharge |
| Same file, `simulate_tick`, `_simulate_machinery` | Machinery buffers live separately inside Production. Solar generation is explicit; it does not refill the workbench bank |
| `src/core/machinery/machinery_workshop.gd`, `draw` | 20000 J per machine buffer, 1000 W generation and shared cable budgets. `draw` mutates workshop candidates and has no pump endpoint/Pressure transaction; do not borrow this path or count solar energy twice |
| `src/core/access/prepared_door_change.gd`, `commit`; Production `_apply_door` | Existing Access/Pressure prevalidation/CAS then non-yielding writes followed by Production assignment provides a transaction pattern, not an existing pump-energy API |
| `src/core/pressure/pressure_system.gd`, `install_prepared_room_state`, `_step_paid_chamber` | Pressure owns finite bulk-mole volumes, ordered passive flows, sensors, chamber links and decoded candidate installation |
| `src/core/simulation/simulation_runner.gd`, `_system_order`; `SimulationSystem`; Production `_init` | Pressure defaults to priority0; Production is priority300, after pressure/sensors. Preserve that order rather than relying on child insertion order |
| `src/core/pressure/pressure_flow_solver.gd` | Passive solver cannot transfer uphill; pump needs a separate bounded work-paid planner, never a negative conductance or free use of `_step_transfer` |
| `src/core/runtime/world_runtime.gd`, `restore_world_snapshot` | Detached mass/link validation surrounds whole-runner restore; extend common candidate validation before any owner writes |
| `docs/development/paid-chamber-sequential-interlocks-milestone.md` | Actual fresh route spends 71750 J from 100000 J and leaves 0.6 kg plate / 0.4 kg iron after 39 kg ore |

**Prerequisite:** there is no existing atomic gas-transfer/energy-debit API.
Accept a narrow prepared Production/Pressure transaction before pump behavior,
or stop at this prerequisite. Do not debit energy after Pressure mutation, call
live `MachineryWorkshop.draw`, compensate via restore, or claim existing APIs
already make the operation atomic. This amendment must be reviewed before code.

## Work model, bounds and finite acquisition

Use the current equal-temperature ideal-gas model: bulk mol, m3, K, absolute kPa,
joules, watts and simulation seconds. No heat/species changes. Reversible
isothermal compression requires `dn * R * T * ln(Pout/Pin)` for fixed endpoint
pressures. The [USPAS Cryogenic Engineering lecture, slides 16-17](https://uspas.fnal.gov/materials/21onlineSBU/Cryo/5%20-%20Thermodynamics%20for%20Cryogenics.pdf)
derives this minimum-work relation and explains isothermal efficiency. Our
finite-volume endpoint bound and tuning below are independent project proposals,
not performance data for a real pump.

For a proposed batch q from chamber C into habitat H, derive candidate endpoint
pressures from `nC-q` and `nH+q`. Reject q <= 0, q >= nC, invalid/nonfinite
derived states, unequal temperatures or unsupported endpoints. Charge:

```
ratio_end = max(1, PH_after / PC_after)
work_bound_J = q * R * T * ln(ratio_end)
electrical_J = ceil(work_bound_J / 0.35) + 1
```

The ratio rises throughout this fixed-volume transfer, so the endpoint ratio
upper-bounds reversible work across the entire batch, rather than undercharging
using its initial pressure. Proposed 35% isothermal efficiency is conservative
prototype tuning, not certification. The extra 1 J per successful batch covers
bounded drive overhead even at equal/downhill pressures. Downhill pumping earns
no energy credit; stopped/no-flow states consume no power. Isothermal heat
rejection to an unmodeled environment is an explicit approximation, not stored
thermal energy, electricity regeneration or gas heating.

One batch of at most 0.1 mol per 60 simulation ticks at 60 Hz (0.1 mol/s);
maximum 250 J per batch / 250 W average over its one-second interval. No burst
catch-up after pause/restore. Reject a batch whose conservative price exceeds
250 J, whose destination exceeds 110 kPa absolute, whose pressure ratio exceeds
16, or whose source would fall below 1 kPa absolute. Do not truncate the price,
silently shrink a batch to match electricity or borrow future energy. The final
batch may be smaller solely to hit the user-selected fixed 20% recovery budget.
No epsilon-emptying, clamping of moles, target-pressure write or residual deletion.

Proposed assembly bill: 400000 mg processed plate housing/interface plus
200000 mg refined iron drive; manual assembly with usable held crowbar costs
1000 J from the existing Production bank. Prototype material/device tuning,
without adding materials, ore, catalog versions, stock, motor items or starter
equipment. Actual pump provenance records both materials and energy spent;
recover its intact physical assembly rather than cloning a factory fixture.
Manual recover/refit costs zero additional energy but preserves condition and
does not refund assembly energy. Destructive salvage returns original materials
once, never electricity; rebuilding then costs 1000 J again.

Finite matter after construction: chamber 20.4 kg + crowbar 2 kg + pump 0.6 kg
+ plate 0.2 kg + iron 0.2 kg + tails 15.6 kg = 39 kg acquired ore. Existing
unacquired ice/regolith and starter ledgers remain unchanged. Pump uses no shell.
Assembly leaves 27250 J for all subsequent work, not a dedicated free reserve.

Independent source-model calculation at initial 101.325 kPa / 293.15 K,
3.6 m3 chamber and 996.4 m3 habitat, with the unrelated prototype valves closed:

| Metric | Proposed 20% recovery |
| --- | ---: |
| Starting chamber gas | 149.65630889 mol |
| Gas returned to habitat | 29.93126178 mol |
| Batches / ideal duration | 300 / 300 seconds |
| Endpoint-bound electricity including ceil and 1 J per batch | 22993 J |
| Largest batch charge | 157 J, below 250 J limit |
| Final chamber / habitat absolute pressure | 81.060 / 101.39821758 kPa |
| Total route + pump assembly + recovery | 95743 J |
| Remaining bank | 4257 J |

The integrated reversible minimum for the same finite endpoints is about
7863.4934 J. At 35% efficiency this already requires about 22467 J; the 22993 J
charged batch sum is conservatively higher, including endpoint bounds/rounding.
PowerShell and independent JavaScript arithmetic agree on all table totals.

This is arithmetic evidence, not runtime or physical acceptance. Other work or
reservoir changes can prevent the target; admission/step checks use actual state.
Remaining 80% is explicitly retained until the player opens the existing outer
bypass, conserving gas into exterior. The pump cannot make the outer door safe
by itself. Repeated recovery can exhaust the finite bank and must stop honestly.
90% recovery would cost about 702335 J even without respecting the 250 J batch
cap; it is not achievable from this bank. No hidden source or easier-work formula.
Solar-powered deeper recovery needs its own paid placement/wiring/atomic-power
design; it is not silently included here.

## Placement, commands and interlocks

One fixed assembly bound to exact paid-chamber ID, `habitat_main`, owner/body,
world/region and existing paid geometry. Use a bounded nonblocking mount at the
inner chamber interface with actual 3D pump silhouette, support/contact and
reachable handle. Pin final coordinates against the actual sweeps and 600 mm
body path in the implementation amendment; actual physical tests must verify
the chosen mount rather than treating a UI anchor as placement acceptance.
Power connection is an explicit fixed logical interface to the existing
Production workbench bank, using `powered.construction`; no spatial electrical
grid, cable, solar-feed or realistic wiring claim. Coordinator must accept this
bounded fixture power binding or require a paid grid prerequisite instead.

Proposed host commands: build/place assembly, start recovery, stop, recover,
refit, salvage. Start sets an immutable job target of exactly 20% of observed
current chamber gas and a maximum permitted job electricity budget, never a
target pressure. It captures current owner/body/control epoch and fixed links.
Only one job/assembly; no direct user q, efficiency, rating or endpoint values.
Start and state-changing commands require authenticated session, principal,
body, revisions/restore epoch, current reach, construction capability and actual
held usable crowbar. Per-step owner/session/reach/tool checks mirror existing
bound finite jobs; losing any pauses before gas/energy writes. Resume is explicit
under fresh authorization, no saved session credential or automatic reconnect.
Receipts bind exact intent; changed-intent replays reject, same request is once.

Both doors/bypasses closed and intact before start and each transfer. Running
job blocks both door/bypass openings, chamber decommission and supporting-part/
kit recovery. Stopping always isolates the pump's normally closed interface;
safe closure must remain possible with damaged opposite hardware. No reverse
pump path, no automatic vent and no free bypass flow through stopped hardware.
Existing Access force checks, 1000 N / 1.71 m2, original 0.5 kPa policy, chamber
retention/leak behavior and collision/occupancy guards remain authoritative.
Supported chamber damage pauses recovery and existing leaks remain active;
the pump does not seal a failed boundary. No new damage/repair simulation.

Physical recovery requires stopped job and isolated interface, valid paid mount,
supported inventory destination/capacity and no occupant/sweep conflict. Preserve
assembly ID, condition and exact material receipt; no gas resides in the pump,
and no volume disappears when removed. Failed device state, if introduced by
existing supported integrity semantics, must disable flow and remain retained;
refitting/reloading cannot heal it. Do not invent an unsupported wear tick.

## Prepared transaction and save prerequisite

Add only a narrow server-owned prepared operation: Pressure plans new C/H moles,
retaining all other volumes; Production plans energy debit, job progress and
bounded counters/receipt. Stage and validate detached records against current
Access/Inventory and active reservation claims. Compare complete required owner
revisions, current energy and source/destination state immediately before commit.
After the last possible failure, assign prepared owner records synchronously
without callback, yield, signal, live restore, decoder or fallible allocation.
No debit without gas and no gas without debit; failure/no-power/capacity/rating/
limit/stale-CAS leaves all canonical state and receipts unchanged.

Admission/start/stop may explicitly change job state. A scheduled stalled batch
does not alter progress, energy, gas, target, revision or receipt; derive the
stall reason in observation. Normal owner tick and independently scheduled flows
can still advance; no-write assertions compare the affected transaction state
at its exact step boundary, not the whole world across time. No per-stall log spam.
Persist last committed batch tick and refuse duplicate or backwards ticks;
Proposed scheduling preserves existing priorities: Pressure0 executes passive
flows and samples sensors, then Production300 advances its tick and existing
canister/machinery work, then attempts one due pump transaction before existing
extraction/recipe early returns. Competing earlier spends win; pump rechecks the
remaining bank. There is no second pump call from Pressure. The existing pressure
sensors sample the result on the next tick (one-tick latency); pump admission and
current UI pressures derive from actual canonical volumes, never stale sensors.
Pin this ordering in the accepted transaction amendment and test restore parity.
Do not execute from UI or service callbacks.

Prepared-operation failure injection and all-owner equality tests are a required
prerequisite to starting powered behavior. Existing `_apply_door` is the pattern;
its Access-specific assumptions must not be disguised as an energy transaction.
If a nonfallible commit boundary cannot be demonstrated, stop and report that
prerequisite instead of compensating writes.

The frozen amendment below pins Production16 / observation18 / paid-door7 and
Pressure6, including reciprocal audit records; pump/job and definition/bill are1.
Preserve all old definitions/catalogs/fingerprints and force semantics. Decode
complete Production/Pressure/Access/Inventory candidates first; validate paid
bill, geometry/mount, ownership, target/accumulated mol, energy spent, tick/cadence,
links, valves and supported conditions before any install. Reject orphan pumps,
false bills, wrong endpoints, duplicate jobs, inconsistent target/receipts, energy
overflow and malformed half-restores with all-owner/tick/epoch equality.

Legacy missing pump means absent pump/job, unchanged energy/gas and no materials,
healing, source, motor or port grant. Save/reload preserves actual gas and energy
without reapplying a batch. Restored jobs are paused pending fresh authorization;
document this intentional session-safety migration rather than silently resuming.
Recovery/salvage respects all active material claims, receiving capacities and
exact-once receipts. No environment variables, dependencies or services.

## Frozen implementation amendment for acceptance

### Exact mount, collision and physical provenance

All coordinates below are canonical millimetres, before the existing display
offset. Pump solid center `[5600,150,-4400]`, size `[200,300,100]`; AABB
x[5500,5700], y[0,300], z[-4450,-4350]. Its footprint must be completely covered
by the paid floor at y0 using the existing exact union support query, and remain
within the accepted chamber interior x[5100,6900], z[-4500,-3500]. No wall health
or wall mount is implied: this is a floor-supported compact prototype interface.
Handle `[5600,900,-4300]` is a noncolliding interaction point, tested against
canonical body center using existing 1500 mm reach. The entire pump solid is
derived from the owned mounted assembly record, not an independent scene owner.

At quarter-turn1 the existing inner door sweep occupies x[4100,5100],
z[-4500,-3500]; outer occupies x[6000,7000], same z band. Pump has 400 mm
separation from inner sweep and 300 mm from outer sweep. The unchanged central
600 mm body route at z=-4000 occupies z[-4300,-3700], leaving 50 mm to pump's
frontmost face z=-4350; rear wall interior face at -4500 leaves 50 mm behind it.
These are AABB calculations, not contact evidence. Retain PR149's continuous
spawn/inner-leaf detour, both apertures and outer-return route; test actual
CharacterBody3D/PhysicsServer contact with installed pump and all swept/open/closed
door shapes, floor seams and body heights. Place/recover fails if a body, world
container or existing machine overlaps the solid. Supporting-floor removal is
guarded while installed. No collision disabling, body teleport or narrowed body.

New immutable definition `item.chamber-recovery-pump.fabricated` revision1,
schema item-definition1, tags `item.handheld` and `equipment.chamber-pump`,
6000 ml external volume, base mass0 and storage null. Production's dedicated
`chamber_recovery.assemblies` material record supplies exactly 600000 mg through
both `payload_mass` and `payload_masses`; it is never also a generic structure,
machinery part or cargo payload. Exact record: assembly ID/item ID, definition
revision, bill/fingerprint, owner/body/world/region, 1000 J assembly-spend receipt,
original Inventory condition and mounted-or-carried state. No fabricated equipment
tag that accidentally routes through unrelated blueprint validation.

Build prepares the new physical item in the authenticated body's inventory using
the existing factory-candidate pattern with registered definition and capacity;
then place relocates that same ID to a dedicated bounded root container
`world.chamber-pump-<assembly-id>` at floor anchor `[5600,0,-4400]`, capacity one
item/600000 mg/6000 ml. Root is observable but general Inventory transfer/closure/
equip/socket operations must reject mounted pump movement; only the paired pump
recover command can remove it and retire the root. Mounted record and actual
Inventory item/root must match exactly. Recover prepares original item into the
body subject to capacity/available-hand/ownership checks; no condition reset or
material refund. Salvage only an owned carried inactive item; remove exact ID and
refund original bill once, preserving lifetime audit. Record existing condition
verbatim; only condition1000 can start, with other conditions retained for salvage.
No new damage model, wear/repair operation or healing path.

### Versions, lifetime limits and reciprocal accounting

Pin Production save16, observation18, paid-door observation7 (pump interlocks),
Pressure save6, pump assembly/job/accounting records1 and pump blueprint1.
Pressure6 extends the chamber5 shape with `pump_accounting`; it preserves every
existing gas volume/valve field. Inventory system5, shared owner2 / ledger2,
item-definition1 and Production intent1 envelope remain their existing shape;
strict operation allowlists gain pump operations. Add new emitted schemas for
Production16/observation18/paid-door7/Pressure6/pump records and update every
current consumer's accepted/unsupported-version controls. Do not accept unknown
future versions or alter old immutable item/blueprint/catalog bytes.

Legacy Production<=15/Pressure<=5 normalize to empty pump history/accounting,
without changing old gas, energy, origins, receipts or definitions. Both absent
is valid; a current pump on only one side is invalid. Existing chamber records
remain unchanged in their nested version. New item registration never spawns an
item or grants a rating. No missing-owner migration creates a pump.

One current assembly maximum, at most32 lifetime assembly records and128 lifetime
jobs; retain completed/cancelled/salvaged summaries, reject further creation at
capacity instead of trimming provenance or inventing a counter reset. Jobs have
monotonic server ID/sequence, initial mol, target=0.2*initial mol, returned mol,
spent J, immutable maxJ=`min(25000, actual_bank_J_at_start)`, owner/control binding,
state and last successful batch tick. Client supplies no target/maxJ/efficiency.
maxJ must be positive; each batch checks spent+price<=maxJ and current bank>=price.
Stop means pause; resume retains the same target/maxJ/spend. Cancel permanently
closes that job without refund; a fresh authorized job may target20% of then-current
gas, but all lifetime counters and actual bank debit persist. Place/recover/refit/
salvage/build never reset job history or recovered-mol/paid-J totals. No budget
refresh on restart, receipt eviction or reload. Bounds/overflow reject before write.

Production owns authoritative bank and material/job accounting. Pressure6 stores
a reciprocal audit mirror, not another energy/gas owner: monotonic commit sequence,
assembly/job ID, last batch tick, exact last q/chargedJ, cumulative returned mol
and paid J, plus retained per-job summaries (same128 limit). Both candidates receive
the identical calculated values, never recomputed/rounded independently. Reciprocal
sequence/totals/job summaries must match exactly on every prepare/restore; check
sum(job paidJ)=lifetime paidJ, sum(job returned mol)=lifetime returned mol using
the same deterministic accumulation order, valid target/spend bounds, and bank
+ lifetime pump assembly/batch spending<=100000 J as a necessary finite-origin
constraint. Other existing station spending remains in the existing bank/receipts;
the mirror is not permission to infer or refill missing energy.

### Prepared API, CAS and commit boundaries

New server-only `PreparedChamberRecoveryChange` is short-lived, single-use and
never persisted/sent. Proposed `Production.prepare_chamber_recovery_step(tick)`
returns a prepared success or rejection; it asks
`Pressure.prepare_chamber_recovery_transfer(assembly_id, job_id, q, tick)` for
detached decoded pressure-after plus conservative cost. No public caller chooses
cost/efficiency or writes gas. `prepared.commit(production, pressure, inventory,
access)` verifies exact owner object identities, volatile restore fences, expected
Production state_revision/last_tick and complete before snapshot (including
bank/job/material claims), exact Pressure before record (all volumes, valve,
sensor, accounting state), Access pair before records, and Inventory owner/ledger
revisions, body/control/action epochs, current grip/tool/pose/condition and
controller restore generation. Compare exact canonical records where no revision
exists; a prior matching ID alone is insufficient. A mismatch consumes/rejects
the prepared object. Validate overflow, candidate schemas and all cross-links
before the first assignment.

All allocations/decoding/projection/hashes and optional test-failure injection
occur before publication. Final boundary directly swaps prepared Pressure state
and Production state with no callback, signal, decoder, allocation-dependent
helper, yielding or restore. Optional Inventory swaps for build/place/recover
must be completely predecoded and fenced before this same boundary; pure gas
steps do not change Inventory or Access. Existing Inventory factory preparation
and `PreparedDoorChange` demonstrate detached preparation; neither live factory
commit followed by gas mutation nor live `MachineryWorkshop.draw` is acceptable.
Build/place/recover/salvage use the same rejection-before-write discipline.

First implementation phase is this prerequisite plus focused failure-injection
tests, before pump UI/preview expansion. Inject before/after candidate preparation,
at each owner validation and immediately before publication; change bank, gas,
claims, door/valve, Inventory/grip/body/epoch, restore fence and single-use status
between prepare/commit. Assert equality of every affected owner and reciprocal
receipt/counter, including successful same-step second-call rejection. No rollback
or live compensation. Prove legitimate success charges the computed work once.

### Scheduler and paused-reload cadence

Keep Pressure priority0 (passive flows then sensors) and Production priority300.
Production advances last_tick, simulates existing timed canister/machinery work,
then calls pump scheduling exactly once before extraction/recipe early returns.
Successful previous spends have precedence; pump plans against the current bank.
Admission at external-command tick start sets first eligibility to tick+60.
Successful batch sets next eligibility to tick+60. Ineligible ticks have no pump
mutation; stalled eligible ticks derive a reason with unchanged job/gas/bank/
receipts and can try one batch on a later tick, never catch up multiple batches.
Explicit stop or lost session/reach/tool parks the job until authorized resume;
resume sets fresh eligibility current_tick+60 while retaining target/maxJ/spend.
No saved session secret. Whole-world reload installs a paused job with retained
last successful tick; normalize that pause in both candidates, no debit/transfer,
and require fresh resume/60-tick delay. Reload/stop cannot accelerate the rate.
Running pump interlocks are enforced at external commands and step admission.
Actual volumes drive admission/UI; sensors deliberately catch up next tick.

### Boundary checks before device expansion

Use R=8.314462618 J/(mol*K), actual fixed T and volumes; mol as existing finite
float, J as exact bounded integer. Compute after-state first, use dimensionless
PHafter/PCafter and natural logarithm, ceil only after dividing by0.35, then add1.
Check no rounded-down free charge, positive q, q<nC, strict finite endpoints and
monotonic PH increase / PC decrease before assignment. Accept exact250J,110kPa,
ratio16 and1kPa boundaries; reject just outside. Test exact integer/near-integer
work charges, tiny final target batch, equality/downhill min1J, absent energy,
maxJ exhaustion and unsupported timebase. Do not use pressure epsilon to erase
matter or clamp a final amount to empty. Preserve the original29.93126178mol /
22993J model target with meaningful runtime receipts after authorization.

## Controls and acceptance after design approval

Real hosted controls select pump/mount and show bill, bank J, chamber/habitat
absolute pressures, remaining target mol, returned mol, paid J, running/paused/
stalled state, 250 W / 0.1 mol/s limits, elapsed active seconds and exact blocker.
Start/stop/resume/recover/refit use the existing authenticated action queue;
stale/rebound/disconnected views disable actions until fresh owner observation.
Explain 20% partial recovery and remaining manual vent/force sequence plainly.

- Unseeded finite acquisition/build route, paid pump placement, physical support,
  UI operation, 20% return in about 300 active seconds, 22993 J model check and
  all-volume mole/material/energy accounting. Actual integration receipt totals
  must substantiate the design arithmetic; no source-to-runtime inference.
- Both door traversals and complete outward/return manual cycle, pump interlocks,
  no habitat vent shortcut, isolated recovery/refit/salvage and stable provenance.
- No power, insufficient bank, over-job budget, >250 J batch, exhausted target,
  source floor, ratio16, destination110 kPa, unequal T, nonfinite values, wrong
  owner/session/body/reach/tool/hand, stale revisions/epochs, replay/changed intent,
  concurrent material reservations and safe-close cases with rejected-step equality.
- Forced failure at each preparation/CAS boundary proves no one-sided debit/gas
  transfer. Unrelated passive flows and scheduling have deterministic ordering.
- Save/reload before/after a charged batch, stalled/restored paused jobs, corrupted
  link/bill/energy/tick/target candidates and old-world no-grant preservation.
- Existing chamber/pressure stability, force/bypass, reinforcement, finite bootstrap,
  machinery energy, timed construction, Inventory/UI and strict emitted schemas.

Current verification is source, arithmetic and diff review only. Outcome, budget
and power binding are accepted; no runtime/schema edits until Coordinator accepts
this pinned implementation amendment and transaction boundaries. Then freeze/push
implementation head and request an explicit
exclusive exact-head NO-PORT lease with named stages/budget, AST-extracted versioned
Invoke-GodotCheck, empty preflight inventory, first-diagnostic stop, no edit/retry,
retained logs and postflight release. Final Windows/Linux exact-head CI and emitted
schema negatives required; distinguish source head and tested merge revision.
Capture only if actual UI/physical uncertainty remains. No successor, media,
publication, spending, deployment or outreach.
