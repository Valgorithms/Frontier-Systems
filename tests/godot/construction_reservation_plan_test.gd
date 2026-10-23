extends SceneTree

var failures: int = 0
var record: Dictionary = ConstructionReservationPlan.initial()
var iron: int = 2000000
var owner_revision: int = 0
var outputs: Dictionary = {}
var sequence: int = 0


func _initialize() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/production/equipment-blueprints.v1.json"))
	var bill: Dictionary = source["blueprints"][ConstructionReservationPlan.BLUEPRINT]["materials"]
	check(bill.size() == 1 and ControlContractValidation.is_integer(bill.get("iron"), ConstructionReservationPlan.BILL, ConstructionReservationPlan.BILL), "bill matches actual trusted blueprint")
	var first: Dictionary = request("reserve", "job-a", 0)
	var candidate: ServiceResult = plan(first)
	check(candidate.is_success and record["jobs"].is_empty() and iron == 2000000, "planning has no side effects")
	var competing: ServiceResult = plan(request("reserve", "job-b", 0))
	check(commit(candidate.value), "first candidate commits")
	check(not commit(competing.value), "same owner revision cannot commit a competing stale candidate")
	check(apply("reserve", "job-b", 0), "independent second claim fits finite stock")
	var before: Dictionary = record.duplicate(true)
	check(not plan(request("reserve", "job-c", 0)).is_success and record == before, "third claim rejects double spend")
	var stale: Dictionary = request("cancel", "job-a", 0)
	stale["expected_revision"] = 0
	check(not plan(stale).is_success, "stale ledger revision rejects")
	check(not plan(request("cancel", "job-a", 0), "foreign").is_success, "foreign principal cannot cancel")
	check(not plan(first, "foreign").is_success, "foreign principal cannot replay receipt")
	var changed: Dictionary = first.duplicate(true)
	changed["job_id"] = "job-b"
	check(not plan(changed).is_success, "same request ID rejects changed intent")
	check(apply("cancel", "job-b", 0) and iron == 2000000, "cancellation releases claim without crediting stock")
	check(apply("reserve", "job-c", 0), "released claim permits recovery by new reservation")
	check(not apply("complete", "job-a", 0), "work cannot complete immediately")
	check(not apply("advance", "job-a", 2), "skipped tick cannot fast forward")
	check(apply("advance", "job-a", 1), "one consecutive tick progresses")
	check(not apply("advance", "job-a", 1), "duplicate tick with new request cannot duplicate progress")
	check(apply("interrupt", "job-a", 1), "interrupt preserves work and claim")
	check(not apply("advance", "job-a", 2), "paused work cannot progress")
	check(apply("resume", "job-a", 10), "resume revalidates current actor and revision")
	for tick in range(11, 130): check(apply("advance", "job-a", tick), "bounded consecutive work %d" % tick)
	check(record["jobs"]["job-a"]["state"] == "ready", "exact finite duration becomes ready")
	check(not apply("complete", "job-a", 130), "completion must use freshly ready tick")
	var restored: ServiceResult = ConstructionReservationPlan.restore(JSON.parse_string(JSON.stringify(record)), iron)
	check(restored.is_success and restored.value["jobs"]["job-a"]["state"] == "paused", "JSON restore pauses ready work")
	check(ConstructionReservationPlan.claimed(restored.value) == 2000000, "restore retains claims")
	record = restored.value
	owner_revision += 1
	check(not apply("complete", "job-a", 129), "restored readiness cannot complete automatically")
	check(apply("resume", "job-a", 200) and apply("advance", "job-a", 201), "ready restore needs one fresh tick")
	var finish: Dictionary = request("complete", "job-a", 201)
	var finished: ServiceResult = plan(finish)
	before = record.duplicate(true)
	check(not commit(finished.value, true) and record == before and iron == 2000000 and outputs.is_empty(), "failed output preparation commits neither debit nor receipt")
	check(commit(finished.value) and iron == 1000000 and outputs.size() == 1, "atomic fixture completes one conserved output")
	var retry: ServiceResult = plan(finish)
	check(retry.is_success and retry.value["replayed"] and retry.value["effects"].is_empty(), "completion retry has no duplicate effects")
	check(commit(retry.value) and iron == 1000000 and outputs.size() == 1, "retry cannot double spend or duplicate output")
	check(not apply("complete", "job-a", 201), "new completion request cannot re-complete terminal job")
	record = ConstructionReservationPlan.restore(JSON.parse_string(JSON.stringify(record)), iron).value
	check(record["jobs"]["job-a"]["state"] == "completed" and record["jobs"]["job-b"]["state"] == "cancelled", "terminal states survive restart")
	check(plan(JSON.parse_string(JSON.stringify(finish))).is_success, "retained completion receipt and request survive JSON restore")
	check(apply("cancel", "job-c", 0), "paused claim can be cancelled after restart")
	check(iron + outputs.size() * ConstructionReservationPlan.BILL == 2000000 and ConstructionReservationPlan.claimed(record) == 0, "all original material remains exactly once")
	check(not ConstructionReservationPlan.restore(record, -1).is_success, "negative stock rejects restore")
	var invalid: Dictionary = record.duplicate(true)
	invalid["jobs"]["job-a"]["progress_ticks"] = 0
	check(not ConstructionReservationPlan.valid(invalid), "forged completed progress rejects")
	invalid = record.duplicate(true)
	invalid["jobs"]["job-a"]["extra"] = true
	check(not ConstructionReservationPlan.valid(invalid), "unknown persisted fields reject")
	invalid = record.duplicate(true)
	invalid["revision"] = 1.5
	check(not ConstructionReservationPlan.valid(invalid), "fractional revisions reject")
	var empty: Dictionary = ConstructionReservationPlan.initial()
	var too_many: Dictionary = empty.duplicate(true)
	for index in range(ConstructionReservationPlan.MAX_JOBS + 1):
		too_many["jobs"]["job-%d" % index] = {"actor_id": "actor", "blueprint_id": ConstructionReservationPlan.BLUEPRINT, "state": "active", "progress_ticks": 0, "last_tick": 0}
	check(not ConstructionReservationPlan.valid(too_many), "bounded job registry rejects overflow")
	var full: Dictionary = record.duplicate(true)
	var receipt: Dictionary = full["receipts"].values()[0]
	for index in range(ConstructionReservationPlan.MAX_RECEIPTS): full["receipts"]["filled-%d" % index] = receipt.duplicate(true)
	check(not ConstructionReservationPlan.valid(full), "bounded receipt registry rejects overflow")
	full["receipts"] = {}
	for index in range(ConstructionReservationPlan.MAX_RECEIPTS): full["receipts"]["filled-%d" % index] = receipt.duplicate(true)
	var bounded: Dictionary = request("reserve", "job-limit", 0)
	check(ConstructionReservationPlan.valid(full) and not ConstructionReservationPlan.plan(full, bounded, "actor", iron, owner_revision).is_success, "full receipt retention fails closed without evicting idempotency")
	var unpaid: Dictionary = ConstructionReservationPlan.initial()
	var reserve: Dictionary = {"request_id": "no-stock", "job_id": "unpaid", "operation": "reserve", "expected_revision": 0, "tick": 0}
	check(not ConstructionReservationPlan.plan(unpaid, reserve, "actor", ConstructionReservationPlan.BILL - 1, 0).is_success, "insufficient owner stock rejects")
	unpaid["jobs"]["unpaid"] = {"actor_id": "actor", "blueprint_id": ConstructionReservationPlan.BLUEPRINT, "state": "paused", "progress_ticks": 1, "last_tick": 1}
	check(not ConstructionReservationPlan.restore(unpaid, 0).is_success, "restore rejects claims exceeding canonical stock")
	var malformed: Dictionary = request("reserve", "bad", 0)
	malformed["tick"] = 1.5
	check(not plan(malformed).is_success, "fractional request tick rejects")
	check(not ConstructionReservationPlan.restore(too_many, iron).is_success, "malformed restore fails closed")
	print("Construction reservation contract: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func request(operation: String, job: String, tick: int) -> Dictionary:
	sequence += 1
	return {"request_id": "reservation-request-%d" % sequence, "job_id": job, "operation": operation, "expected_revision": record["revision"], "tick": tick}


func plan(command: Dictionary, actor: String = "actor") -> ServiceResult:
	return ConstructionReservationPlan.plan(record, command, actor, iron, owner_revision)


func apply(operation: String, job: String, tick: int) -> bool:
	var result: ServiceResult = plan(request(operation, job, tick))
	return result.is_success and commit(result.value)


## Test adapter only: production integration must provide this atomicity itself.
func commit(candidate: Dictionary, reject_output: bool = false) -> bool:
	if int(candidate["base_owner_revision"]) != owner_revision: return false
	if candidate["replayed"]: return true
	var effects: Dictionary = candidate["effects"]
	if not effects.is_empty():
		if reject_output or outputs.has(effects["output_id"]) or iron < int(effects["debit_iron_milligrams"]): return false
		outputs[effects["output_id"]] = effects["blueprint_id"]
		iron -= int(effects["debit_iron_milligrams"])
	record = candidate["record"].duplicate(true)
	owner_revision += 1
	return true


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
