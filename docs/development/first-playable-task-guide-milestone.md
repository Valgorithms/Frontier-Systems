# Observation-only first-playable task guide

## Scope

A separate scrollable Guide tab describes current finite iron, scoped carried canister ore, workstation ore/iron, physical carried plates and spatial wall records. It never claims historical or actor-specific completion. It adds no commands, grants, canonical mutations, saved state or protocol fields. Existing tabs retain their indices, world labels and native picking.

ProductionSimulationSystem and InventorySimulationSystem remain authoritative. The helper reuses RemoteProductionProjection validation and rebuilds text on each authenticated client observation. Invalid/partial observations and disconnect clear all rows. It owns only presentation text, has no simulation cadence or persistence version, and performs bounded work over the existing projection limits. No new profiling counters are needed.

Recipe prerequisites reflect the existing catalog.v1 iron/plate recipes (1 kg input, 1000 J), observed reach/capability, power and job occupancy. Placement guidance describes host checks without promising a valid pose. Shared stock and wall counts do not identify who produced them. Rejected commands do not advance any checklist; cancellation, consumption, dropping plates and wall removal can reduce displayed facts.

## Verification

Pending focused Windows guide/runtime checks and exact-head CI. No graphical, VR, human usability, release or deployment acceptance is claimed. No image uploads or fixed network test ports are needed for focused owner-driven tests.
