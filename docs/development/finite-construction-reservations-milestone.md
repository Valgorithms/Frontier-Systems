# Finite construction reservation foundation

Status: owner integration implemented on PR #131; no presentation queue. The detached foundation sections through Verification record PR #129 and its original boundaries; the implemented owner integration follows.

Scope is one trusted `equipment.canister` blueprint from `data/production/equipment-blueprints.v1.json`: one fabricated canister shell costs 1,000,000 mg iron. Production remains the only material owner, Inventory owns physical items and child containers. New reservation plans must be committed with those owners, never used as a second material store.

Owned files: `src/core/production/construction_reservation_plan.gd`, `tests/godot/construction_reservation_plan_test.gd`, `docs/schema/construction-reservation-v1.schema.json`, and this milestone. Existing runtime owners, schemas, CI, topology and presentation remain outside scope.

Acceptance: deterministic bounded work, actor/revision checks, interrupt/resume/cancel, retained idempotent receipts, competing claims, conserved completion/cancellation in an executable transaction fixture, and serialized restore. Integration requires an exclusive owner change before any queue is exposed.

## Reservation and work contract

`ConstructionReservationPlan` is a pure proposal builder, not a SimulationSystem or command endpoint. The future canonical owner is Production. Its v1 fragment contains jobs and receipts only, never stock. `claimed()` counts one bill for every active, paused or ready job; cancelled/completed jobs hold no claim. `owner_iron_mg` is gross stock from the same current owner snapshot, including reserved stock. A reservation succeeds only if gross stock minus all claims covers another bill. Cancel releases the claim without adding material. Interrupted work retains both claim and progress.

The new policy is 120 consecutive validated fixed ticks per canister, intended for the existing 60 Hz timebase (two seconds of active work). This duration is an explicit prototype policy, not a field claimed to exist in the blueprint. Each `advance` increments by one; duplicated/skipped ticks reject. Resume sets a new starting tick without catching up elapsed time. Ready work completes only at its last validated tick. Interrupt/restore of readiness requires one fresh tick after resume. Progress does not itself consume matter or produce equipment.

Requests contain exactly request ID, job ID, operation, expected reservation revision and tick. Trusted ingress supplies authenticated principal, gross owner stock and owner revision separately. Existing `ControlContractValidation` and `ServiceResult` conventions apply. Every new transition increments reservation revision; actor ownership and expected revision are mandatory. Exact retained retries may succeed across later revisions but return no effects. Reusing an ID for another actor or intent rejects. JSON integer-valued numbers normalize before intent hashing. Receipt values report the original committed operation/revision; a successful historical retry does not restart a cancelled job.

The registry retains at most 16 jobs (including terminal jobs) and 2,048 receipts without eviction. Capacity exhaustion fails closed. There is deliberately no archival/reuse policy, unbounded queue or implicit receipt expiry. Revision/tick arithmetic stays within exact JSON integers. Persistence uses [v1 schema](../schema/construction-reservation-v1.schema.json) plus executable semantic validation for receipt references, actors, revisions, state/progress and claim coverage. Restore accepts trusted owner checkpoint fragments only, pauses unfinished work and increments revision when it changes state. It neither authenticates an arbitrary save nor reconstructs missing materials. Terminal states and receipts survive restart.

## Required owner integration

The returned `record` and `effects` are candidates only. `completed` in a candidate is not evidence of a committed physical item. The integrating owner must:

