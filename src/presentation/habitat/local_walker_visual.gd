extends MeshInstance3D
class_name LocalWalkerVisual

## Original MIT humanoid. Disposable geometry and pose only, never authority.
const STRIDE_LENGTH: float = 2.4
const MAX_SWING: float = 0.20
var _phase: float = 0.0
var _sampled: bool = false
var _last_position := Vector3.ZERO
var _limbs: Array[MeshInstance3D] = []
var _neutral: Array[Transform3D] = []
var _pivots: Array[Vector3] = []
var _signs: Array[float] = []


func _ready() -> void:
	name = "LocalWalkerVisual"
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color("#6cb8c5")
	suit.roughness = 0.85
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("#294856")
	trim.roughness = 0.85
	var torso := BoxMesh.new()
	torso.size = Vector3(0.40, 0.62, 0.28)
	mesh = torso
	material_override = suit
	_part("Neck", Vector3(0.14, 0.08, 0.14), Vector3(0, 0.35, 0), trim)
	_part("Head", Vector3(0.30, 0.30, 0.28), Vector3(0, 0.54, 0), suit)
	_part("Visor", Vector3(0.23, 0.10, 0.02), Vector3(0, 0.56, -0.15), trim)
	_part("Pelvis", Vector3(0.34, 0.18, 0.26), Vector3(0, -0.36, 0), trim)
	for side in [-1.0, 1.0]:
		var suffix: String = "Left" if side < 0 else "Right"
		_part("Arm" + suffix, Vector3(0.12, 0.57, 0.14), Vector3(side * 0.28, 0.015, 0), suit)
		_part("Glove" + suffix, Vector3(0.13, 0.12, 0.15), Vector3(side * 0.28, -0.33, 0), trim)
		_part("Leg" + suffix, Vector3(0.14, 0.37, 0.18), Vector3(side * 0.10, -0.625, 0), suit)
		_part("Boot" + suffix, Vector3(0.16, 0.09, 0.24), Vector3(side * 0.10, -0.855, -0.03), trim)
		for part_name in ["Arm", "Glove", "Leg", "Boot"]:
			var part := get_node(part_name + suffix) as MeshInstance3D
			_limbs.append(part)
			_neutral.append(part.transform)
			var arm: bool = part_name in ["Arm", "Glove"]
			_pivots.append(Vector3(side * 0.28, 0.30, 0) if arm else Vector3(side * 0.10, -0.44, 0))
			_signs.append(-side if arm else side)


## Observe only this tick's collision-resolved travel. Discontinuities rebase neutral.
func observe_motion(before: Vector3, after: Vector3, delta: float, grounded: bool) -> void:
	var continuous: bool = _sampled and before == _last_position
	_last_position = after
	_sampled = true
	var travel: Vector3 = after - before
	if not continuous or not before.is_finite() or not after.is_finite() or not is_finite(delta) or delta <= 0.0 or delta > 0.1 or not grounded or travel.length() > LocalHabitatCharacter.RUN_SPEED * delta + 0.001:
		_neutral_pose()
		return
	var horizontal := Vector3(travel.x, 0, travel.z)
	var distance: float = horizontal.length()
	if distance <= 0.0001:
		_neutral_pose()
		return
	_phase = fposmod(_phase + distance * TAU / STRIDE_LENGTH, TAU)
	var swing: float = sin(_phase) * MAX_SWING * minf(distance / delta / LocalHabitatCharacter.WALK_SPEED, 1.0)
	var local_direction: Vector3 = global_basis.inverse() * horizontal.normalized()
	var axis := Vector3(-local_direction.z, 0, local_direction.x).normalized()
	for index in range(_limbs.size()):
		var turn := Basis(axis, swing * _signs[index])
		_limbs[index].transform = Transform3D(turn * _neutral[index].basis, _pivots[index] + turn * (_neutral[index].origin - _pivots[index]))


func reset_motion() -> void:
	_sampled = false
	_neutral_pose()


func _neutral_pose() -> void:
	_phase = 0.0
	for index in range(_limbs.size()):
		_limbs[index].transform = _neutral[index]


func _part(part_name: String, dimensions: Vector3, location: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.material_override = material
	part.position = location
	add_child(part)
