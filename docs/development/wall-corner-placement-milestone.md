# Canonical wall corner placement

## Bounded design and ownership

Use a 50 mm floor-position grid for the existing 1000 × 2000 × 100 mm panels. Two contiguous X panels cap two Z panels; their centres differ by 550 mm at the corners, producing exact face contact without intersecting solids. All existing 100 mm placements remain valid with unchanged IDs, dimensions, mass and JSON records. Production remains the canonical owner and Inventory pays one physical plate through the existing fixed-tick command path. No periodic work or new persistence fields are introduced.

This task owns SpatialWallConstruction's placement rule, the wall-only schema constraints, narrow coordinate input/feedback adaptations needed to submit the new positions, dedicated canonical construction regression tests and these documents. It does not edit ProductionSimulationSystem or InventorySimulationSystem, which are owned by the timed-canister worker.

Acceptance requires finite extracted/refined stock to pay for a complete canonical perimeter recognized by ConstructedRoomTopology. Negative controls cover overlap, a deliberate gap, preview cancellation, authorization, movement and malformed checkpoints. Save/restore must retain stable wall IDs and exact stock. Existing 100 mm saves must still restore. Floors and ceilings remain absent; no gas, pressure, sealing or airtightness claim is made.

## Verification

Implementation and focused runtime verification are pending. Local Godot execution waits for the Coordinator's explicit no-port runtime lease. Windows/Linux CI will be evaluated against the final PR head. No graphical capture is planned unless the focused evidence leaves material behavioral uncertainty.
