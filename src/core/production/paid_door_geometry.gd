extends RefCounted
class_name PaidDoorGeometry

## First-party prototype dimensions, never a pressure/density claim.
const MAX_DOORS: int = 16
const MASS: int = 2000000
const BLUEPRINT: String = "door.manual.prototype"


static func rotate(point: Vector3, pose: Dictionary) -> Vector3:
	return point if int(pose["quarter_turn"]) == 0 else Vector3(-point.z, point.y, point.x)


static func box(pose: Dictionary, offset: Vector3, size: Vector3) -> Dictionary:
	var center: Vector3 = SpatialWallConstruction.point(pose["position"]) + rotate(offset, pose)
	var extent: Vector3 = size if int(pose["quarter_turn"]) == 0 else Vector3(size.z, size.y, size.x)
	return {"center_millimetres": [int(center.x), int(center.y), int(center.z)], "size_millimetres": [int(extent.x), int(extent.y), int(extent.z)]}


static func sweep(pose: Dictionary) -> Dictionary:
	return box(pose, Vector3(0, 1000, 450), Vector3(1000, 2000, 1000))


static func solids(pose: Dictionary, opened: bool) -> Array[Dictionary]:
	return [box(pose, Vector3(-475, 1000, 0), Vector3(50, 2000, 100)),
		box(pose, Vector3(475, 1000, 0), Vector3(50, 2000, 100)),
		box(pose, Vector3(0, 1950, 0), Vector3(900, 100, 100)),
		box(pose, Vector3(-425, 950, 475) if opened else Vector3(0, 950, 0), Vector3(50, 1900, 900) if opened else Vector3(900, 1900, 50))]


static func intersects(a: Dictionary, b: Dictionary) -> bool:
	return SpatialWallConstruction.overlaps(SpatialWallConstruction.point(a["center_millimetres"]), SpatialWallConstruction.point(a["size_millimetres"]) / 2.0, SpatialWallConstruction.point(b["center_millimetres"]), SpatialWallConstruction.point(b["size_millimetres"]) / 2.0)


## Exact union coverage: split the support rectangle at every paid panel edge.
static func supported(pose: Dictionary, panels: Dictionary) -> bool:
	var volume: Dictionary = sweep(pose)
	var c: Array = volume["center_millimetres"]
	var s: Array = volume["size_millimetres"]
	var bounds: Array[int] = [int(c[0] - s[0] / 2), int(c[0] + s[0] / 2), int(c[2] - s[2] / 2), int(c[2] + s[2] / 2)]
	var xs: Array[int] = [bounds[0], bounds[1]]
	var zs: Array[int] = [bounds[2], bounds[3]]
	var floors: Array = []
	for panel in panels.values():
		if panel["kind"] != "floor" or int(panel["height_millimetres"]) != 0: continue
		var b: Array = panel["bounds_millimetres"]
		floors.append(b)
		for x in [b[0], b[1]]:
			if x > bounds[0] and x < bounds[1] and not xs.has(int(x)): xs.append(int(x))
		for z in [b[2], b[3]]:
			if z > bounds[2] and z < bounds[3] and not zs.has(int(z)): zs.append(int(z))
	xs.sort()
	zs.sort()
	for x in range(xs.size() - 1):
		for z in range(zs.size() - 1):
			var covered: bool = false
			for b in floors:
				if b[0] <= xs[x] and b[1] >= xs[x + 1] and b[2] <= zs[z] and b[3] >= zs[z + 1]: covered = true; break
			if not covered: return false
	return true


static func valid(doors: Variant, panels: Dictionary) -> bool:
	if typeof(doors) != TYPE_DICTIONARY or doors.size() > MAX_DOORS: return false
	var previous: Array = []
	for id in doors:
		var d: Variant = doors[id]
		if not ControlContractValidation.is_id(id) or not String(id).begins_with("door-") or typeof(d) != TYPE_DICTIONARY: return false
		if not ControlContractValidation.has_exact_fields(d, PackedStringArray(["position", "quarter_turn", "principal_id", "body_id", "blueprint_id", "blueprint_revision", "materials"])): return false
		if not SpatialWallConstruction.valid_pose({"position": d["position"], "quarter_turn": d["quarter_turn"]}): return false
		if not ControlContractValidation.is_id(d["principal_id"]) or not ControlContractValidation.is_id(d["body_id"]) or d["blueprint_id"] != BLUEPRINT or not ControlContractValidation.is_integer(d["blueprint_revision"], 1, 1) or d["materials"] != {"plate": MASS}: return false
		if not supported(d, panels): return false
		var envelope: Dictionary = sweep(d)
		for other in previous:
			if intersects(envelope, other): return false
		previous.append(envelope)
	return true
