extends RefCounted
class_name PaidPanelCollisionDescriptors

## Detached server-internal values; not an observation, physics body or grant.
const THICKNESS_MM: int = 12


static func describe(panels: Variant) -> ServiceResult:
	# Validate the complete paid registry, including bills, before deriving solids.
	if not HorizontalPanelConstruction.valid(panels):
		return ServiceResult.failure(&"invalid_paid_panel_collision", "Current paid panel records must validate before geometry derivation.")
	var boxes: Array[Dictionary] = []
	var ids: Array = panels.keys()
	ids.sort()
	for id in ids:
		var panel: Dictionary = panels[id]
		var bounds: Array = panel["bounds_millimetres"]
		# The paid 50mm grid guarantees integral half extents and centers.
		var center_y: int = int(panel["height_millimetres"]) + (-6 if panel["kind"] == "floor" else 6)
		boxes.append({"surface_id": id, "kind": panel["kind"],
			"center_millimetres": [int((bounds[0] + bounds[1]) / 2), center_y, int((bounds[2] + bounds[3]) / 2)],
			"size_millimetres": [int(bounds[1] - bounds[0]), THICKNESS_MM, int(bounds[3] - bounds[2])]})
	return ServiceResult.success(boxes)
