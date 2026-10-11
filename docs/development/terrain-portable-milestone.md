# Terrain portable material milestone

## Scope

This branch implements one synchronous authoritative fixed-tick claim of owned terrain escrow into a portable physical inventory item. TerrainMaterialOwner remains the sole owner of its exact material mass and origin parcels; inventory owns physical parentage. A materialized transfer cannot be filled or claimed again. Production cannot consume this material.

The bounded implementation reuses inventory factory preparation and payload capacity checks, adds terrain checkpoint v2 with immutable materialization receipts, and retains v1 recovery. No mesh, streaming, presentation, external services or persistence worker changes are planned.

## Acceptance

Verify finite exhaustion, claimant authorization, capacity rejection, competing and repeated intents, exact total matter and origin provenance, physical inventory movement and atomic JSON recovery. Use the existing bounded Windows Godot runner and Windows/Linux CI. No graphical image is expected for this canonical boundary.
