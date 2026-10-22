extends RefCounted
class_name ConstructedWallBoundaries

## Detached physical boundary input for future room topology, never a seal claim.
## Production remains the canonical owner; no pressure volumes or matter change.
static func describe(walls: Variant, revision: Variant) -> ServiceResult:
	if not ControlContractValidation.is_integer(revision, 0, ProductionSimulationSystem.MAX_REVISION) or not SpatialWallConstruction.valid(walls):
		return ServiceResult.failure(&"invalid_wall_boundaries", "Validated constructed walls and a production revision are required.")
	var boundaries: Array = []
	var ids: Array = walls.keys()
	ids.sort()
	for id in ids:
		var wall: Dictionary = walls[id]
		var half: Vector3 = SpatialWallConstruction.half_size(wall)
		var position: Array = InventorySpatialMath.normalized(wall["position"])
		var along_x: bool = int(wall["quarter_turn"]) == 0
		var span: int = int(half.x if along_x else half.z)
		var start: Array = position.duplicate()
		var end: Array = position.duplicate()
		var axis: int = 0 if along_x else 2
		start[axis] -= span
		end[axis] += span
		boundaries.append({"wall_id": String(id), "start_millimetres": start, "end_millimetres": end,
			"height_millimetres": int(half.y) * 2, "thickness_millimetres": int(half.z if along_x else half.x) * 2})
	return ServiceResult.success({"schema_version": 1, "production_revision": int(revision), "boundaries": boundaries})
