extends RefCounted
class_name HorizontalFloorSupportQuery

## Detached geometry assessment. Only a trusted adapter can establish provenance/freshness.
static func query(request: Variant, surfaces: Variant, production_revision: Variant) -> ServiceResult:
	if typeof(request) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(request, PackedStringArray(["schema_version", "expected_production_revision", "footprint_millimetres", "foot_height_millimetres", "vertical_tolerance_millimetres"])):
		return invalid()
	if not ControlContractValidation.is_integer(request.schema_version, 1, 1) or not ControlContractValidation.is_integer(production_revision, 0, ProductionSimulationSystem.MAX_REVISION) or not ControlContractValidation.is_integer(request.expected_production_revision, 0, ProductionSimulationSystem.MAX_REVISION) or request.expected_production_revision != production_revision:
		return invalid()
	var footprint: Variant = request.footprint_millimetres
	if typeof(footprint) != TYPE_ARRAY or footprint.size() != 4:
		return invalid()
	for number in footprint:
		if not ControlContractValidation.is_integer(number, -100500, 100500): return invalid()
	if footprint[1] <= footprint[0] or footprint[3] <= footprint[2] or footprint[1] - footprint[0] > 2000 or footprint[3] - footprint[2] > 2000:
		return invalid()
	if not ControlContractValidation.is_integer(request.foot_height_millimetres, -100500, 100500) or not ControlContractValidation.is_integer(request.vertical_tolerance_millimetres, 0, 100):
		return invalid()
	if typeof(surfaces) != TYPE_ARRAY or surfaces.size() > HorizontalPanelConstruction.MAX_PANELS:
		return invalid()
	var panels: Dictionary = {}
	var floors: Array[Dictionary] = []
	var ids: Array[String] = []
	for raw in surfaces:
		var decoded: ServiceResult = ConstructedRoomSurface.decode(raw)
		if not decoded.is_success: return invalid()
		var surface: Dictionary = decoded.value
		var id: String = surface.surface_id
		if panels.has(id): return invalid()
		# Reuse canonical panel geometry/grid/overlap rules; synthetic metadata is
		# validation scaffolding only, never evidence of an installed paid record.
		panels[id] = {"kind": surface.kind, "bounds_millimetres": surface.bounds_millimetres, "height_millimetres": surface.height_millimetres, "blueprint_id": HorizontalPanelConstruction.BLUEPRINT, "blueprint_revision": 1, "principal_id": "geometry-validation", "materials": {"plate": HorizontalPanelConstruction.bill(surface.bounds_millimetres)}}
		if surface.kind == "floor" and request.foot_height_millimetres >= surface.height_millimetres and request.foot_height_millimetres - surface.height_millimetres <= request.vertical_tolerance_millimetres and ConstructedRoomClosure.overlaps(footprint, surface.bounds_millimetres):
			floors.append(surface)
			ids.append(id)
	if not HorizontalPanelConstruction.valid(panels): return invalid()
	ids.sort()
	var cuts: Array[int] = [int(footprint[0]), int(footprint[1])]
	for floor_surface in floors:
		for x in [maxi(footprint[0], floor_surface.bounds_millimetres[0]), mini(footprint[1], floor_surface.bounds_millimetres[1])]:
			if not cuts.has(x): cuts.append(x)
	cuts.sort()
	var supported: bool = true
	for index in range(cuts.size() - 1):
		var intervals: Array[Vector2i] = []
		for floor_surface in floors:
			var bounds: Array = floor_surface.bounds_millimetres
			if bounds[0] <= cuts[index] and bounds[1] >= cuts[index + 1]:
				intervals.append(Vector2i(maxi(footprint[2], bounds[2]), mini(footprint[3], bounds[3])))
		intervals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
		var covered_to: int = footprint[2]
		for interval in intervals:
			if interval.x > covered_to: break
			covered_to = maxi(covered_to, interval.y)
		if covered_to < footprint[3]: supported = false
	return ServiceResult.success({"schema_version": 1, "production_revision": int(production_revision), "supported": supported, "candidate_surface_ids": ids, "profiling": {"inspected_surfaces": surfaces.size(), "candidate_floors": floors.size(), "sweep_strips": cuts.size() - 1}})


static func invalid() -> ServiceResult:
	return ServiceResult.failure(&"invalid_floor_support_query", "Expected current complete bounded panel geometry and an integer-mm footprint/tolerance.")
