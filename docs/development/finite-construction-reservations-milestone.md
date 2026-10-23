# Finite construction reservation foundation

Status: implemented detached contract; no runtime integration or playable queue.

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

## Live integration in progress

The `finite-canister-owner-transaction` branch integrates only refined iron in the canonical workbench store. All command planners must pass a shared precommit claim-coverage check, including older atomic factories and transfers. Machine cargo/hoppers, deposits and physical plates remain distinct sources and cannot withdraw claimed workbench iron. Production owns the reservation fragment and material bill; Inventory prepares the real item and nested container before the synchronous owner transaction commits. No UI queue or recipe expansion is planned.
