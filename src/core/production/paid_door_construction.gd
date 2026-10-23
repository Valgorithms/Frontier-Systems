extends RefCounted
class_name PaidDoorConstruction


static func actuator_id(id: String) -> StringName:
	return StringName("%s-leaf" % id)


static func new_device(id: String, principal: String) -> AccessControlledDeviceState:
	var device := AccessControlledDeviceState.new()
	device.device_id = StringName(id)
	device.access_policy = {"schema_version": 1, "policy_id": "%s-policy" % id, "revision": 1, "default_decision": "deny", "grants": [{"subject_kind": "principal", "subject_id": principal, "action_ids": ["door.manual_operate"]}]}
	var actuator := ActuatorState.new()
	actuator.actuator_id = actuator_id(id)
	actuator.mode = &"manual"
	actuator.latch_state = &"released"
	actuator.manual_override_available = true
	actuator.seal_condition = 0.0
	device.actuators[actuator.actuator_id] = actuator
	return device


static func valid_device(id: String, door: Dictionary, record: Dictionary) -> bool:
	var decoded: ServiceResult = AccessControlledDeviceState.from_record(record)
	if not decoded.is_success: return false
	var device: AccessControlledDeviceState = decoded.value
	var target: ActuatorState = device.actuator(actuator_id(id))
	if device.device_id != StringName(id) or not device.security_controllers.is_empty() or device.actuators.size() != 1 or target == null: return false
	if device.access_policy != new_device(id, door["principal_id"]).access_policy: return false
	# Condition, latch and bypass history remain Access-owned. No hidden hardware.
	return target.mode in [&"manual", &"disabled", &"jammed"] and target.position in [0.0, 1.0] and target.effective_pressure_area_m2 == 0.0 and target.maximum_force_newtons == 0.0 and target.seal_condition == 0.0 and target.manual_override_available


static func links(state: Dictionary, access: Dictionary, inventory: Dictionary = {}) -> ServiceResult:
	var doors: Dictionary = state.get("doors", {})
	if typeof(access.get("devices")) != TYPE_ARRAY: return failure("Missing Access device records.")
	var seen: Dictionary = {}
	for device in access["devices"]:
		if typeof(device) != TYPE_DICTIONARY or typeof(device.get("device_id")) != TYPE_STRING: return failure("Invalid device identity.")
		var id: String = device["device_id"]
		if doors.has(id):
			if seen.has(id) or not valid_device(id, doors[id], device): return failure("Door hardware or ownership differs from its commissioned identity.")
			seen[id] = true
		elif id.begins_with("door-"): return failure("An orphan constructed door device is not allowed.")
	if seen.size() != doors.size(): return failure("Every paid door requires exactly one commissioned Access device.")
	if not inventory.is_empty():
		for d in doors.values():
			var bound: bool = false
			for body in inventory["bodies"]:
				if body["body_id"] == d["body_id"] and body["principal_id"] == d["principal_id"]: bound = true
			if not bound: return failure("Door principal/body binding is missing.")
	return ServiceResult.success()


static func clear_installations(doors: Dictionary, state: Dictionary) -> bool:
	for d in doors.values():
		var envelope: Dictionary = PaidDoorGeometry.sweep(d)
		var center: Vector3 = SpatialWallConstruction.point(envelope["center_millimetres"])
		var half: Vector3 = SpatialWallConstruction.point(envelope["size_millimetres"]) / 2.0
		if not SpatialWallConstruction.fixture_clear(center, half): return false
		for wall in state["walls"].values():
			if SpatialWallConstruction.overlaps(center, half, SpatialWallConstruction.center(wall), SpatialWallConstruction.half_size(wall)): return false
		for id in state["machinery"]["placements"]:
			var p: Dictionary = state["machinery"]["placements"][id]
			if SpatialWallConstruction.overlaps(center, half, MachineryPlacement.center(p["position"]), MachineryPlacement.half_size(state["machinery"], id)): return false
	return true


## Unsupported world roots/grip targets/body profiles fail closed, never guessed.
static func unoccupied(pose: Dictionary, inventory: Dictionary, state: Dictionary) -> bool:
	var envelope: Dictionary = PaidDoorGeometry.sweep(pose)
	var center: Vector3 = SpatialWallConstruction.point(envelope["center_millimetres"])
	var half: Vector3 = SpatialWallConstruction.point(envelope["size_millimetres"]) / 2.0
	for body in inventory["bodies"]:
		var mapped: bool = false
		for binding in inventory["owner"]["bodies"]:
			if binding["body_id"] == body["body_id"] and binding["profile_id"] == "inventory.body.human" and int(binding["profile_revision"]) == 1: mapped = true
		if not mapped or SpatialWallConstruction.overlaps(center, half, SpatialWallConstruction.body_center(body["position_millimetres"]), SpatialWallConstruction.BODY_HALF): return false
	for storage in inventory["world_storage"]:
		if storage["container_id"] == "world.tray-1" and storage["position_millimetres"] == [0, 0, 0]: continue
		var mapped: bool = false
		for machine in state["machinery"]["placements"]:
			var p: Dictionary = state["machinery"]["placements"][machine]
			if MachineryWorkshop.root_id(machine) == storage["container_id"] and p["position"] == storage["position_millimetres"]: mapped = true
		if not mapped: return false
	for session in inventory["grips"]["sessions"]:
		if not InventorySimulationSystem.GRIP_TARGETS.has(session["target_id"]): return false
		var target: Dictionary = InventorySimulationSystem.GRIP_TARGETS[session["target_id"]]
		# Logical targets lack physical dimensions: conservatively reject active grips.
		if not target.is_empty(): return false
	return true


