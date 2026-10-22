# Constructed wall boundaries

Coordinator owns this bounded foundation for the room topology construction adapter. Production remains the canonical wall owner; PressureSystem continues to own existing gas volumes. No shared file is assigned to another worker. PR85 capture files are excluded.

The detached record is documented by `docs/schema/constructed-wall-boundaries-v1.schema.json`. Geometry relationships, ordering and overlap validation are enforced by the adapter in addition to the structural schema.

`ProductionSimulationSystem.construction_boundaries(context)` authorizes the same production visibility capability as ordinary observations and returns a detached v1 record. It includes the current production revision and ID-sorted panel boundaries: stable wall ID, two floor-centreline endpoints, height and thickness, all in integer millimetres. Orientation and dimensions derive from the existing physical wall contract. Invalid, overlapping or over-capacity registries fail without returning partial geometry.

This is an on-demand in-process adapter, not a per-tick system or network command. Worst-case work is bounded by the existing 32-wall registry, including pairwise overlap validation. No cache, persistence shape, gas amount, seal, room identity, server callback or command validation changes. Restore re-derives geometry from canonical walls; removal omits the recovered panel. Endpoints describe the panel centreline and do not assert corner joining or airtightness.

Acceptance: both orientations and negative coordinates produce exact dimensions; dictionary insertion order and JSON recovery preserve output; mutations of output cannot mutate input; malformed/overlapping records and invalid revisions reject. The paid wall runtime test checks actual constructed identity/revision, read-only behavior and authorization. Existing spatial construction tests retain conservation and restore coverage. Screenshots are unnecessary for this nonvisual contract.

Next bounded step is an explicit room-topology policy for panel joins, corners, gaps, floors and ceilings. Only after that policy and gas ownership/recovery tests may a separate change connect constructed rooms to PressureSystem. This milestone does not make player-built walls airtight or create a playable pressure vessel.
