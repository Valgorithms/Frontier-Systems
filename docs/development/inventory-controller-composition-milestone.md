# Inventory controller composition prerequisite

## Owner and contract

A trusted same-process owner initializes one `InventoryRuntimeCommandQueue` over one canonical `InventorySimulationSystem`, obtains its exact `controller_authority()` for lifecycle changes, enqueues commands and calls `advance_tick` once per consecutive fixed tick. Inventory must not also be registered or advanced by another runner. The queue now delegates `own_inventory_observation` (including details), `world_inventory_observation`, `local_grip_observation`, `local_observation` and `read_search` through its existing internal gate. No raw gate or direct command-dispatch accessor is added.

Actor, body, scope and live-session validation remain gate/authority responsibilities; search preserves its voluntary capability and actor/target invalidation. The queue does not construct another authority, cache projections or accept caller-selected actors. Gate projections remain deeply detached and bounded by existing inventory contracts. Commands retain existing FIFO capacity, intent, attempt and sequence limits; reads create no receipts or job progress.

## Busy and recovery behavior

All five delegates fail without a projection while uninitialized, freed or busy, and refuse externally advanced tick state. Each read holds the same busy guard as command drain across provider validation and projection. Callback attempts to read, enqueue, advance or discard fail closed. Trusted lifecycle/recovery operations remain owner responsibilities.

A restore generation change detected before or during a read clears pending volatile commands, resynchronizes the queue tick and returns `queue_restored` without a projection. Reconciliation and fresh bind/pin are still required through the exact same authority. Replacement, revocation and actor/target invalidation fence both queued applications and observations. Snapshot v4, restore generation, scoped schemas and persistent records are unchanged. Queue profiling retains bounded pending/peak/attempt/rejection/discard/sequence counters; gate read profiling remains internal.

## Verification

`inventory_controller_composition_test.gd` composes actual inventory, health, queue, session provider and two bound controllers. Both issue canonical queued commands then read scoped projections. It exercises own details, world, grip, local jobs/outcomes and search, detached result mutation, wrong identity/scope/provider denial, actor and target replacement, revoke, identical-epoch restore/reconciliation/fresh bind, read-triggered restore clearing pending intent, provider reentrancy during reads and drains, exact 120-tick search completion, duplicate-boundary and external-advance conservation, and freed-runtime refusal.

Run the existing port-free `tools/ci/run-godot-checks.ps1` with pinned Godot 4.7.2 and the composition, queue, observation, gate, authority, lifecycle, inventory, grip, self/world/search and checkpoint regression tests. Local Windows import/startup and all 13 focused fixtures passed with Godot 4.7.2. Exact-head Linux/Windows CI status is reported with the PR; local success does not establish Linux execution. The unchanged CI discovers this fixture on both operating systems.

This is a same-process composition prerequisite. Network/admission rollout, production runner integration, graphical/controller/VR usability, live services and deployed performance remain deferred. No shared schemas, movement, presentation, dependency/configuration, art or provenance contract changes. First-party implementation, fixtures and documentation are MIT; no third-party material is added.
