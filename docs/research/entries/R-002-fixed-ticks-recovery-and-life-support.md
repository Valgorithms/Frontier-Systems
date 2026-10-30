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
