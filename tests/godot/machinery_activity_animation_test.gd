extends "res://tests/godot/machinery_runtime_test.gd"


func finish() -> void:
	var extractor: String = ""
	var workshop: Dictionary = production.capture_snapshot().value["machinery"]
	for module in workshop["mounts"]:
		if workshop["parts"][module]["kind"] == "extractor": extractor = workshop["mounts"][module]
	move([-6000, 0, -1000])
	command("machine_run", {"machine_id": extractor, "recipe": "extract.ice"})
	var helper := MachineryActivityAnimation.new()
	var first: Dictionary = production.observation(context).value
	check(helper.observe(first) and helper.state(extractor) == "unknown", "accepted job alone does not certify running")
	step(8)
	var running: Dictionary = production.observation(context).value
	check(helper.observe(running) and helper.state(extractor) == "running", "paid finite extraction advancing observation earns motion")
	var snapshot: String = world.capture_world_snapshot_json().value
	var record_bytes: String = JSON.stringify(running)
	# Detached, schema-valid contradictory observations exercise conservative edges.
	var edge := MachineryActivityAnimation.new()
	edge.observe(first)
	edge.observe(running)
	var unchanged: Dictionary = running.duplicate(true)
	unchanged["last_tick"] += 1
	check(edge.observe(unchanged) and edge.state(extractor) == "blocked", "new tick without progress stops motion")
	var regressed: Dictionary = unchanged.duplicate(true)
	regressed["last_tick"] += 1
	regressed["machinery"]["jobs"][extractor]["progress"] = 0
	check(edge.observe(regressed) and edge.state(extractor) == "unknown", "regressed job cannot be treated as continuation")
	var replaced: Dictionary = regressed.duplicate(true)
	replaced["last_tick"] += 1
	replaced["machinery"]["jobs"][extractor]["recipe"] = "refine.iron"
	check(edge.observe(replaced) and edge.state(extractor) == "unknown", "different recipe cannot inherit prior activity")
	var same_tick: Dictionary = running.duplicate(true)
	var conflicting := MachineryActivityAnimation.new()
	conflicting.observe(first)
	conflicting.observe(running)
	same_tick["machinery"]["jobs"][extractor]["progress"] += 1
	check(conflicting.observe(same_tick) and conflicting.state(extractor) == "unknown", "changed same-tick job is not fresh progress evidence")
	var broken: Dictionary = running.duplicate(true)
	for physical in broken["machinery"]["inventory_items"]:
		if physical["item_id"] == extractor: physical["condition_permille"] = 0
	check(conflicting.observe(broken) and conflicting.state(extractor) == "blocked", "broken retained frame freezes even with earlier progress")
	helper.advance(0.05)
	check(helper.phase(extractor) > 0.0, "observed running moves cosmetic phase")
	var partitioned := MachineryActivityAnimation.new()
	partitioned.observe(first)
	partitioned.observe(running)
	partitioned.advance(0.025)
	partitioned.advance(0.025)
	check(is_equal_approx(partitioned.phase(extractor), helper.phase(extractor)), "normal frame partition has equal phase")
	var phase: float = helper.phase(extractor)
	for delta in [NAN, INF, -INF, -1.0, 0.0]: helper.advance(delta)
	check(helper.phase(extractor) == phase and is_finite(helper.phase(extractor)), "nonfinite and nonpositive deltas cannot corrupt transforms")
	helper.advance(0.5)
	check(is_equal_approx(helper.phase(extractor), phase + 0.1 * TAU), "large valid frame delta clamps cosmetic motion")
	helper.observe(running)
	helper.advance(0.5)
	check(helper.state(extractor) == "unknown", "duplicate tick cannot renew expired evidence")
	phase = helper.phase(extractor)
	helper.advance(1000000.0)
	check(helper.phase(extractor) == phase, "long gap expires before animating")
	check(world.capture_world_snapshot_json().value == snapshot and JSON.stringify(running) == record_bytes, "animation never changes canonical snapshot or source observation")
	var visual_root := Node3D.new()
	root.add_child(visual_root)
	var parts: Dictionary = MachineryActivityParts.build(visual_root, ["extractor", "refinery"])
	check(parts["rotors"].size() == 2 and visual_root.find_children("*", "CollisionObject3D", true, false).is_empty(), "cosmetic rotor/indicator only")
	for sample in range(100):
		MachineryActivityParts.present(parts, float(sample) * TAU / 100.0, helper.indicator(extractor))
		for rotor in parts["rotors"]:
			check(rotor.transform.is_finite(), "finite rotor transform")
			for visual in rotor.get_children():
				var bounds: AABB = rotor.transform * visual.transform * visual.get_aabb()
				check(bounds.position.x >= -0.4 and bounds.end.x <= 0.4 and bounds.position.z >= -0.4 and bounds.end.z <= 0.4 and bounds.position.y >= -0.4 and bounds.end.y <= 0.95, "all animated extremes inside unchanged frame envelope")
	var held: Transform3D = parts["rotors"][0].transform
	MachineryActivityParts.present(parts, NAN, Color.RED)
	check(parts["rotors"][0].transform == held, "nonfinite presentation phase rejected")
	visual_root.free()
	command("machine_enable", {"machine_id": extractor, "enabled": false})
	check(helper.observe(production.observation(context).value) and helper.state(extractor) == "blocked", "host isolation freezes")
	step(8)
	helper.observe(production.observation(context).value)
	helper.advance(0.1)
	check(helper.phase(extractor) == phase, "blocked job stays still")
	var paused_world := WorldRuntime.new()
	paused_world.resource_carriers_enabled = true
	root.add_child(paused_world)
	check(paused_world.restore_world_snapshot_json(world.capture_world_snapshot_json().value).is_success, "real restart restore accepted")
	var paused_production: ProductionSimulationSystem = paused_world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	var paused: Dictionary = paused_production.observation(context).value
	check(helper.observe(paused) and helper.state(extractor) == "paused", "actual restored paused job freezes")
	helper.advance(0.1)
	check(helper.phase(extractor) == phase, "paused transform stays still")
	paused_world.free()
	check(not helper.observe({}) and helper.state(extractor) == "unknown", "disconnect forgets evidence")
	helper.advance(0.1)
	check(helper.phase(extractor) == phase, "disconnect freezes retained cosmetic pose")
	helper.observe(production.observation(context).value)
	command("machine_enable", {"machine_id": extractor, "enabled": true})
	step(8)
	helper.observe(production.observation(context).value)
	step(8)
	helper.observe(production.observation(context).value)
	check(helper.state(extractor) == "running", "fresh progress after reconnect earns motion again")
	step(180)
	var completed: Dictionary = production.observation(context).value
	check(not completed["machinery"]["jobs"].has(extractor), "actual finite paid job completed")
	helper.observe(completed)
	check(helper.state(extractor) == "outcome_unknown", "completed host job disappearance never fabricates completion certificate")
	command("machine_run", {"machine_id": extractor, "recipe": "extract.ice"})
	helper.observe(production.observation(context).value)
	command("machine_cancel", {"machine_id": extractor})
	helper.observe(production.observation(context).value)
	check(helper.state(extractor) == "outcome_unknown", "actual cancellation also remains outcome-unconfirmed")
	check(not helper.observe(first) and helper.state(extractor) == "unknown", "older tick discards activity")
	var malformed: Dictionary = completed.duplicate(true)
	malformed["machinery"]["jobs"] = "invalid"
	check(not helper.observe(malformed), "malformed observation discarded without motion")
	world.free()
	print("Machinery activity animation: %d failures" % failures)
	quit(1 if failures else 0)