1. Read stock, reservation fragment, authorization and global owner revision from one trusted fixed-tick snapshot. Check current reach, manipulation/capabilities, world/region/control authority and timebase. Pause on interruption; no external callback may advance work.
2. Make **every** path spending the same iron honor these claims, including atomic factories, loading/transfers and other production jobs. Existing paths currently do not; this detached class cannot reserve live stock against them.
3. Prepare the existing canister factory/Inventory transaction, real nested cargo container and conserved shell bill. Completion proposes exactly a 1,000,000 mg iron debit, blueprint ID and stable job-derived output ID. It does not create the child container or invent a physical item. Check output collision, capacity and trusted blueprint identity/revision/material bill before commit. Apply any required completed-work tool wear through its owner.
4. Compare-and-swap the returned `base_owner_revision`, and atomically commit stock, reservation record/receipt and all prepared physical-owner changes. Any failure commits none. Increment global owner revision for every material, reservation or physical mutation, including restore. Do not execute effects twice on receipt replay. Do not expose candidates to clients as authority.
5. Persist/recover all affected owners in one validated world checkpoint and validate claimed material coverage. Keep prepared candidates ephemeral. Add cross-owner restore rejection and crash/failure tests in that exclusive integration change.

Without these steps, conservation and live competing spends are **not established**. The test's atomic transaction fixture demonstrates the required contract, not existing Production/Inventory integration. The foundation stores no energy, tools, inventory copies, world cache or room/topology data. It adds no simulation registration, network endpoint, UI or port.

Owner profiling should expose existing bounded job/receipt counts, total claimed mg, progress/denial/completion counts; this pure class adds no tick scheduler or logging side effects. Reach, material provenance, factory output and durable cross-owner atomicity remain with their current owners.

## Verification

On Windows with Godot 4.7.2, the existing runner passed import, startup and `construction_reservation_plan_test.gd` using `-TestTimeoutSeconds 120`; logs/JUnit are under ignored `var/ci/reservation-foundation-final`. The focused test checks actual blueprint mass, side-effect-free plans, competing/stale candidate CAS, double spend/insufficient stock, foreign/stale/changed-intent requests, finite work and pause/resume, fresh completion, output-preparation failure, completion replay, cancellation/recovery, serialized restore/retry, malformed counters/state and bounded registries. The conservation fixture starts with finite 2 kg iron and ends with one 1 kg shell plus 1 kg stock, no outstanding claim.

No live runtime queue, actual physical output transaction, graphical interaction, controller/VR, public deployment or capture was exercised. Captures would not resolve the outstanding owner integration contract. Required repository CI is tracked on the PR head separately from this local evidence.

## Implemented owner integration

The `finite-canister-owner-transaction` branch integrates only refined iron in the canonical workbench store. All command planners must pass a shared precommit claim-coverage check, including older atomic factories and transfers. Machine cargo/hoppers, deposits and physical plates remain distinct sources and cannot withdraw claimed workbench iron. Production owns the reservation fragment and material bill; Inventory prepares the real item and nested container before the synchronous owner transaction commits. No UI queue or recipe expansion is planned.

### Owner transaction and spending audit

Production v8 adds `construction`, `construction_bindings` and permanently retained `construction_commands`. The existing Production/Inventory owners remain canonical. A command reads current state, prepares all changes, checks claim coverage, validates Inventory capacities and tool associations, then commits synchronously without an await. Production rolls back if Inventory rejects its prepared owner. Nothing publishes a candidate or invokes an external callback during preparation. Inventory retains its independent physical-owner revision; fresh physical validation runs in the same synchronous call, so no prepared candidate survives between ticks.

Only `store.iron` funds these jobs. The shared precommit guard rejects every candidate with less iron than outstanding claims, before material, Inventory or Tools publication. The audited paths are:

- `process`: debits recipe inputs into the existing reserved batch.
- `load_cargo`: debits workbench stock into a physical carrier; `unload_cargo` credits it.
- `fabricate_equipment`, `fabricate_tool_part`, and `machine_craft`: debit the same workbench stock through their existing planners.
- `materialize_plate`, wall `build`, and spatial wall placement spend plate or paid physical plate components rather than refined iron.
- `machine_print`, `machine_autolathe_make`, machinery recipe ticks, and hopper operations spend cargo/hopper material already outside the workbench. Such material can be loaded only through the guarded transfer path. Extraction spends finite deposits; batch completion and recycling only credit the store.
- Tool repair spends finite energy rather than iron. All command paths still pass the shared coverage invariant.

