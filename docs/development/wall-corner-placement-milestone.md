# Canonical wall corner placement

## Bounded design and ownership

Use a 50 mm floor-position grid for the existing 1000 × 2000 × 100 mm panels. Two contiguous X panels cap two Z panels; their centres differ by 550 mm at the corners, producing exact face contact without intersecting solids. All existing 100 mm placements remain valid with unchanged IDs, dimensions, mass and JSON records. Production remains the canonical owner and Inventory pays one physical plate through the existing fixed-tick command path. No periodic work or new persistence fields are introduced.

This task owns SpatialWallConstruction's placement rule, the wall-only schema constraints, narrow coordinate input/feedback adaptations needed to submit the new positions, dedicated canonical construction regression tests and these documents. It does not edit ProductionSimulationSystem or InventorySimulationSystem, which are owned by the timed-canister worker.

Acceptance requires finite extracted/refined stock to pay for a complete canonical perimeter recognized by ConstructedRoomTopology. Negative controls cover overlap, a deliberate gap, preview cancellation, authorization, movement and malformed checkpoints. Save/restore must retain stable wall IDs and exact stock. Existing 100 mm saves must still restore. Floors and ceilings remain absent; no gas, pressure, sealing or airtightness claim is made.

## Placement and persistence contract

Only floor X/Z coordinates change from multiples of 100 to multiples of 50 mm, still within ±100000 mm. Y remains zero; quarter-turn is 0 or 1 and the registry remains bounded to 32 panels. Strict positive-volume intersection still rejects placement; touching faces are accepted without a tolerance. Fixture, body, machine, movement, authenticated scope, revision, ownership and capacity checks still run through the existing owners. No materials, panels or corner fittings are granted. Production's existing `spatial_walls` counter and command diagnostics remain the profiling signals; there is no new per-tick work.

The existing production v7 save, v7/v8 observation and v1 intent schemas widen only their wall-position constraints. This is a reader-compatible extension for existing 100 mm saves, with no record migration or new fields. Older binaries enforcing 100 mm cannot read newly placed half-grid panels; use the updated runtime to load those saves. The concurrent timed-canister worker owns the new v8 production save schema and will carry forward these wall constraints.

The focused paid layout uses six panels: X caps at (5500, -4550), (6500, -4550), (5500, -3450), (6500, -3450), and Z sides at (5050, -4000), (6950, -4000), all coordinates in mm at floor Y=0. Its exact inner rectangle is [5100, 6900, -4500, -3500]. Ten kilograms of finite iron ore yield six kilograms of wall plates and four kilograms of tailings. This verifies fixed-panel construction rather than synthetic variable-span descriptors. The UI uses 0.05 m steps in wall mode and retains its half-grid draft across machinery mode, where the 0.1 m step remains.

## Verification

Implementation and focused runtime verification are pending. Local Godot execution waits for the Coordinator's explicit no-port runtime lease. Windows/Linux CI will be evaluated against the final PR head. No graphical capture is planned unless the focused evidence leaves material behavioral uncertainty.