static func plan(state: Dictionary, inventory: InventorySimulationSystem, access: AccessControlSystem, context: AuthenticatedCommandContext, request: String, operation: String, payload: Dictionary) -> ServiceResult:
	var create: bool = operation == "door_build"
	var fields: Array = ["expected_revision", "control_epoch", "position", "quarter_turn"] if create else ["expected_revision", "control_epoch", "door_id"]
	if not ControlContractValidation.has_exact_fields(payload, PackedStringArray(fields)): return failure("An exact door intent is required.")
	var authorized: ServiceResult = inventory.authorize(context, true)
	if not authorized.is_success: return authorized
	var id: Variant = "door-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32) if create else payload["door_id"]
	if not ControlContractValidation.is_id(id): return failure("A stable door identity is required.")
	var doors: Dictionary = state["doors"]
	var device: AccessControlledDeviceState
	var door: Dictionary
	if create:
		if doors.size() >= PaidDoorGeometry.MAX_DOORS or doors.has(id) or access.devices.has(StringName(id)): return failure("Door identity/capacity is unavailable.")
		door = {"position": payload["position"], "quarter_turn": payload["quarter_turn"], "principal_id": String(context.principal_id), "body_id": authorized.value, "blueprint_id": PaidDoorGeometry.BLUEPRINT, "blueprint_revision": 1, "materials": {"plate": PaidDoorGeometry.MASS}}
		doors[id] = door
		if not PaidDoorGeometry.valid(doors, state["panels"]) or int(state["store"]["plate"]) < PaidDoorGeometry.MASS: return failure("A paid supported floor, clear grid pose and two kg processed plate are required.")
		device = new_device(id, String(context.principal_id))
		state["store"]["plate"] -= PaidDoorGeometry.MASS
	else:
		if not doors.has(id): return failure("Select an existing paid door.")
		door = doors[id]
		if door["principal_id"] != String(context.principal_id) or door["body_id"] != authorized.value: return failure("Only the constructing principal/body may operate or recover this door.")
		var current: ServiceResult = access.device_snapshot(StringName(id))
		if not current.is_success or not valid_device(id, door, current.value): return failure("The commissioned door hardware is invalid.")
		device = AccessControlledDeviceState.from_record(current.value).value
		var actuator: ActuatorState = device.actuator(actuator_id(id))
		if operation == "door_remove":
			if actuator.position != 0.0 or not device.bypass_jobs.is_empty() or not device.tamper_events.is_empty() or actuator.override_actor_id != &"": return failure("Close the door and clear foreign work before recovery.")
			if ProductionSimulationSystem._mass(state["store"]) + ProductionSimulationSystem._reserved_mass(state) + PaidDoorGeometry.MASS > ProductionSimulationSystem.MAX_MASS: return failure("Receiving stock capacity is unavailable.")
			state["store"]["plate"] += PaidDoorGeometry.MASS
		else:
			if operation not in ["door_open", "door_close"]: return failure("Unknown door operation.")
			var tool: ServiceResult = inventory.active_tool(context, "tool.crowbar")
			if not tool.is_success: return tool
			var verified := AuthenticatedCommandContext.from_authenticated_session(context.principal_id, context.session_id, context.world_id, context.region_id, PackedStringArray(context.permissions.keys()), {&"tool.pry": PackedStringArray([tool.value])})
			verified.origin = context.origin
			verified.permissions["airlock.manual_operate"] = true
			var can_move: ServiceResult = access.validate_door_actuation(StringName(id), actuator_id(id), operation == "door_open", 0.0, true, verified)
			if not can_move.is_success: return can_move
			actuator.position = 1.0 if operation == "door_open" else 0.0
	var reach: ServiceResult = inventory.production_capability(context, true, door["position"])
	if not reach.is_success: return reach
	if not clear_installations(doors, state) or not unoccupied(door, inventory.capture_snapshot().value, state): return failure("The installation swing is occupied or has an unsupported canonical shape.")
	if operation == "door_remove": doors.erase(id)
	var parsed: ServiceResult = AccessControlledDeviceState.from_record(device.to_record())
	if not parsed.is_success: return parsed
	return ServiceResult.success(PreparedDoorChange.new(access, StringName(id), access.devices.get(StringName(id)), device.to_record(), operation == "door_remove"))


static func failure(message: String) -> ServiceResult:
	return ServiceResult.failure(&"door_construction_denied", message)
