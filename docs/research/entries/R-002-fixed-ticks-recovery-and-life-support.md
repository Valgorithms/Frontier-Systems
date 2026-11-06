# R-002: fixed ticks, recovery, transport and life support

- **Topics:** simulation, persistence, multiplayer/networking, engineering-game design
- **Outcome/status:** proposed; public source and Frontier source inspected 2026-10-30; no experiment executed or design adopted
- **Project snapshot:** [115f0e3c2fbf059819a4844ccdeffb64182af062](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/README.md); compare with the then-current integration head and active work before execution.
- **Next decision:** select one scenario and define its acceptance threshold before a separately authorized isolated test. These are research proposals, not implementation assignments.

## Sources and context

All sources below were accessed on 2026-10-30; documentation pages are mutable even where versioned. Publication/update dates are included when available.

| ID | Primary source | Author/date/version and reviewed scope |
| --- | --- | --- |
| S1 | [Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/) | Glenn Fiedler, 2004-06-10; fixed-step accumulation, catch-up headroom, interpolation and overload discussion; unversioned article |
| S2 | [High-level multiplayer](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) | Godot documentation contributors; date not stated; 4.7, transfer modes/channels; page may change without a documentation commit pin |
| S3 | [Atomic Commit In SQLite](https://www.sqlite.org/atomiccommit.html) | SQLite project; date not stated; mutable article, rollback-journal mode, flush ordering and failure assumptions; WAL uses a different mechanism |
| S4 | [Environmental Control and Life Support Systems](https://www.nasa.gov/reference/environmental-control-and-life-support-systems-eclss/) | NASA Marshall Space Flight Center; page updated 2025-04-04, editor Beth Ridgeway; ISS air revitalization and oxygen generation; descriptive real-world reference |

The user-designated [HELLION baseline](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/design/hellion-baseline.md) remains primary. NASA describes ISS equipment, not HELLION gameplay. Its system split is a research question, not an attributed HELLION mechanic or an instruction to adopt real-world thresholds. No source code, creative assets, full articles or game content are imported.

## Claims, independent evidence and proposed tests

### Fixed-step catch-up (simulation)

**Source claim:** S1 argues that a fixed simulation step with limited catch-up work avoids unbounded work accumulation; limiting steps can instead slow apparent simulation. Interpolation between simulation states smooths presentation at the cost of displaying older state. A fixed step alone does not prove cross-platform determinism or identical physics.

**Frontier inspection:** [SimulationRunner](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/src/core/simulation/simulation_runner.gd) documents fixed physics cadence, a default 16,667 µs tick budget and bounded command counts; [the rate matrix](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/development/simulation-rate-benchmark-matrix.md) already flags changes in work per second and tick-based health semantics at 72/90 Hz. Existing reports are historical, not measurements from this pass. Engine frame scheduling/catch-up policy and a real overloaded host were not verified.

**Proposed experiment:** at a fixed 60 Hz, compare matched low-load and bounded burst workloads on an isolated authorized fixture, preserving workload and inputs, warmup, capture windows and hardware. Record per-tick p95/p99/max, queue age/depth, budget overruns, simulated ticks per wall second and any catch-up/slowdown; separately capture render pacing. Include command ordering and conserved state checks. Compare work per *simulated second* as well as per tick. Do not change the scheduler or infer a new rate from a microbenchmark. **Cost/limit:** burst fixtures can miss expensive real-world combinations; profiling itself adds overhead.

### Commit and acknowledgement boundaries (persistence)

**Source claim:** S3 explains rollback journaling and ordering under stated filesystem/device assumptions; journal durability and recovery depend on correct locking and flush behavior. Its commit mechanism is SQLite-specific and differs in WAL mode.

**Frontier inspection:** [checkpoint recovery](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/development/checkpoint-recovery-milestone.md) describes alternating slots, validated staging/readback/promotion and prior fault-injection tests. It explicitly limits its assurance to the local protocol and does not prove device power-loss durability, directory sync or a per-command journal. This pass did not rerun those tests. SQLite is not established as the project's current store.

**Proposed experiment:** extend the existing isolated fault-injection suite only if a fresh gap remains after reviewing active work: compare interruption immediately before promotion, after promotion before acknowledgement, and after acknowledgement, using a retained original request. Assert either old or new valid committed snapshot, correct captured tick/sequence, and explicit unknown-outcome reconciliation without duplicate material or blind replay. Negative controls: corrupted staging and same-sequence/different-content retry. Record the actual filesystem/OS and injected boundary. **Cost/limit:** process-level injections cannot establish real power-cut or device flush ordering. No storage-engine migration is proposed.

### Channels versus current WebSocket transport (multiplayer)

**Source claim:** S2 describes reliable/unreliable transfer modes and separate channels in Godot's high-level multiplayer API; separate streams can avoid one logical reliable stream blocking another. This is API/transport-specific, not a universal WebSocket behavior.

**Frontier inspection:** [FirstPlayableHost](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/src/adapters/network/first_playable_host.gd) uses `TCPServer` and `WebSocketPeer`; [adapter contract](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/architecture/first-playable-adapters.md) describes bounded frames, rate/queue limits and slow-consumer closure. These facts do not show ENet channels in the current path, real packet-loss latency or production-network behavior.

**Proposed experiment:** use an isolated injected/mock transport with a fixed two-client command stream and large observation bursts. Control A sends normal-sized observations; B injects bounded backpressure/delayed reads using the same WebSocket path. Measure command admission-to-completion p95/p99, queue occupancy, disconnect/reconnect and duplicate or missing outcomes. Verify authoritative order, authorization and no double application in both arms. If a future ENet comparison is authorized, test it separately with matched security, payload and reliability semantics; channels are not a setting to apply to the current socket. **Cost/limit:** mocks cannot establish internet latency, congestion behavior or security equivalence.

### Air supply versus carbon-dioxide removal (engineering design)

**Source claim:** S4 describes ISS oxygen generation and air revitalization as distinct functions with different processes. It is neither a HELLION mechanics source nor evidence of Frontier behavior.

**Frontier inspection:** [breathing/pressure design](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/design/breathing-mixtures-and-pressure-control.md) documents detached species-aware records and a fictional prototype policy; its bulk airlock solver has only total moles, and runtime metabolic consumption/scrubbers remain planned. No health, pressure or UI test was run this pass.

**Proposed design experiment:** after verifying the HELLION version's actual life-support behavior and existing implementation lanes, compare two scripted scenarios with identical starting mixture and oxygen supply: functional versus disabled CO₂ removal. Track constituent quantities, readable indications, conservation and recovery path, without importing NASA values as game balance. Verify authorized repair/failure outcomes and retained resources through restart only when a relevant system exists. **Cost/limit:** real ISS architecture is not proof of HELLION parity; adding a separately simulated scrubber could increase UI, persistence and tick costs. Treat deviations as explicit design decisions, not as automatically approved features.

## Outcome and ownership

All four experiments are **proposed**, not executed; no measured performance improvement, storage guarantee, network advantage, implemented gameplay or HELLION feature parity follows from these references. Reuse existing harnesses and coordinate with active implementation owners before testing. A future result must link exact commit/diff, inputs, OS/engine/transport, raw evidence where separately authorized, failed and not-run cases, and a decision rationale. Keep unpublished/private research, logs and credentials out of public updates.

## Follow-up source review: 2026-11-06

The following are new sources for existing research questions, reviewed 2026-11-06. All outcomes remain **proposed**; no experiments ran. Prior source and experiment records above are retained.

### Camera interpolation and simulation authority

**Source:** Godot documentation contributors, [Advanced physics interpolation](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html), 4.7; publication date not stated, mutable page, no documentation commit captured. It describes following an interpolated target for camera presentation, current physics transforms for gameplay, and the fact that an uninterpolated child can still inherit its moving parent's interpolated rendering transform.

**Frontier evidence:** [Camera motion smoothing](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/development/camera-motion-smoothing-milestone.md) documents angular presentation smoothing while preserving body/collision behavior and existing selection-ray contracts. It reports historical checks, not evidence collected this week. It does not establish that Godot's optional physics interpolation is enabled or that a different hierarchy is warranted.

**Proposed experiment:** After coordinating with existing owners and obtaining separate execution authorization, compare the current camera setup with a presentation-only interpolation fixture at fixed physics cadence and two recorded render cadences. Inspect first/third-person motion, parent/child inheritance, a discontinuity/reset and wall occlusion. Assert the same authoritative snapshots, movement/collision results, reach validation and selection/occlusion correctness. Record camera delay, visible discontinuities and any picking mismatch; establish acceptance thresholds beforehand. **Tradeoff:** smoothing can add visible/input latency and hierarchy complexity; the source does not prove that a change is needed in Frontier.

### Network snapshot smoothing

**Source:** Glenn Fiedler, [Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/), 2014-11-30, unversioned article, accessed 2026-11-06. Its illustrative snapshot buffering trades added display delay for smoother reconstruction under jitter; the example's UDP workload, loss and timing are not Frontier targets.

**Frontier evidence:** [First-playable adapters](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/architecture/first-playable-adapters.md) describe authoritative host state, disposable client observations, bounded WebSocket/TCP transport and reconnect invalidation. This is not proof that a snapshot interpolation buffer currently exists or that network motion is jittery.

**Proposed experiment:** With isolated, injected WebSocket observation delivery and fixed authoritative inputs, compare immediate presentation against a bounded visual-only snapshot buffer across recorded delay/jitter patterns. Include disconnect/reconnect, stale session generations, teleports and missing updates. Record display age, visible position error and buffer underruns; assert commands, collision, reach checks and persisted state are identical. Choose buffer size and acceptable latency before testing. **Tradeoff:** extra delay and stale visual information; a mock does not establish Internet performance or justify copying UDP loss/rate assumptions.

### Storage mode and multi-owner boundaries

**Source:** SQLite project, [Write-Ahead Logging](https://www.sqlite.org/wal.html), unversioned mutable documentation, publication date not stated, accessed 2026-11-06. It describes WAL's separate log/checkpoint behavior, same-host shared-memory requirement and lack of atomicity across a set of attached databases in WAL mode. These details are conditional on SQLite/WAL, not general guarantees for files or networks.

**Frontier evidence:** [Local checkpoint recovery](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/development/checkpoint-recovery-milestone.md) describes two JSON slots and bounded recovery; [persistence design](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/design/persistence-and-command-boundary.md) describes a separate repository contract. Neither establishes SQLite as the current adapter or proves hardware power-loss durability.

**Proposed experiment:** Only if a future SQLite adapter is separately considered and authorized, design isolated tests using one database transaction versus two attached databases, recording SQLite build, journal/synchronous modes, filesystem, storage failures and OS. Interrupt at transaction/checkpoint boundaries and compare restored owner revisions and invariant results; treat unsupported or uncertain outcomes as failures to establish the guarantee. Do not modify the present checkpoint protocol or imply WAL is a selected dependency. **Tradeoff:** WAL/checkpoint lifecycle and sidecar files complicate backup and operation; this source does not establish actual Frontier latency or atomicity.

### Save compatibility versus behavioral compatibility

**Source:** Factorio team / Wube Software, [Friday Facts #449: 2.1 Stable](https://www.factorio.com/blog/post/fff-449), 2026-10-23, accessed 2026-11-06. The authors state that 2.0 saves load in 2.1 but circuit input/output changes may break existing factory designs, and updated saves/blueprints cannot be downgraded to 2.0. This is Factorio's report, not an observation of Frontier or HELLION. The linked FFF-442 was not independently reviewed for this entry.

**Frontier evidence:** [Control circuit runtime](https://github.com/Valgorithms/Frontier-Systems/blob/115f0e3c2fbf059819a4844ccdeffb64182af062/docs/architecture/control-circuit-runtime.md) documents versioned records and restoration of circuits, wires and queued pulses. A valid decoded record by itself does not show that a particular old factory retains equivalent behavior after migration; no migration test was run here.

**Proposed experiment:** When a real control-schema change is proposed, preserve an isolated fixture of an old-version circuit with known inputs, outputs, power and pending pulse state. Compare an old-version replay with the migrated circuit under the same tick-indexed inputs; check outputs, sequence/order, retained resources and documented exceptions. Include unknown-version and incompatible-route rejection, and confirm the original fixture stays available for rollback. **Tradeoff:** semantic compatibility may require preserving older behavior or an explicit user-visible migration, not merely accepting serialized fields. Treat Factorio as a secondary engineering lesson; establish HELLION behavior independently before adopting gameplay differences.
