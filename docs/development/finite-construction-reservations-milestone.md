# Finite construction reservation foundation

Status: detached contract in development; no runtime integration or playable queue.

Scope is one trusted `equipment.canister` blueprint from `data/production/equipment-blueprints.v1.json`: one fabricated canister shell costs 1,000,000 mg iron. Production remains the only material owner, Inventory owns physical items and child containers. New reservation plans must be committed with those owners, never used as a second material store.

Owned files: `src/core/production/construction_reservation_plan.gd`, `tests/godot/construction_reservation_plan_test.gd`, `docs/schema/construction-reservation-v1.schema.json`, and this milestone. Existing runtime owners, schemas, CI, topology and presentation remain outside scope.

Acceptance: deterministic bounded work, actor/revision checks, interrupt/resume/cancel, retained idempotent receipts, competing claims, conserved completion/cancellation in an executable transaction fixture, and serialized restore. Integration requires an exclusive owner change before any queue is exposed.
