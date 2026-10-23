extends RefCounted

## Test-only delivery for older socket-free observation fixtures.
static func envelope(world: WorldRuntime, context: AuthenticatedCommandContext) -> Dictionary:
	var production := world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID) as ProductionSimulationSystem
	var inventory := world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID) as InventorySimulationSystem
	return {"schema_version": 1, "world_id": String(world.world_id), "region_id": String(world.region_id), "sequence": 1, "inventory_restore": inventory.controller_restore_generation(), "production_restore": production.collision_restore_generation(), "geometry": production.paid_panel_collision_descriptors(context, production.capture_snapshot().value.state_revision).value}
