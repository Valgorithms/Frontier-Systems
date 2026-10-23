extends RefCounted
class_name HorizontalPanelObservation

## Detached own geometry; aggregate closure deliberately contains no identities.
static func project(state: Dictionary, context: AuthenticatedCommandContext, closure: ServiceResult, can_operate: bool) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	var ids: Array = state["panels"].keys()
	ids.sort()
	for id in ids:
		if state["panels"][id]["principal_id"] == String(context.principal_id):
			surfaces.append(HorizontalPanelConstruction.descriptor(id, state["panels"][id]))
	return {"schema_version": 1, "surfaces": surfaces, "can_operate": can_operate,
		"closure": {"production_revision": state["state_revision"], "status": closure.value["status"] if closure.is_success else "unavailable"}}


static func valid(value: Variant, revision: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(value, PackedStringArray(["schema_version", "surfaces", "can_operate", "closure"])): return false
	if not ControlContractValidation.is_integer(value["schema_version"], 1, 1) or typeof(value["can_operate"]) != TYPE_BOOL or typeof(value["surfaces"]) != TYPE_ARRAY or value["surfaces"].size() > 64: return false
	var summary: Variant = value["closure"]
	if typeof(summary) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(summary, PackedStringArray(["production_revision", "status"])): return false
	if not ControlContractValidation.is_integer(revision, 0, ProductionSimulationSystem.MAX_REVISION) or not ControlContractValidation.is_integer(summary["production_revision"], 0, ProductionSimulationSystem.MAX_REVISION) or summary["production_revision"] != revision or summary["status"] not in ["geometrically_closed", "open_or_unsupported", "unavailable"]: return false
	var panels: Dictionary = {}
	for raw in value["surfaces"]:
		var decoded: ServiceResult = ConstructedRoomSurface.decode(raw)
		if not decoded.is_success: return false
		var surface: Dictionary = decoded.value
		var id: String = surface["surface_id"]
		if panels.has(id): return false
		panels[id] = {"kind": surface["kind"], "bounds_millimetres": surface["bounds_millimetres"], "height_millimetres": surface["height_millimetres"], "blueprint_id": HorizontalPanelConstruction.BLUEPRINT, "blueprint_revision": 1, "principal_id": "projection", "materials": {"plate": HorizontalPanelConstruction.bill(surface["bounds_millimetres"])}}
	return HorizontalPanelConstruction.valid(panels)
