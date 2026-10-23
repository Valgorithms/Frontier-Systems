extends RefCounted

## Test-only delivery for older socket-free observation fixtures.
static func envelope(world: WorldRuntime, context: AuthenticatedCommandContext) -> Dictionary:
	var production := world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID) as ProductionSimulationSystem
	var inventory := world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID) as InventorySimulationSystem
	return {"schema_version": 1, "world_id": String(world.world_id), "region_id": String(world.region_id), "sequence": 1, "inventory_restore": inventory.controller_restore_generation(), "production_restore": production.collision_restore_generation(), "geometry": production.paid_panel_collision_descriptors(context, production.capture_snapshot().value.state_revision).value}


static func door_envelope(world: WorldRuntime, context: AuthenticatedCommandContext) -> Dictionary:
	var panel: Dictionary = envelope(world, context)
	var production: ProductionSimulationSystem = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	return {"schema_version": 1, "world_id": panel.world_id, "region_id": panel.region_id, "sequence": panel.sequence, "inventory_restore": panel.inventory_restore, "production_restore": panel.production_restore, "production_revision": panel.geometry.production_revision, "production_tick": panel.geometry.production_tick, "inventory_tick": panel.geometry.inventory_tick, "boxes": production.door_solids().value}
