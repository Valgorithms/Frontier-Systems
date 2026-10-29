extends RefCounted
class_name HorizontalPanelConstruction

## Paid boundary planes, not collision solids or pressure vessels.
const BLUEPRINT: String = "surface.horizontal-panel"
const MAX_PANELS: int = 64


static func descriptor(id: String, panel: Dictionary) -> Dictionary:
	return {"surface_id": id, "kind": panel["kind"], "bounds_millimetres": panel["bounds_millimetres"].duplicate(), "height_millimetres": panel["height_millimetres"]}


static func bill(bounds: Array) -> int:
	return int(bounds[1] - bounds[0]) * int(bounds[3] - bounds[2])


static func valid(panels: Variant) -> bool:
	if typeof(panels) != TYPE_DICTIONARY or panels.size() > MAX_PANELS: return false
	var previous: Array[Dictionary] = []
	for id in panels:
		var panel: Variant = panels[id]
		if not ControlContractValidation.is_id(id) or typeof(panel) != TYPE_DICTIONARY: return false
		if not ControlContractValidation.has_exact_fields(panel, PackedStringArray(["kind", "bounds_millimetres", "height_millimetres", "blueprint_id", "blueprint_revision", "principal_id", "materials"])): return false
		if panel["blueprint_id"] != BLUEPRINT or not ControlContractValidation.is_integer(panel["blueprint_revision"], 1, 1) or not ControlContractValidation.is_id(panel["principal_id"]): return false
		# Decode untrusted geometry before indexing or calculating its bill.
		var decoded: ServiceResult = ConstructedRoomSurface.decode({"surface_id": id, "kind": panel["kind"], "bounds_millimetres": panel["bounds_millimetres"], "height_millimetres": panel["height_millimetres"]})
		if not decoded.is_success: return false
		var bounds: Array = decoded.value["bounds_millimetres"]
		if bounds[1] - bounds[0] > 1000 or bounds[3] - bounds[2] > 1000: return false
		for coordinate in bounds:
			if coordinate % 50 != 0: return false
		if typeof(panel["materials"]) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(panel["materials"], PackedStringArray(["plate"])) or not ControlContractValidation.is_integer(panel["materials"]["plate"], bill(bounds), bill(bounds)): return false
		for other in previous:
			if panel["kind"] == other["kind"] and ConstructedRoomClosure.overlaps(bounds, other["bounds_millimetres"]): return false
		previous.append(decoded.value)
	return true


static func mass(panels: Dictionary) -> int:
	var total: int = 0
	for panel in panels.values(): total += int(panel["materials"]["plate"])
	return total


static func plan(state: Dictionary, inventory: InventorySimulationSystem, context: AuthenticatedCommandContext, request: String, operation: String, payload: Dictionary) -> ServiceResult:
	var create: bool = operation == "panel_build"
	var fields: Array = ["expected_revision", "kind", "bounds_millimetres", "height_millimetres"] if create else ["expected_revision", "panel_id"]
	if not ControlContractValidation.has_exact_fields(payload, PackedStringArray(fields)): return failure()
	var panels: Dictionary = state["panels"]
	var id: Variant = "panel-%s" % JSON.stringify([String(context.principal_id), request]).sha256_text().substr(0, 32) if create else payload["panel_id"]
	if not ControlContractValidation.is_id(id): return failure()
	var panel: Dictionary
	if create:
		if panels.size() >= MAX_PANELS or panels.has(id): return failure()
		panel = {"kind": payload["kind"], "bounds_millimetres": payload["bounds_millimetres"], "height_millimetres": payload["height_millimetres"], "blueprint_id": BLUEPRINT, "blueprint_revision": 1, "principal_id": String(context.principal_id), "materials": {"plate": 0}}
		var geometry: ServiceResult = ConstructedRoomSurface.decode({"surface_id": id, "kind": panel["kind"], "bounds_millimetres": panel["bounds_millimetres"], "height_millimetres": panel["height_millimetres"]})
		if not geometry.is_success: return failure()
		panel["bounds_millimetres"] = geometry.value["bounds_millimetres"]
		panel["height_millimetres"] = geometry.value["height_millimetres"]
		panel["materials"]["plate"] = bill(panel["bounds_millimetres"])
		panels[id] = panel
		if not valid(panels) or int(state["store"]["plate"]) < int(panel["materials"]["plate"]): return failure()
	else:
		if not panels.has(id): return failure()
		panel = panels[id]
		if panel["principal_id"] != String(context.principal_id): return failure()
		if ProductionSimulationSystem._mass(state["store"]) + ProductionSimulationSystem._reserved_mass(state) + int(panel["materials"]["plate"]) > ProductionSimulationSystem.MAX_MASS: return failure()
	var bounds: Array = panel["bounds_millimetres"]
	# Reach uses the installation's floor anchor for either boundary plane.
	var reach: ServiceResult = inventory.production_capability(context, true, [int((bounds[0] + bounds[1]) / 2), 0, int((bounds[2] + bounds[3]) / 2)])
	if not reach.is_success: return reach
	state["store"]["plate"] += -int(panel["materials"]["plate"]) if create else int(panel["materials"]["plate"])
	if not create: panels.erase(id)
	return ServiceResult.success()


static func failure() -> ServiceResult:
	return ServiceResult.failure(&"panel_construction_denied", "Expected a paid, owned, reachable, non-overlapping 50 mm rectangle with bounded stock and capacity.")
