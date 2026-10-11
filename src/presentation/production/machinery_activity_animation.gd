extends RefCounted
class_name MachineryActivityAnimation

## Detached visual evidence, never simulation work. No completion receipt is
## available in this projection: absent jobs cannot certify a completed batch.
const EVIDENCE_LIFETIME: float = 1.0
const MAX_FRAME_DELTA: float = 0.1
var _tick: int = -1
var _age: float = EVIDENCE_LIFETIME
var _previous: Dictionary = {}
var _states: Dictionary = {}
var _phase: Dictionary = {}
var _drive_phase: Dictionary = {}
var _drive_kind: Dictionary = {}


func observe(record: Dictionary) -> bool:
	if record.is_empty():
		_tick = -1
		_forget()
		return false
	if not WorkstationResourceView.valid(record) or int(record["last_tick"]) < _tick:
		_forget()
		return false
	var tick: int = int(record["last_tick"])
	var workshop: Dictionary = record["machinery"]
	var next: Dictionary = {}
	var states: Dictionary = {}
	_drive_kind.clear()
	for id in workshop["placements"]:
		var job: Dictionary = workshop["jobs"].get(id, {})
		var prior: Dictionary = _previous.get(id, {})
		var enabled: bool = workshop["placements"][id]["enabled"]
		var state: String = "idle"
		if job.is_empty():
			if not prior.get("job", {}).is_empty() or _states.get(id) == "outcome_unknown": state = "outcome_unknown"
		elif job["paused"]:
			state = "paused"
		elif not enabled or _frame_broken(workshop, id):
			state = "blocked"
		elif tick == _tick and prior == {"job": job, "enabled": enabled}:
			state = _states.get(id, "unknown")
		elif tick > _tick and not prior.get("job", {}).is_empty() and prior["job"]["recipe"] == job["recipe"]:
			state = "running" if int(job["progress"]) > int(prior["job"]["progress"]) else ("blocked" if int(job["progress"]) == int(prior["job"]["progress"]) else "unknown")
		else:
			state = "unknown"
		var recipe: String = job.get("recipe", "")
		if recipe.begins_with("extract.") and record["deposits"].has("deposit." + recipe.trim_prefix("extract.")):
			_drive_kind[id] = "extractor"
		elif record.get("recipe_requirements", {}).has(recipe):
			_drive_kind[id] = "refinery" if record["recipe_requirements"][recipe]["station"] != "printer" else ""
		if state == "running" and not String(_drive_kind.get(id, "")).is_empty() and not _components_usable(workshop, id, _drive_kind[id]): state = "blocked"
		states[id] = state
		next[id] = {"job": job.duplicate(true), "enabled": enabled}
		if not _phase.has(id): _phase[id] = 0.0
		if not _drive_phase.has(id): _drive_phase[id] = {"extractor": 0.0, "refinery": 0.0}
	for id in _phase.keys():
		if not next.has(id):
			_phase.erase(id)
			_drive_phase.erase(id)
	if tick > _tick: _age = 0.0
	_tick = tick
	_previous = next
	_states = states
	return true


static func _frame_broken(workshop: Dictionary, id: String) -> bool:
	for physical in workshop["inventory_items"]:
		if physical["item_id"] == id: return int(physical["condition_permille"]) == 0
	return false


static func _components_usable(workshop: Dictionary, id: String, kind: String) -> bool:
	var usable: Dictionary = {}
	var frame_usable: bool = false
	for physical in workshop["inventory_items"]:
		var module: String = physical["item_id"]
		if module == id: frame_usable = int(physical["condition_permille"]) > 0
		if workshop["mounts"].get(module) == id and int(physical["condition_permille"]) > 0:
			usable[workshop["parts"][module]["kind"]] = true
	return frame_usable and usable.has("power") and usable.has("controller") and usable.has(kind)


func _forget() -> void:
	_age = EVIDENCE_LIFETIME
	_previous.clear()
	_states.clear()
	_drive_kind.clear()
	# Keep cosmetic pose frozen through disconnect; never reset canonical state.


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	_age = minf(EVIDENCE_LIFETIME, _age + delta)
	if _age >= EVIDENCE_LIFETIME: return
	var bounded: float = minf(delta, MAX_FRAME_DELTA)
	for id in _states:
		if _states[id] != "running": continue
		_phase[id] = fposmod(float(_phase[id]) + bounded * TAU, TAU)
		var kind: String = drive_kind(id)
		if _drive_phase[id].has(kind): _drive_phase[id][kind] = fposmod(float(_drive_phase[id][kind]) + bounded * TAU, TAU)


func state(machine_id: String) -> String:
	return "unknown" if _age >= EVIDENCE_LIFETIME else _states.get(machine_id, "unknown")


func phase(machine_id: String, kind: String = "") -> float:
	if not kind.is_empty(): return float(_drive_phase.get(machine_id, {}).get(kind, 0.0))
	return float(_phase.get(machine_id, 0.0))


func drive_kind(machine_id: String) -> String:
	return _drive_kind.get(machine_id, "")


func indicator(machine_id: String) -> Color:
	match state(machine_id):
		"running": return Color(0.2, 0.75, 0.6)
		"paused", "blocked": return Color(0.9, 0.6, 0.15)
		"idle": return Color(0.3, 0.4, 0.5)
	return Color(0.65, 0.4, 0.7)
