extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func snapshots(owners: Array) -> Array:
	var result: Array = []
	for owner in owners:
		var snapshot: ServiceResult = owner.capture_snapshot()
		check(snapshot.is_success, "real owner snapshot available")
		result.append(snapshot.value.duplicate(true) if snapshot.is_success else {})
	return result


func run() -> void:
	for mutation in ["none", "bank", "gas", "valve", "access", "production_restore", "pressure_restore", "inventory_restore", "access_restore", "identity"]:
		var world: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
		root.add_child(world)
		check(world.start_simulation().is_success, "real factory starts for " + mutation)
		world.get_node("SimulationRunner").set_physics_process(false)
		var production: ProductionSimulationSystem = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
		var pressure: PressureSystem = world.get_simulation_system(PressureSystem.SYSTEM_ID)
		var inventory: InventorySimulationSystem = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
		var access: AccessControlSystem = world.get_simulation_system(AccessControlSystem.SYSTEM_ID)
		var owners: Array = [production, pressure, inventory, access]
		var captured: ServiceResult = ChamberRecoveryOwnerFence.capture(production, pressure, inventory, access)
		check(captured.is_success, "capture real owner fence")
		if not captured.is_success:
			world.free()
			continue
		var fence: ChamberRecoveryOwnerFence = captured.value
		var baseline: Array = snapshots(owners)
		# Isolated failure injection mutates real owners, without runtime fault hooks.
		match mutation:
			"bank":
				var changed: Dictionary = baseline[0].duplicate(true)
				changed.energy_joules -= 1
				check(production.restore_snapshot_record(changed, int(changed.last_tick)).is_success, "real Production accepts lower finite bank")
			"gas":
				(pressure.volumes[PressureSystem.PROTOTYPE_HABITAT_ID] as PressureVolumeState).gas_moles -= 0.1
			"valve":
				(pressure.airlocks[&"habitat_airlock"] as AirlockState).equalization_valve_open = true
			"access":
				var device: AccessControlledDeviceState = access.devices[&"habitat_airlock"]
				device.actuator(&"habitat_airlock-inner-door").position = 1.0
			"production_restore": check(production.restore_snapshot_record(baseline[0], int(baseline[0].last_tick)).is_success, "Production restore succeeds")
			"pressure_restore": check(pressure.restore_snapshot_record(baseline[1], 0).is_success, "identical Pressure restore succeeds")
			"inventory_restore": check(inventory.restore_snapshot_record(baseline[2], 0).is_success, "identical Inventory restore succeeds")
			"access_restore": check(access.restore_snapshot_record(baseline[3], 0).is_success, "identical Access restore succeeds")
		var immediately_before: Array = snapshots(owners)
		var other_pressure: PressureSystem = PressureSystem.new() if mutation == "identity" else pressure
		var taken: ServiceResult = fence.take(production, other_pressure, inventory, access)
		check(taken.is_success == (mutation == "none"), "only unchanged exact owners pass: " + mutation)
		check(snapshots(owners) == immediately_before, "take changes no canonical records or receipts: " + mutation)
		check(not fence.take(production, pressure, inventory, access).is_success, "both success and rejection consume only the ephemeral fence: " + mutation)
		check(snapshots(owners) == immediately_before, "second take also changes no canonical state: " + mutation)
		if other_pressure != pressure: other_pressure.free()
		world.free()
	var exhausted: WorldRuntime = FirstPlayableBootstrap.create_playable_world()
	root.add_child(exhausted)
	var production: ProductionSimulationSystem = exhausted.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var pressure: PressureSystem = exhausted.get_simulation_system(PressureSystem.SYSTEM_ID)
	var inventory: InventorySimulationSystem = exhausted.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	var access: AccessControlSystem = exhausted.get_simulation_system(AccessControlSystem.SYSTEM_ID)
	# Test-only counter seeding checks the actual successful-restore increment and
	# fail-closed terminal value, without adding runtime injection interfaces.
	production._collision_restore_generation = ProductionSimulationSystem.MAX_REVISION - 1
	pressure._room_restore_generation = ChamberRecoveryRecords.LIMIT - 1
	inventory._controller_restore_generation = InventorySimulationSystem.MAX_EXACT_INTEGER - 1
	access._restore_generation = ChamberRecoveryRecords.LIMIT - 1
	var owners: Array = [production, pressure, inventory, access]
	for owner in owners:
		var before: Dictionary = owner.capture_snapshot().value.duplicate(true)
		check(owner.restore_snapshot_record(before, 0).is_success, "last representable restore advances its real fence")
		check(not owner.validate_snapshot_record(before, 0).is_success, "exhausted fence rejects whole-world prevalidation")
		check(not owner.restore_snapshot_record(before, 0).is_success and owner.capture_snapshot().value == before, "exhausted restore cannot wrap or mutate canonical records")
	exhausted.free()
	quit(failures)
