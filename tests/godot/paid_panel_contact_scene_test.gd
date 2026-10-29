extends "res://tests/godot/paid_horizontal_panels_test.gd"

class ContactHost extends FirstPlayableHost:
	var frames: Array[Dictionary] = []
	func _send(_id: int, value: Dictionary) -> void: frames.append(value.duplicate(true))

class ContactSocket extends RefCounted:
	var closed: bool = false
	func close(_code: int, _reason: String = "") -> void: closed = true

class ContactClient extends FirstPlayableBootstrap:
	func _connect_client() -> void: pass

var contact_host: ContactHost
var remote: RemoteWorldRuntime
var scene: PaidPanelContactScene


func run() -> void:
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "real paid owners start")
	runner = world.get_node("SimulationRunner")
	runner.set_physics_process(false)
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
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
	command("panel_build", intent("floor", [0, 800, 0, 1000]))
	var floor_id: String = state().panels.keys()[0]
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	command("panel_build", intent("ceiling", [0, 800, 0, 1000]))
	contact_host = ContactHost.new()
	root.add_child(contact_host)
	contact_host.set_process(false)
	contact_host._world = world
	contact_host._keys = ["contact-actor-00000000000000000000", "contact-target-0000000000000000000"]
	contact_host._peers[1] = {"socket": ContactSocket.new(), "slot": -1}
	contact_host._receive(1, {"type": "authenticate", "key": contact_host._keys[0]})
	remote = RemoteWorldRuntime.new()
	root.add_child(remote)
	remote.set_process(false)
	remote._receive(contact_host.frames[0])
	scene = PaidPanelContactScene.new()
	root.add_child(scene)
	scene.bind(remote)
	var complete: Dictionary = publish()
	check(scene._bodies.size() == 2 and complete.production.horizontal_panels.surfaces.size() == 1, "real host and remote deliver complete geometry for both builders, own picking projection stays private")
	check(not JSON.stringify(complete.panel_contact).contains("principal_id") and not JSON.stringify(complete.panel_contact).contains("materials") and not JSON.stringify(complete.panel_contact).contains("session_id"), "contact observation excludes principals, materials and sessions")
	var first_body: StaticBody3D = scene._bodies[floor_id]
	publish()
	check(scene._bodies[floor_id] == first_body, "unchanged complete content retains body only within live lifecycle")
	# A real character, no fixture floors or habitat shell can mask these probes.
	var character := LocalHabitatCharacter.new()
	root.add_child(character)
	character.read_local_keyboard = false
	character.set_physics_process(false)
	await physics_frame
	await physics_frame
	var origin: Vector3 = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN
	character.position = origin + Vector3(0.4, 0.95, 0.5)
	var floor_hit: KinematicCollision3D = character.move_and_collide(Vector3(0, -0.2, 0))
	check(floor_hit != null and floor_hit.get_collider() == scene._bodies[floor_id] and floor_hit.get_normal().y > 0.99, "PhysicsServer CharacterBody capsule contacts paid floor top")
	character.position = origin + Vector3(0.4, 0.95, 0.5)
	var ceiling_hit: KinematicCollision3D = character.move_and_collide(Vector3(0, 0.3, 0))
	check(ceiling_hit != null and ceiling_hit.get_normal().y < -0.99, "same capsule contacts foreign-builder ceiling underside")
	var preview := HorizontalPanelPreview.new()
	root.add_child(preview)
	preview.observe(complete.production)
	check(preview._panels[floor_id].position == origin + Vector3(0.4, -0.006, 0.5), "own visual mesh and picking match exact floor solid center")
	var saved: String = world.capture_world_snapshot_json().value
	var original: Dictionary = state()
	var before_generation: int = production.collision_restore_generation()
	var changed: Dictionary = original.duplicate(true)
	changed.panels[floor_id].bounds_millimetres = [0, 1000, 0, 800]
	check(production.restore_snapshot_record(changed, runner.tick_number).is_success, "direct Production restore accepted")
	var restored: Dictionary = publish()
	check(restored.panel_contact.geometry.production_revision == complete.panel_contact.geometry.production_revision and restored.panel_contact.production_restore == before_generation + 1, "same revision direct restore has trusted distinct owner fence")
	check(scene._boxes != complete.panel_contact.geometry.boxes and scene._bodies[floor_id] != first_body, "same revision changed shape retires old physics body")
	preview.observe(restored.production)
	check(preview._panels[floor_id].position == origin + Vector3(0.5, -0.006, 0.4), "same stable ID preview restore updates dimensions and center")
	var failed: Dictionary = state().duplicate(true)
	failed.panels[floor_id].materials.plate += 1
	check(not production.restore_snapshot_record(failed, runner.tick_number).is_success and production.collision_restore_generation() == before_generation + 1, "failed restore cannot mutate owner lifecycle")
	world.stop_simulation()
	var retired: WorldRuntime = world
	world = WorldRuntime.new()
	world.resource_carriers_enabled = true
	root.add_child(world)
	check(world.restore_world_snapshot_json(saved).is_success, "atomic world restore on fresh runtime as required by runner")
	contact_host._world = world
	contact_host._publish(1)
	check(contact_host._peers[1].socket.closed, "bound runtime replacement closes old authenticated host binding")
	remote._connecting = true
	remote._process(0)
	check(scene._bodies.is_empty(), "replacement disconnect clears old scene before reconnect")
	contact_host.free()
	retired.free()
	production = world.get_simulation_system(ProductionSimulationSystem.SYSTEM_ID)
	inventory = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	runner = world.get_node("SimulationRunner")
	world.command_completed.connect(func(_command: SimulationCommand, result: ServiceResult) -> void: last = result)
	check(world.start_simulation().is_success, "restored world resumes")
	runner.set_physics_process(false)
	contact_host = ContactHost.new()
	root.add_child(contact_host)
	contact_host.set_process(false)
	contact_host._world = world
	contact_host._keys = ["contact-actor-00000000000000000000", "contact-target-0000000000000000000"]
	contact_host._peers[1] = {"socket": ContactSocket.new(), "slot": -1}
	contact_host._receive(1, {"type": "authenticate", "key": contact_host._keys[0]})
	remote._connection_generation += 1
	remote._contact_sequence = 0
	remote._contact_fences = [0, 0]
	remote._receive(contact_host.frames[0])
	var atomic: Dictionary = publish()
	check(atomic.panel_contact.inventory_restore > complete.panel_contact.inventory_restore and atomic.panel_contact.production_restore > complete.panel_contact.production_restore and scene._boxes == complete.panel_contact.geometry.boxes, "atomic restore initializes both owner fences and fresh connection reinstalls geometry")
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	command("panel_remove", {"panel_id": floor_id})
	publish()
	await physics_frame
	await physics_frame
	character.position = origin + Vector3(0.4, 0.95, 0.5)
	check(character.move_and_collide(Vector3(0, -0.2, 0)) == null and scene._bodies.size() == 1, "removal retires actual floor contact while preserving foreign ceiling")
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	command("panel_remove", {"panel_id": state().panels.keys()[0]})
	var empty: Dictionary = publish()
	check(scene._bodies.is_empty(), "valid complete empty snapshot clears all solids")
	# Restore useful geometry before each lifecycle negative.
	original["last_tick"] = runner.tick_number
	var reinstated: ServiceResult = production.restore_snapshot_record(original, runner.tick_number)
	check(reinstated.is_success, "restore geometry for lifecycle negatives: " + reinstated.message)
	if not reinstated.is_success:
		finish()
		return
	publish()
	scene._physics_process(0.6)
	check(scene._bodies.is_empty(), "expired publication clears contact")
	publish()
	scene.position.x = 1.0
	scene._physics_process(0.01)
	check(scene._bodies.is_empty(), "nonidentity global parent transform clears contact")
	scene.position = Vector3.ZERO
	publish()
	remote.region_id = &"wrong-region"
	scene._physics_process(0.01)
	check(scene._bodies.is_empty(), "scope mutation cannot retain bodies")
	remote.region_id = world.region_id
	publish()
	var current: Dictionary = contact_host.frames.back().duplicate(true)
	remote._receive(current)
	check(scene._bodies.is_empty() and not remote._authenticated, "repeated sequence rejects and immediately clears contact")
	remote._receive(current)
	check(scene._bodies.is_empty(), "payload cannot revive invalidated authentication")
	# Transport generation comes from the local connection, never this frame.
	remote._connection_generation += 1
	remote._contact_sequence = 0
	remote._contact_fences = [0, 0]
	remote._receive(contact_host.frames[0])
	remote._receive_from_transport(current, remote._connection_generation - 1)
	check(scene._bodies.is_empty() and remote._contact_sequence == 0, "queued prior-connection packet cannot revive new authenticated binding")
	publish()
	check(scene._bodies.size() == 2, "fresh current transport may install freshly derived geometry")
	remote._connecting = true
	remote._process(0)
	check(scene._bodies.is_empty() and not remote._authenticated, "actual disconnected transport clears contact immediately")
	remote._connecting = false
	remote._receive(contact_host.frames[0])
	publish()
	for field in ["sequence", "production_restore", "inventory_restore"]:
		for value in [-1, true, 0.5, PaidPanelContactObservation.MAX_INTEGER + 1]:
			var invalid: Dictionary = current.panel_contact.duplicate(true)
			invalid[field] = value
			check(not PaidPanelContactObservation.decode(invalid, world.world_id, world.region_id).is_success, "bounded strict lifecycle field rejects " + field)
	var invalid: Dictionary = current.panel_contact.duplicate(true)
	if invalid.geometry.boxes.is_empty():
		check(false, "lifecycle fixture must contain geometry before box mutation")
		finish()
		return
	invalid.geometry.boxes[0].size_millimetres[0] = 51
	check(not PaidPanelContactObservation.decode(invalid, world.world_id, world.region_id).is_success, "off-grid solid rejects")
	invalid = current.panel_contact.duplicate(true)
	invalid.geometry.boxes[0].principal_id = "forbidden"
	check(not PaidPanelContactObservation.decode(invalid, world.world_id, world.region_id).is_success, "foreign identity fields reject")
	invalid = current.duplicate(true)
	invalid.panel_contact.production_restore = 0
	invalid.panel_contact.sequence = remote._contact_sequence + 1
	remote._receive(invalid)
	check(scene._bodies.is_empty() and not remote._authenticated, "restore fence regression clears actual client scene")
	remote._receive(contact_host.frames[0])
	var mixed: Dictionary = publish()
	mixed.panel_contact.sequence = remote._contact_sequence + 1
	mixed.panel_contact.geometry.production_revision += 1
	remote._receive(mixed)
	check(scene._bodies.is_empty() and not remote._authenticated, "mixed Production observation and contact provenance fails closed")
	contact_host._peers[1].contact_sequence = PaidPanelContactObservation.MAX_INTEGER
	check(not contact_host._panel_contact_snapshot(1, contact_host._context(0, 1), state().state_revision).is_success, "host sequence exhaustion cannot wrap")
	contact_host._peers[1].contact_sequence = 0
	var generation: int = production.collision_restore_generation()
	production._collision_restore_generation = ProductionSimulationSystem.MAX_REVISION
	check(not production.validate_snapshot_record(state(), runner.tick_number).is_success and not production.restore_snapshot_record(state(), runner.tick_number).is_success, "restore exhaustion rejects before mutation in validation and apply")
	production._collision_restore_generation = generation
	var replacement := WorldRuntime.new()
	root.add_child(replacement)
	contact_host._world = replacement
	check(not contact_host._panel_contact_snapshot(1, contact_host._context(0, 1), state().state_revision).is_success, "owner instance replacement fails closed")
	contact_host._world = world
	replacement.free()
	var fixture := FileAccess.open("res://var/paid-panel-contact-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"complete": complete.panel_contact, "restored": restored.panel_contact, "atomic": atomic.panel_contact, "empty": empty.panel_contact}))
	fixture.close()
	contact_host._peers[1].contact_sequence = 0
	var client := ContactClient.new()
	root.add_child(client)
	client._remote.set_process(false)
	client._remote._receive(contact_host.frames[0])
	contact_host._publish(1)
	client._remote._receive(JSON.parse_string(JSON.stringify(contact_host.frames.back())))
	var installed: PaidPanelContactScene
	for child in client._habitat.get_children():
		if child is PaidPanelContactScene: installed = child
	check(installed != null and installed._bodies.size() == 2, "actual playable bootstrap binds complete authenticated contact observation into viewport scene")
	client.free()
	preview.free()
	character.free()
	scene.free()
	remote.free()
	contact_host.free()
	print("Paid panel scene contact: %d failures" % failures)
	finish()


func publish() -> Dictionary:
	contact_host._publish(1)
	var frame: Dictionary = contact_host.frames.back().duplicate(true)
	remote._receive_from_transport(JSON.parse_string(JSON.stringify(frame)), remote._connection_generation)
	return frame
