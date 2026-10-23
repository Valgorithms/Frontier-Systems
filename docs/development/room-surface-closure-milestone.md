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
