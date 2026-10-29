# E-001: baseline and shared wall resources

- **Related entry:** [R-001](../entries/R-001-modern-rendering.md)
- **Outcome/status:** proposed; not executed
- **Prepared:** 2026-10-25 against `b19e99ffd964006c4e590435239a8f17adbd62d5`
- **Execution scope:** a future separately authorized isolated run; this research pass uses cloud source reads only

## Question and static result

Does reusing equivalent immutable wall meshes/materials reduce construction/resource overhead or render submission cost without changing appearance, selection or authoritative state?

R-001's pinned call-path inspection counts 10 BoxMesh and 10 StandardMaterial3D constructor calls per newly created wall, including a superseded initial panel pair. Arithmetic expansion predicts the following **constructor calls**, not measured live allocations or draws:

| New walls | BoxMesh calls | StandardMaterial3D calls | Coverage |
| --- | --- | --- | --- |
| 32 | 320 | 320 | Current canonical wall cap |
| 100 | 1,000 | 1,000 | Synthetic presentation stress |
| 1,000 | 10,000 | 10,000 | Synthetic presentation stress |

Reproduce this inspection without running Godot: open the two pinned presentation files linked in R-001, follow _update_spatial_walls -> wall -> box -> material, and expand the fixed loops (2 vertical frames + 2 horizontal frames + 2 sides x 2 bars). Include replacement of the first panel pair. This source analysis establishes repeated construction only; actual object lifetime, GPU batching and performance remain untested.

## Stage A: measurement baseline

Reuse [benchmark_client.gd](../../../tools/godot/benchmark_client.gd) and the existing reporting conventions before proposing harness extensions. It currently warms for five seconds and measures fifteen seconds in the stationary main scene; it can overwrite renderer/rate-qualified reports. Archive old output and use new experiment artifact paths. No runnable new harness is supplied by this docs change.

For an authorized extension/run, record exact tested commit plus diff, Godot executable/version/build, OS, CPU/GPU/driver, renderer/API, refresh/VSync/max-FPS settings, power mode, scene/map, content seed, camera path, physics rate and capture overhead. Verify actual root **and habitat** pixel dimensions: a 1920x1080 window is not proof of a 1920x1080 3D target. Keep 3D scale at 1.0 for the native baseline; report any inset UI layout separately.

Use a fixed camera path containing a stationary room, movement past thin wall details and an open view. Keep topology, lights/shadows, UI and simulation workload identical across pairs. Proposed sampling is five interleaved A/B pairs with five-second warmup and sixty-second measurement per run; separately label cold construction/startup from warm steady-state rendering. Preserve raw per-frame samples, counts, missing samples and the percentile method. Report per-run results and variability rather than treating correlated frames as independent trials.

Measure end-to-end frame intervals (p50/p95/p99), render CPU and GPU timings with their boundaries, simulation/physics timing separately, wall creation/removal time, node/resource counts, draw calls/primitives and CPU/GPU memory gauges. Label unavailable measurements rather than infer them from FPS or engine counters. Engine gauges do not establish full process/driver memory or input-to-display latency. Investigate unexplained refresh-aligned waits before claiming a throughput difference.

## Stage B: single-variable A/B

- **A/control:** existing wall presentation and fixed topology.
- **B/variant:** same nodes, geometry, collisions, pick handlers and per-wall identity; share equivalent immutable meshes/materials within the wall presentation boundary. Include details and eliminate the superseded panel setup where safely equivalent. No MultiMesh, renderer/API, shadow, AA or simulation changes in this comparison.
- **Workloads:** 32 real-cap walls for relevance; 100 and 1,000 isolated presentation replicas for scaling diagnosis. Do not feed over-cap records into canonical owners or increase capacities. Include create, remove half, recreate and teardown phases.
- **Checks:** unchanged wall observations/world snapshots; correct per-wall selection, collision and teardown; equal visible geometry/color/material settings; no shared highlight mutation; no stale removed wall. Profile cache growth across repeated recreate cycles.
- **Predeclared criterion:** all correctness/readability checks must pass. Before measuring, choose one primary metric (construction time or render CPU time), a smallest useful improvement, acceptable frame-tail/memory tolerances and a repeatability rule. Proposed starting rule: improvement must exceed paired run variability at the relevant workload with no p95/p99 regression beyond baseline variability. If only synthetic scaling improves, record that limited result and defer production adoption.
- **Decision:** retain raw evidence even on failure. Mark tested only after independent reproduction; adopted additionally needs an accepted implementation/contract. A null result should redirect investigation rather than trigger renderer surgery.

Shared resources trade memory/creation work against cache lifecycle and accidental shared mutation. If the baseline remains pacing-limited or rendering is too small to matter, report that result. Do not sum unrelated video percentages or generalize one GPU/API result.

## Follow-on experiments, each separate

1. **AA/readability:** native resolution, fixed supported renderer/API; compare no AA, MSAA 2x/4x, TAA and native-resolution FSR2 only where supported by the actual engine. Verify the applied setting. Keep sharpening, resolution scale and motion-blur setting recorded/fixed. Capture repeated camera/object motion and thin details/labels; assess shimmer, ghosting, edge loss and target recognition alongside CPU/GPU and frame tails. A still screenshot alone cannot pass.
2. **Room occlusion:** same room/door/demolition sequence with occlusion off/on and simple conservative occluders. Check open doors, newly removed walls and oblique views against the control, including immediately after topology changes. Never retain a closed-door occluder over an opening. Measure CPU update spikes and visible-object counts as well as GPU savings.
3. **Shadow budget:** hold occlusion and topology fixed; vary a documented light/shadow budget independently. Capture readability and update cost through opening/demolition and multiple visible rooms. Do not change geometry to manufacture culling wins.
4. **Spatial MultiMesh:** consider only if Stage B leaves measured submission overhead. Partition by visibility region and preserve separate collision/identity. Document AABB/light limits and update costs. This is a later hypothesis, not the default variant.

## Evidence handoff

A future report belongs under a fresh reports/performance experiment path and links raw samples/logs, exact source/diff, environment, configuration, camera/workload definition and ordinary engine captures. Separate passed, failed and not-run criteria; keep VR, lower-end hardware and other APIs explicitly unmeasured until tested. Do not publish captures externally under this plan.

Initial result: pinned static inspection and arithmetic completed; baseline, variants, motion captures, GPU measurements and adoption **not run / pending**. No game, native benchmark, GPU workload or desktop process was launched or modified.
