extends RefCounted
class_name TimedCanisterConstruction

## Workbench-only policy. Material and physical records remain in their owners.
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
