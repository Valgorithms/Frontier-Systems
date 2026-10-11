# Authenticated terrain parcel client milestone

Expose whole owned terrain escrow through the invite-authenticated host and Terrain panel. TerrainMaterializeCommand remains the fixed-tick authority; callers submit only transfer_id and expected_inventory_revision with the existing independent claim ordinal.

## Acceptance in progress

Retain exact original intent across uncertain acknowledgement, disconnect and client restart. Scope observations to the authenticated principal. Verify atomic foreign/stale/full-inventory/changed-retry rejection using temporary two-client loopback fixtures. Schema validation and exact-head Windows/Linux CI are required before completion. No external service, live player, merge, release or deployment is authorized.
