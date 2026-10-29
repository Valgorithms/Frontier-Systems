# Detached floor/ceiling geometry and room closure

This milestone owns new ConstructedRoomSurface and ConstructedRoomClosure helpers,
their focused tests and v1 schemas only. Production owns canonical paid records;
Inventory owns physical items. A later authoritative adapter must obtain surfaces
from validated paid records at the same production revision as the wall descriptor.
Caller-supplied geometry is never proof of payment or authorization.

The observable outcome is geometric recognition of one bounded rectangular wall
perimeter with explicit floor and ceiling rectangles. Compose the unchanged wall
topology helper; require exact interior coverage without gaps or positive-area
overlap at floor Y=0 and ceiling Y=2000 mm. Missing surfaces remain open.
Malformed descriptors fail. This does not establish airtightness, gas, pressure,
playable paid floors, rendering, controller/VR behavior or deployment.

No state, tick, material, reservation, command or persistence owner is added.
Descriptors are detached observations, never world-save records. No environment
variables, dependencies or assets are introduced. Runtime verification requires
the Coordinator's explicit exclusive no-port Godot lease.

## V1 contract

`ConstructedRoomSurface.decode` accepts exactly `surface_id`, `kind`,
`bounds_millimetres` (X minimum/maximum, Z minimum/maximum) and
`height_millimetres`. Bounds are integer mm within +/-100500 with strictly
positive width/depth. IDs use the existing nonblank 128-character contract.
Floor height is exactly 0; ceiling height is exactly 2000. These are horizontal
boundary planes, not solids with material, thickness, load capacity or collision.

`ConstructedRoomClosure.assess` accepts exactly schema version 1, production
revision (0..9007199254740000), raw v1 `walls` and up to 64 `surfaces`.
It revalidates walls through ConstructedRoomTopology and requires the same
revision. IDs are unique across both surface kinds; output IDs sort stably.
Positive-area overlap in either plane is malformed. Every tile must lie wholly
within the supported wall interior for its plane to count as covered. With no
overlap, equal integer areas establish exact rectangular coverage; gaps and
overhangs remain `open_or_unsupported`. Only both covered planes and a closed
wall perimeter return `geometrically_closed`. No tolerance, cache or general
polygon engine is involved. Input remains untouched; output is detached.

Work is on demand: at most 32 wall panels and 64 surface rectangles with bounded
pair comparisons. There is no tick cadence or persistent data to migrate.
ServiceResult failures and missing-plane output are the diagnostic signals.
The JSON schemas enforce shapes; ordering, identity uniqueness, revision equality
and coverage are explicitly runtime constraints. No room identity is minted.

## Verification and limits

The focused Godot test composes the real wall descriptor adapter using the exact
six-panel paid-layout coordinates from PR132. Explicit surfaces are synthetic
geometry, not canonical construction. Controls exercise missing tiles/walls,
1 mm gaps, overhang, overlap with compensating area, translated/transposed tiling,
JSON round trips, detached deterministic results, malformed records, coordinate
and revision bounds, 64 accepted surfaces and 65 rejected surfaces.

Windows Godot 4.7.2 import/startup and the topology, wall-boundary and paid-wall
perimeter regressions passed. The first new test run exposed a constant declaration
parse error; corrected import/startup and closure regression passed. Both runs
are retained under `var/ci/room-surface-initial` and
`var/ci/room-surface-corrected`. The Coordinator's lease was released after no
Godot processes remained. Schema checks use the new focused Python test with an
isolated ignored jsonschema 4.23.0 environment. Remote CI evidence is recorded
on PR133 separately. Gameplay capture is unnecessary for these pure geometry
contracts; native presentation, controller/VR and deployed behavior are untested.

The followup owner adapter must validate paid floor/ceiling records, payment and
physical installation/lifecycle, stable IDs, revision coherence and save/restore
before this foundation can support a gameplay or atmosphere claim. It must use
existing Production/Inventory owners, with no second canonical registry.

Canonical paid Production records and their revision-coherent owner query are now
implemented by the [paid horizontal panel integration](paid-horizontal-panels-milestone.md).
The detached helpers remain geometry-only and retain their original v1 contract.
