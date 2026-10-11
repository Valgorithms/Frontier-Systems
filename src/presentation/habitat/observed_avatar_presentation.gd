extends MeshInstance3D
class_name ObservedAvatarPresentation

## Disposable crew geometry; no collider, picking, commands or persisted state.
const STALE_SECONDS: float = 0.5
const STRIDE_METRES: float = 1.2
const MAX_STEP_METRES: float = 1.0
var _previous := Vector3.ZERO
var _initialized: bool = false
var _tick: int = -1
var _age: float = 0.0
var _phase: float = 0.0
var _limbs: Array[Node3D] = []


func _ready() -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 0.22
	torso.height = 0.75
	mesh = torso
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#5dba87")
	material.roughness = 0.8
	material_override = material
	_part(self, Vector3(0.34, 0.34, 0.3), Vector3(0, 0.59, 0), material)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.29, 0.28, 0)
		add_child(arm)
		_part(arm, Vector3(0.12, 0.59, 0.14), Vector3(0, -0.295, 0), material)
		_limbs.append(arm)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, -0.33, 0)
		add_child(leg)
		_part(leg, Vector3(0.16, 0.57, 0.18), Vector3(0, -0.285, 0), material)
		_limbs.append(leg)


## Coordinates are already validated by the observation adapter. Never interpolate
## position or infer motion from input, velocity, elapsed frames or a repeated tick.
func observe_position(coords: Array, tick: int) -> void:
	if not InventorySpatialMath.is_position(coords) or tick < 0 or tick <= _tick:
		return
	var observed := Vector3(float(coords[0]), float(coords[1]), float(coords[2])) / 1000.0
	if not observed.is_finite():
		neutralize()
		return
	var fresh: bool = _initialized and _age < STALE_SECONDS
	var displacement: Vector3 = observed - _previous
	_previous = observed
	_tick = tick
	_age = 0.0
	_initialized = true
	position = ProceduralWorldInventoryPreview.DISPLAY_ORIGIN + Vector3(observed.x, maxf(0.95, observed.y), observed.z)
	var horizontal := Vector2(displacement.x, displacement.z)
	var distance: float = horizontal.length()
	if not fresh or distance < 0.001 or displacement.length() > MAX_STEP_METRES or absf(displacement.y) > 0.05:
		neutralize()
		return
	_phase = fposmod(_phase + distance * TAU / STRIDE_METRES, TAU)
	rotation.y = atan2(-displacement.x, -displacement.z)
	var swing: float = sin(_phase) * 0.38
	for index in range(_limbs.size()):
		_limbs[index].rotation.x = swing * (-1.0 if index in [0, 3] else 1.0)


func neutralize() -> void:
	_phase = 0.0
	for limb in _limbs:
		limb.rotation.x = 0.0


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_age = minf(STALE_SECONDS, _age + delta)
	if _age >= STALE_SECONDS:
		neutralize()


func _part(parent: Node3D, dimensions: Vector3, location: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.material_override = material
	part.position = location
	parent.add_child(part)
