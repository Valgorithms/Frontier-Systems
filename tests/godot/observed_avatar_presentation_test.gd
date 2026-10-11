extends "res://tests/godot/client_inventory_shell_test.gd"

var peer_context: AuthenticatedCommandContext
var observed_tick: int = 0


func crew_frame() -> Dictionary:
	var record: Dictionary = frame()
	var inventory: InventorySimulationSystem = world.get_simulation_system(InventorySimulationSystem.SYSTEM_ID)
	record["position"] = inventory.own_position(context).value
	record["players"] = [{"slot": 0, "position": record["position"]}, {"slot": 1, "position": inventory.own_position(peer_context).value}]
	record["terrain"] = {}
	record["tick_number"] = observed_tick
	return record


func peer_move(coords: Array) -> void:
	sequence += 1
	var request := InventoryDevelopmentCommand.new()
	request.command_id = StringName("avatar-move-%d" % sequence)
	request.authenticated_context = peer_context
	request.operation = "move_to"
	request.payload = {"position_millimetres": coords}
	check(world.enqueue_command(request).is_success, "real peer movement queues")
	step()
	observed_tick = world.current_tick_number()


func present() -> void:
	var snapshot: String = world.capture_world_snapshot_json().value
	var sent: int = remote.sent.size()
	client._on_observation(crew_frame())
	client._habitat.character.set_physics_process(false)
	check(world.capture_world_snapshot_json().value == snapshot and remote.sent.size() == sent, "presentation preserves canonical snapshot and commands")


func run() -> void:
	OS.set_environment("FRONTIER_EVENT_URL", "")
	OS.set_environment("FRONTIER_EVENT_TOKEN", "")
	world = WorldRuntime.new()
	root.add_child(world)
	check(world.start_simulation().is_success, "real world starts")
	world.get_node("SimulationRunner").set_physics_process(false)
	context = AuthenticatedCommandContext.for_local_development(&"local-inventory-actor", world.world_id, world.region_id)
	peer_context = AuthenticatedCommandContext.for_local_development(&"local-inventory-target", world.world_id, world.region_id)
	client = InventoryClient.new()
	root.add_child(client)
	client.set_process(false)
	remote = client._remote
	remote.set_process(false)
	remote.server_slot = 0
	peer_move([0, 950, -2000])
	present()
	check(client._avatars.size() == 1 and not client._avatars.has(0), "crew slot identity and self exclusion preserved")
	var avatar: ObservedAvatarPresentation = client._avatars[1]
	avatar.set_process(false)
	check(avatar._phase == 0.0 and avatar.get_child_count() == 5, "first observation neutral original geometry")
	await capture_pose(avatar, "neutral")
	check(avatar.find_children("*", "CollisionObject3D", true, false).is_empty(), "geometry adds no collision/picking")
	peer_move([150, 950, -2000])
	present()
	check(avatar._phase > 0.0 and absf(avatar._limbs[0].rotation.x) > 0.1, "actual observed displacement poses limbs")
	await capture_pose(avatar, "moving")
	check(avatar.position == ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(0.15, 0.95, -2.0), "observed display position unchanged")
	var pose: float = avatar._phase
	avatar._process(0.1)
	check(avatar._phase == pose, "render frames never advance gait")
	var position: Vector3 = avatar.position
	avatar.observe_position([500, 950, -2000], observed_tick)
	avatar.observe_position([500, 950, -2000], observed_tick - 1)
	avatar.observe_position(["bad", 950, -2000], observed_tick + 1)
	avatar.observe_position([NAN, 950, -2000], observed_tick + 1)
	check(avatar.position == position and avatar._age == 0.1, "duplicate/regressing/malformed observations neither move nor refresh")
	avatar._process(0.4)
	check(avatar._phase == 0.0 and avatar._limbs[0].rotation.x == 0.0, "stale neutralization")
	peer_move([300, 950, -2000])
	present()
	check(avatar._phase == 0.0, "first post-stale sample has no inferred walk")
	peer_move([450, 950, -2000])
	present()
	check(avatar._phase > 0.0, "fresh subsequent motion resumes")
	step()
	observed_tick = world.current_tick_number()
	present()
	check(avatar._phase == 0.0, "fresh stationary tick neutralizes")
	peer_move([450, 1100, -2000])
	present()
	check(avatar._phase == 0.0, "vertical motion cannot invent walking")
	peer_move([2000, 950, -2000])
	present()
	check(avatar._phase == 0.0, "large correction does not invent stride")
	client._on_connection_closed("Fixture disconnect")
	check(client._avatars.is_empty() and avatar.is_queued_for_deletion(), "disconnect retains removal contract")
	present()
	check(client._avatars[1] != avatar and client._avatars[1]._phase == 0.0, "reconnect creates neutral baseline")
	var missing: Dictionary = crew_frame()
	missing["players"] = []
	client._on_observation(missing)
	check(client._avatars.is_empty(), "missing peer removes geometry")
	client.free()
	world.free()
	PlayerInputSettings.instance().release_all()
	await process_frame
	print("Observed avatar: %d failures; real world no ports; no human locomotion acceptance" % failures)
	quit(1 if failures else 0)


func capture_pose(_avatar: ObservedAvatarPresentation, _label: String) -> void:
	pass
