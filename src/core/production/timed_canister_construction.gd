extends RefCounted
class_name TimedCanisterConstruction

## Workbench-only policy. Material and physical records remain in their owners.
## Read-only current control data is not a grant. Ingress resolves it again.
static func observation(state: Dictionary, inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, fingerprint: String) -> Dictionary:
	var actor: ServiceResult = inventory.authorize(context)
	var bodies: Dictionary = inventory.controller_candidate().value
	var body: Dictionary = bodies[actor.value]
	var can_operate: bool = inventory.production_capability(context).is_success
	var result: Dictionary = {"blueprint_fingerprint": fingerprint, "revision": state["construction"]["revision"], "control_epoch": body["control_epoch"], "can_operate": can_operate, "can_start": false, "jobs": {}}
	var unfinished: bool = false
	for id in state["construction"]["jobs"]:
		var previous: Dictionary = state["construction_bindings"][id]
		if previous["actor_id"] != String(context.principal_id) or previous["body_id"] != actor.value or previous["world_id"] != String(context.world_id) or previous["region_id"] != String(context.region_id): continue
		var job: Dictionary = state["construction"]["jobs"][id]
		result["jobs"][id] = {"state": job["state"], "progress_ticks": job["progress_ticks"]}
		if job["state"] not in ["cancelled", "completed"]: unfinished = true
	result["can_start"] = can_operate and not unfinished and int(state["timebase_hz"]) == 60 and state["powered"]["printer"] and int(state["store"]["iron"]) - ConstructionReservationPlan.claimed(state["construction"]) >= ConstructionReservationPlan.BILL and state["construction"]["jobs"].size() < ConstructionReservationPlan.MAX_JOBS and state["construction_commands"].size() < 128
	return result


static func valid_observation(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["blueprint_fingerprint", "revision", "control_epoch", "can_operate", "can_start", "jobs"])): return false
	if typeof(value["blueprint_fingerprint"]) != TYPE_STRING or value["blueprint_fingerprint"].length() != 64: return false
	for character in value["blueprint_fingerprint"]:
		if not "0123456789abcdef".contains(character): return false
	for field in ["revision", "control_epoch"]:
		if not ControlContractValidation.is_integer(value[field], 0, ProductionSimulationSystem.MAX_REVISION): return false
	if typeof(value["can_operate"]) != TYPE_BOOL or typeof(value["can_start"]) != TYPE_BOOL or (value["can_start"] and not value["can_operate"]): return false
	if typeof(value["jobs"]) != TYPE_DICTIONARY or value["jobs"].size() > ConstructionReservationPlan.MAX_JOBS: return false
	for id in value["jobs"]:
		var job: Variant = value["jobs"][id]
		if not ControlContractValidation.is_id(id) or typeof(job) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(job, PackedStringArray(["state", "progress_ticks"])): return false
		if not job["state"] in ConstructionReservationPlan.STATES or not ControlContractValidation.is_integer(job["progress_ticks"], 0, ConstructionReservationPlan.WORK_TICKS): return false
		if job["state"] in ["ready", "completed"] and int(job["progress_ticks"]) != ConstructionReservationPlan.WORK_TICKS: return false
		if value["can_start"] and job["state"] in ["active", "paused", "ready"]: return false
	return true


static func output_id(job_id: String) -> String:
	return "reserved-canister-%s" % job_id.sha256_text().substr(0, 24)


static func covered(state: Dictionary) -> bool:
	return typeof(state.get("construction")) == TYPE_DICTIONARY and ConstructionReservationPlan.valid(state["construction"]) and typeof(state.get("store")) == TYPE_DICTIONARY and ControlContractValidation.is_integer(state["store"].get("iron"), 0, ProductionSimulationSystem.MAX_MASS) and int(state["store"]["iron"]) >= ConstructionReservationPlan.claimed(state["construction"])


static func binding(inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, fingerprint: String) -> ServiceResult:
	var authorized: ServiceResult = inventory.production_capability(context)
	if not authorized.is_success: return authorized
	var controllers: ServiceResult = inventory.controller_candidate()
	if not controllers.is_success: return controllers
	var body: Dictionary = controllers.value[authorized.value]
	return ServiceResult.success({"actor_id": String(context.principal_id), "body_id": authorized.value, "control_epoch": body["control_epoch"], "world_id": String(context.world_id), "region_id": String(context.region_id), "fingerprint": fingerprint})


static func valid(state: Dictionary, blueprint: Dictionary) -> bool:
	if not covered(state) or typeof(state["construction_bindings"]) != TYPE_DICTIONARY: return false
	var jobs: Dictionary = state["construction"]["jobs"]
	if jobs.size() != state["construction_bindings"].size(): return false
	for id in jobs:
		var value: Variant = state["construction_bindings"].get(id)
		if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["actor_id", "body_id", "control_epoch", "world_id", "region_id", "fingerprint"])): return false
		for field in ["actor_id", "body_id", "world_id", "region_id"]:
			if not ControlContractValidation.is_id(value[field]): return false
		if value["actor_id"] != jobs[id]["actor_id"] or value["fingerprint"] != blueprint["fingerprint"] or not ControlContractValidation.is_integer(value["control_epoch"], 0, ProductionSimulationSystem.MAX_REVISION): return false
		if int(jobs[id]["last_tick"]) > int(state["last_tick"]): return false
	return true


static func pinned(blueprint: Dictionary) -> bool:
	return blueprint.get("definition_id") == "item.resource-canister.fabricated" and blueprint.get("materials") == {"iron": ConstructionReservationPlan.BILL} and int(blueprint.get("definition_revision", 0)) == 2


static func plan(state: Dictionary, operation: String, request_id: String, id: String, tick: int) -> ServiceResult:
	return ConstructionReservationPlan.plan(state["construction"], {"request_id": request_id, "job_id": id, "operation": operation, "expected_revision": state["construction"]["revision"], "tick": tick}, state["construction_bindings"][id]["actor_id"], int(state["store"]["iron"]), int(state["state_revision"]))
