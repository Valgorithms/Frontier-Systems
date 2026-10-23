extends "res://tests/godot/paid_horizontal_panels_test.gd"

var environment: Dictionary
var equipment: Dictionary = {"magnetic_surface": false, "mag_boots_enabled": false, "mag_boots_powered": true, "mag_boots_condition_permille": 1000, "jetpack_enabled": false, "jetpack_powered": true, "jetpack_condition_permille": 1000, "propellant_milligrams": 1000}


func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "finite world starts")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	environment = JSON.parse_string(FileAccess.get_file_as_string("res://data/locomotion/station-space.v1.json"))
	check(not assessment()["supported"], "default fixture center at y0 is not silently interpreted as sole")
	for batch in range(6):
		move([-3000, 0, -1000])
		command("extract", {"deposit_id": "deposit.iron", "carrier_id": "resource-canister-1", "amount_milligrams": 1000000})
		move([0, 0, 0])
		command("unload_cargo", {"carrier_id": "resource-canister-1", "material": "ore.iron", "amount_milligrams": 1000000})
		command("process", {"recipe_id": "refine.iron"})
		step(120)
	for index in range(2):
		command("process", {"recipe_id": "craft.plate"})
		step(120)
	command("canister_reserve", {"job_id": "support-neighbor", "expected_reservation_revision": state()["construction"]["revision"], "control_epoch": 0})
	var claims: int = ConstructionReservationPlan.claimed(state()["construction"])
	command("panel_build", intent("floor", [0, 500, 0, 1000]))
	var left: String = state()["panels"].keys()[0]
	command("panel_build", intent("floor", [500, 1000, 0, 1000]))
	var right: String = ""
	for id in state()["panels"]:
		if id != left: right = id
	check(state()["store"]["plate"] == 1000000 and HorizontalPanelConstruction.mass(state()["panels"]) == 1000000, "two half floors consume exactly one finite kg")
	move([500, 900, 500])
	var before: Dictionary = state()
	var inventory_before: Dictionary = inventory.capture_snapshot().value
	var supported: Dictionary = assessment()
	check(supported["supported"] and supported["locomotion"]["locomotion_mode"] == "gravity_supported", "adjacent paid floors jointly support explicit human feet")
	check(supported["production_revision"] == before["state_revision"] and supported["production_tick"] == before["last_tick"] and supported["inventory_tick"] == inventory_before["last_tick"], "current owner revision and ticks returned")
	check(assessment() == supported and state() == before and inventory.capture_snapshot().value == inventory_before, "assessment deterministic and owners unchanged")
	check(not JSON.stringify(supported).contains(left) and not JSON.stringify(supported).contains(String(context.principal_id)), "outward aggregate contains no builder IDs or panel IDs")
	var saved: String = world.capture_world_snapshot_json().value
	move([950, 900, 500])
	check(not assessment()["supported"], "canonical pose overhang rejects despite interior center")
	check(assessment()["body_action_epoch"] > supported["body_action_epoch"], "prior pose result is not retained")
	move([500, 899, 500])
	check(not assessment()["supported"], "feet below floor reject")
	move([500, 911, 500])
	check(not assessment()["supported"], "feet above tolerance reject")
	move([500, 910, 500])
	check(assessment()["supported"], "inclusive10mm tolerance")
	move([500, 900, 500])
	for extra in [{"surface_contact": true}, {"surfaces": []}, {"production_revision": supported["production_revision"]}, {"position_millimetres": [500, 900, 500]}, {"supported": true}]:
		var forged: Dictionary = equipment.duplicate(true)
		forged.merge(extra)
		check(not production.resolve_paid_floor_locomotion(context, environment, forged).is_success, "forged contact, stale result, descriptors or pose cannot enter trusted API")
	var actor: AuthenticatedCommandContext = context
	for foreign in [AuthenticatedCommandContext.for_local_development(&"foreign-actor", world.world_id, world.region_id), AuthenticatedCommandContext.for_local_development(actor.principal_id, &"foreign-world", world.region_id), AuthenticatedCommandContext.for_local_development(actor.principal_id, world.world_id, &"foreign-region"), null]:
		check(not production.resolve_paid_floor_locomotion(foreign, environment, equipment).is_success, "foreign actor/scope or absent context rejects")
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	move([500, 900, 500])
	check(assessment()["supported"], "another authorized human can stand on another builder's physical paid floor")
	context = actor
	command("panel_remove", {"panel_id": right})
	check(not assessment()["supported"] and assessment()["production_revision"] > supported["production_revision"], "removed floor invalidates support immediately without cache")
	command("panel_build", intent("floor", [550, 1000, 0, 1000]))
	check(not assessment()["supported"], "50mm gap rejects despite supported footprint corners")
	var gap_id: String = ""
	for id in state()["panels"]:
		if id != left: gap_id = id
	command("panel_remove", {"panel_id": gap_id})
	command("panel_remove", {"panel_id": left})
	check(state()["store"]["plate"] == 2000000, "all finite floor bills refunded exactly")
	move([500, 900, 500])
	command("panel_build", intent("ceiling", [0, 1000, 0, 1000]))
	move([500, 2900, 500])
	check(not assessment()["supported"], "ceiling at exact foot height never supports")
	check(ConstructionReservationPlan.claimed(state()["construction"]) == claims, "support and panel lifecycle preserve unrelated reservations")
	move([5000, 900, 5000])
	check(not assessment()["supported"], "existing movement remains permitted off paid floors")
	move([200000, 900, 0])
	check(not production.resolve_paid_floor_locomotion(context, environment, equipment).is_success, "pose beyond bounded query fails closed")
	world.stop_simulation()
	world.free()
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	var restore: ServiceResult = world.restore_world_snapshot_json(saved)
	check(restore.is_success, "whole world restore restores paid panels and canonical poses: " + restore.message)
	if not restore.is_success:
		finish()
		return
	runner = world.get_node("SimulationRunner")
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	check(world.start_simulation().is_success, "restored world restarts")
	runner.set_physics_process(false)
	check(assessment()["supported"], "restored owner state rederived on demand")
	check(production.validate_snapshot_record(state(), runner.tick_number).is_success, "finite complete state validates after restore")
	# The restored grant is paused by existing rules; this read consumes nothing.
	equipment["mag_boots_enabled"] = true
	check(not assessment()["locomotion"]["magnetic_attachment_available"], "paid plate does not assert magnetic compatibility")
	equipment["magnetic_surface"] = true
	check(assessment()["locomotion"]["locomotion_mode"] == "magnetic_attachment", "trusted compatible equipment uses derived contact")
	equipment["mag_boots_powered"] = false
	equipment["jetpack_enabled"] = true
	environment["generators"][0]["powered"] = false
	check(assessment()["locomotion"]["locomotion_mode"] == "free_motion" and assessment()["locomotion"]["jetpack_thrust_available"], "support does not invent gravity; trusted jetpack remains available")
	equipment["propellant_milligrams"] = 0
	check(not assessment()["locomotion"]["jetpack_thrust_available"], "empty propellant remains unavailable")
	var unsupported: Dictionary
	move([5000, 900, 5000])
	unsupported = assessment()
	var fixture := FileAccess.open("res://var/paid-floor-locomotion-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"supported": supported, "unsupported": unsupported}))
	fixture.close()
	var human_snapshot: Dictionary = inventory.capture_snapshot().value
	for profile in ["cyborg", "station-ai"]:
		var changed: Dictionary = human_snapshot.duplicate(true)
		for body in changed["owner"]["bodies"]:
			if body["body_id"] != "body.human-2": continue
			body["profile_id"] = "inventory.body." + profile
			body["equipped"] = []
			body["active_hand_slot_id"] = "manipulator.left" if profile == "cyborg" else ""
		for item in changed["owner"]["ledger"]["items"]:
			if item["container_id"] == "body.human-2": item["container_id"] = "world.tray-1"
		for container in changed["owner"]["ledger"]["containers"]:
			if container["container_id"] == "body.human-2": container["capacity"]["max_mass_milligrams"] = 80000000 if profile == "cyborg" else 0
		var restored_profile: ServiceResult = inventory.restore_snapshot_record(changed, runner.tick_number)
		check(restored_profile.is_success, "valid canonical nonhuman profile restores: " + profile + ": " + restored_profile.message)
		check(not production.resolve_paid_floor_locomotion(context, environment, equipment).is_success, "nonhuman profile has no capsule support mapping: " + profile)
	check(inventory.restore_snapshot_record(human_snapshot, runner.tick_number).is_success, "human owner restored after profile negatives")
	var unknown: Dictionary = human_snapshot.duplicate(true)
	unknown["owner"]["bodies"][1]["profile_id"] = "inventory.body.unknown"
	check(not inventory.restore_snapshot_record(unknown, runner.tick_number).is_success, "unregistered body profile rejected before assessment")
	print("Paid floor support adapter: %d failures" % failures)
	finish()


func assessment() -> Dictionary:
	var result: ServiceResult = production.resolve_paid_floor_locomotion(context, environment, equipment)
	check(result.is_success, "trusted owner assessment succeeds: " + result.message)
	return result.value if result.is_success else {}
