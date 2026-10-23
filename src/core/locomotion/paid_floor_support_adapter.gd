extends RefCounted
class_name PaidFloorSupportAdapter

## Pure wiring helper; only the Production entry point establishes provenance.
## Prototype human capsule-center mapping, mm: height1800, diameter600.
const FOOT_OFFSET: int = 900
const HALF_WIDTH: int = 300
const VERTICAL_TOLERANCE: int = 10


static func resolve(pose: Dictionary, surfaces: Array[Dictionary], revision: int, production_tick: int, environment: Dictionary, equipment: Dictionary) -> ServiceResult:
	var fields := PackedStringArray(["magnetic_surface", "mag_boots_enabled", "mag_boots_powered", "mag_boots_condition_permille", "jetpack_enabled", "jetpack_powered", "jetpack_condition_permille", "propellant_milligrams"])
	if not ControlContractValidation.has_exact_fields(equipment, fields):
		return ServiceResult.failure(&"invalid_paid_floor_locomotion", "Only trusted equipment fields are accepted; contact is owner-derived.")
	var position: Array = pose["position_millimetres"]
	var support: ServiceResult = HorizontalFloorSupportQuery.query({"schema_version": 1, "expected_production_revision": revision,
		"footprint_millimetres": [int(position[0]) - HALF_WIDTH, int(position[0]) + HALF_WIDTH, int(position[2]) - HALF_WIDTH, int(position[2]) + HALF_WIDTH],
		"foot_height_millimetres": int(position[1]) - FOOT_OFFSET, "vertical_tolerance_millimetres": VERTICAL_TOLERANCE}, surfaces, revision)
	if not support.is_success: return support
	var trusted: Dictionary = equipment.duplicate(true)
	trusted["surface_contact"] = support.value["supported"]
	var policy: ServiceResult = LocomotionEnvironmentPolicy.resolve(environment, trusted)
	if not policy.is_success: return policy
	# Aggregate only: other builders' panel IDs/principals never leave this API.
	return ServiceResult.success({"schema_version": 1, "production_revision": revision, "production_tick": production_tick,
		"inventory_tick": pose["inventory_tick"], "body_action_epoch": pose["action_epoch"], "supported": support.value["supported"],
		"locomotion": policy.value, "profiling": support.value["profiling"]})
