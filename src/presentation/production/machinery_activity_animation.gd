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
	for id in workshop["placements"]:
		var job: Dictionary = workshop["jobs"].get(id, {})
		var prior: Dictionary = _previous.get(id, {})
		var enabled: bool = workshop["placements"][id]["enabled"]
		var state: String = "idle"
		if job.is_empty():
			if not prior.get("job", {}).is_empty() or _states.get(id) == "outcome_unknown": state = "outcome_unknown"
		elif job["paused"]:
			state = "paused"
		elif not enabled:
			state = "blocked"
		elif tick == _tick and prior == {"job": job, "enabled": enabled}:
			state = _states.get(id, "unknown")
		elif tick > _tick and not prior.get("job", {}).is_empty() and prior["job"]["recipe"] == job["recipe"]:
			state = "running" if int(job["progress"]) > int(prior["job"]["progress"]) else ("blocked" if int(job["progress"]) == int(prior["job"]["progress"]) else "unknown")
		else:
			state = "unknown"
		states[id] = state
		next[id] = {"job": job.duplicate(true), "enabled": enabled}
		if not _phase.has(id): _phase[id] = 0.0
	for id in _phase.keys():
		if not next.has(id): _phase.erase(id)
	if tick > _tick: _age = 0.0
	_tick = tick
	_previous = next
	_states = states
	return true


func _forget() -> void:
	_age = EVIDENCE_LIFETIME
	_previous.clear()
	_states.clear()
	# Keep cosmetic pose frozen through disconnect; never reset canonical state.


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	_age = minf(EVIDENCE_LIFETIME, _age + delta)
	if _age >= EVIDENCE_LIFETIME: return
	var bounded: float = minf(delta, MAX_FRAME_DELTA)
	for id in _states:
		if _states[id] == "running": _phase[id] = fposmod(float(_phase[id]) + bounded * TAU, TAU)


func state(machine_id: String) -> String:
	return "unknown" if _age >= EVIDENCE_LIFETIME else _states.get(machine_id, "unknown")


func phase(machine_id: String) -> float:
	return float(_phase.get(machine_id, 0.0))


func indicator(machine_id: String) -> Color:
	match state(machine_id):
		"running": return Color(0.2, 0.75, 0.6)
		"paused", "blocked": return Color(0.9, 0.6, 0.15)
		"idle": return Color(0.3, 0.4, 0.5)
	return Color(0.65, 0.4, 0.7)
