# R-003: coordinate precision is not replay determinism

- Reviewed: 2026-11-13.
- Outcome: **proposed**. Source review only; no runtime, visual, cross-platform or benchmark reproduction.
- Decision: retain existing authority and local-frame design; do not enable double precision or promise deterministic lockstep from this review.
- Question: which separate acceptance checks are needed before distant regions, persistence and native physics can safely share a coordinate contract?

## Current project evidence

At integration snapshot `115f0e3c2fbf059819a4844ccdeffb64182af062`, `project.godot` selects Godot 4.7 features, Jolt Physics and 60 physics ticks per second. These settings do **not** establish the compiler flags of shipped binaries or replay determinism.

The [procedural-world design](../../design/procedural-planets-and-memory-budgets.md) already proposes hierarchical addresses, local physics and presentation origins without changing canonical identity. It explicitly treats planets as a future extension, not implemented streaming. This entry adds verification questions to that direction rather than proposing a second planetary system. The [persistence boundary](../../design/persistence-and-command-boundary.md) remains authoritative; physics state alone is not the whole world snapshot.

## Primary sources and limits

### Godot 4.7: precision and build compatibility

[Large world coordinates](https://docs.godotengine.org/en/4.7/tutorials/physics/large_world_coordinates.html), versioned but mutable documentation; publication date unstated; accessed 2026-11-13.

**Source claims:** vector precision decreases away from the origin even though GDScript scalar floats are normally 64-bit. Double-precision engine builds cost memory/performance and require rebuilt editor/export binaries; GDExtensions need matching builds. Multiplayer peers should use consistent precision builds. Local origin shifting is an alternative with extra multiplayer complexity. Increased precision does not fix every shader, particle or triplanar-mapping case.

**Independent interpretation:** changing numeric precision is not a universal rendering fix or proof that persisted/network coordinates retain meaning. The existing local-frame design is worth testing before a global engine-build change. No Frontier speed, memory or visual improvement was measured.

### Jolt: repeatability has conditions beyond a fixed tick

[Architecture: Deterministic Simulation and Rolling Back a Simulation](https://github.com/jrouwe/JoltPhysics/blob/776666eb232767d5e5b07b6f43cd820f5bf7161c/Docs/Architecture.md#deterministic-simulation), pinned upstream revision `776666eb232767d5e5b07b6f43cd820f5bf7161c` dated 2026-11-12; accessed 2026-11-13.

**Source claims:** reproducibility requires equivalent initial state and simulation-changing API order. Cross-platform determinism is a build option with matching source/defines requirements. Query results, active-body enumeration and multithreaded callbacks may need explicit stable ordering. Physics rollback does not automatically restore application changes or body/constraint lifecycle.

**Independent interpretation:** a fixed 60 Hz clock and seeded procedural generator are insufficient evidence for deterministic native physics replay. Upstream library guarantees are not automatically guarantees of Godot's integration or Frontier's application. The inspected project settings do not establish the applicable Jolt build configuration. No engine integration defect is claimed.

## Bounded experiments, not executed

Check active implementation ownership before selecting one scenario. Use cloud/GitHub execution only if separately authorized; this documentation pass does not authorize native tests.

| Proposed scenario | Controls and observations | Acceptance or rejection |
| --- | --- | --- |
| Local-frame round trip | One existing fixture at near and distant canonical addresses; same local geometry, object IDs and commands. Save/reload, unload/rejoin and two clients with different presentation origins. Record engine/build, frame IDs, local transforms and canonical snapshots. | Require stable identity, no inventory/cargo duplication and consistent interaction/collision decisions. Predeclare numerical tolerances by gameplay scale. Reject any coordinate conversion that changes canonical state merely because the camera recenters. |
| Replay ordering | Reinitialize the same bounded physics fixture with an identical ordered command/body-creation sequence, then vary unrelated insertion and callback enumeration order. Compare each tick's canonical state and separately tolerance-based physical outcomes. | Record the first divergence, not just final appearance. A passing same-build run does not establish cross-platform behavior. Require exact build flags and matching Windows/Linux scenarios before any cross-platform claim. |
| Precision cost and presentation | Only if local-frame evidence identifies a remaining need: compare matched single/double engine builds with fixed scene, renderer, resolution and workload. Include materials/particles, memory and tick/frame percentiles. | No adoption from a single average FPS number. Treat build compatibility, extensions and persistence/network conversion as separate acceptance gates. Preserve failed cases and hardware/build context. |

The three scenarios answer different questions. A visually stable scene may still replay differently; deterministic generation does not establish deterministic contact resolution; a physics snapshot does not prove complete application recovery. Do not expand this research into lockstep, rollback networking or planetary implementation without a separate design decision.

## Adoption status and next decision

No engine switch, runtime change or new performance claim is adopted. Prefer the local-frame round-trip scenario when the existing design owner reaches that milestone; defer native replay guarantees until exact binary provenance and ordered application inputs are available. This is new-to-knowledgebase evidence, not a claim that the underlying floating-point problem was newly discovered.