Old atomic factories retain their prior behavior for unclaimed stock. No legacy factory silently becomes a timed job, and no extra material owner, recipe, transport endpoint or UI is introduced.

### Ingress, interruption and persistence

The fixed-tick `ProductionDevelopmentCommand` accepts the separate [timed canister intent](../schema/timed-canister-intent-v1.schema.json): `canister_reserve`, `canister_interrupt`, `canister_resume`, `canister_cancel`, `canister_complete`, with exact `job_id`, `expected_revision`, `expected_reservation_revision`, and `control_epoch`. Authenticated context supplies principal/world/region; trusted Inventory supplies body/control epoch and current capability. Tick/advance commands are server-owned. The scope is explicitly the 60 Hz workbench/printer prototype, pinned to 1,000,000 mg iron and the current trusted canister blueprint fingerprint. Other production timebases retain old factories but cannot start timed canisters.

Reserve/resume retain the authenticated context only in memory. Every work tick checks reach, manipulation, current body/control epoch and printer power. Lost capability pauses work while retaining its material claim. Resume does not catch up elapsed time. Ready progress remains nonphysical until a fresh authorized completion command prepares exactly one actual Inventory item and nested container, debits the shell bill and printer energy, and commits the reservation terminal state/receipt together. Completion consumes the last validated work tick and rechecks authority at its fresh ingress tick. Output collision, power/energy, capacity and preparation failures leave every owner and receipt unchanged.

The [v8 persistence schema](../schema/production-system-v8.schema.json) retains 50 mm wall coordinates for compatibility with the independently owned placement change. V1-v7 restore migrates to empty claims without grants/debits. V8 validates claim coverage, blueprint fingerprint, body/principal/control-history associations, finite counters, command/reservation receipts and existing physical/provenance links before any world owner restores. Restoring unfinished work pauses it, increments revisions and discards live grants; explicit authenticated resume is necessary. Checkpoints remain trusted world checkpoints, not authenticated arbitrary save imports. Completed outputs can later be transferred or salvaged by existing owners; historical terminal jobs do not retain a second ownership claim over those items.

Limits remain explicit: 16 retained jobs, 2,048 reservation receipts, 128 permanent operator-command receipts, no eviction or job archival. Exhaustion fails closed. No networking/UI usability, graphical/controller/VR acceptance or deployment is claimed by this integration.

### Physical output version and integration verification

The existing revision-1 fabricated canister has no storage definition. Changing it would rewrite the meaning of old items and saved blueprint fingerprints. The timed path therefore pins a separate immutable revision-2 definition and blueprint catalog: a real bulk-only child container with 2,000,000 mg / 2,000 ml capacity and no physical item slots. Production remains the bulk cargo/provenance owner; Inventory owns the physical shell and child container. Existing atomic factories continue to create revision-1 items. Structure fingerprints select the exact definition for restore and salvage.

The real `WorldRuntime` regression starts from finite 2 kg ore, refines it to 1.2 kg iron plus 0.8 kg tailings, reserves a 1 kg shell, and rejects competing factories, recipe spending and overlarge cargo transfers. It exercises loss of reach, changed control epochs, foreign/stale commands, permanent retries after the rolling receipt window, restart without a live grant, malformed cross-owner checkpoints, 120 validated work ticks, actual Inventory output collision, atomic completion/replay, restored child storage, bulk loading/unloading, salvage and cancellation. The final mass remains conserved; a legacy atomic factory still produces its original revision-1 item.

Windows Godot 4.7.2 verification uses the repository runner. Import/startup plus focused reservation, real-owner integration, equipment fabrication, machinery authority/runtime, malformed snapshots, recipe requirements, scratch construction, spatial walls and tool-parts checks are recorded under ignored `var/ci/canister-integration-release`. Earlier failed negative-control fixtures and the missing legacy child-container discovery remain in the earlier evidence directories. PR CI is reported separately against the pushed head. No configuration variables, network endpoints or deployment settings change.
