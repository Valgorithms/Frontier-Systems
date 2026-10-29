extends RefCounted
class_name ConstructionReservationPlan

## Detached proposals only. Owner must atomically CAS stock, ledger and physical output.
const BLUEPRINT: String = "equipment.canister"
const BILL: int = 1000000
const WORK_TICKS: int = 120
const MAX_JOBS: int = 16
const MAX_RECEIPTS: int = 2048
const MAX_REVISION: int = 9007199254740990
const STATES: Array[String] = ["active", "paused", "ready", "cancelled", "completed"]
const OPERATIONS: Array[String] = ["reserve", "advance", "interrupt", "resume", "cancel", "complete"]


static func initial() -> Dictionary:
	return {"schema_version": 1, "revision": 0, "jobs": {}, "receipts": {}}


## Gross owner stock still includes claimed material; it must never be copied here.
static func claimed(record: Dictionary) -> int:
	var total: int = 0
	for job in record["jobs"].values():
		if job["state"] in ["active", "paused", "ready"]: total += BILL
	return total


static func valid(record: Dictionary) -> bool:
	if not ControlContractValidation.has_exact_fields(record, PackedStringArray(["schema_version", "revision", "jobs", "receipts"])) or not ControlContractValidation.is_integer(record["schema_version"], 1, 1) or not ControlContractValidation.is_integer(record["revision"], 0, MAX_REVISION): return false
	if typeof(record["jobs"]) != TYPE_DICTIONARY or record["jobs"].size() > MAX_JOBS or typeof(record["receipts"]) != TYPE_DICTIONARY or record["receipts"].size() > MAX_RECEIPTS: return false
	for id in record["jobs"]:
		var job: Variant = record["jobs"][id]
		if not ControlContractValidation.is_id(id) or typeof(job) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(job, PackedStringArray(["actor_id", "blueprint_id", "state", "progress_ticks", "last_tick"])): return false
		if not ControlContractValidation.is_id(job["actor_id"]) or job["blueprint_id"] != BLUEPRINT or not STATES.has(job["state"]) or not ControlContractValidation.is_integer(job["progress_ticks"], 0, WORK_TICKS) or not ControlContractValidation.is_integer(job["last_tick"], 0, MAX_REVISION): return false
		if job["state"] in ["ready", "completed"] and int(job["progress_ticks"]) != WORK_TICKS: return false
		if job["state"] == "active" and int(job["progress_ticks"]) == WORK_TICKS: return false
	for id in record["receipts"]:
		var receipt: Variant = record["receipts"][id]
		if not ControlContractValidation.is_id(id) or typeof(receipt) != TYPE_DICTIONARY or not ControlContractValidation.has_exact_fields(receipt, PackedStringArray(["actor_id", "intent", "job_id", "operation", "revision"])): return false
		if not record["jobs"].has(receipt["job_id"]) or receipt["actor_id"] != record["jobs"][receipt["job_id"]]["actor_id"] or not OPERATIONS.has(receipt["operation"]): return false
		if typeof(receipt["intent"]) != TYPE_STRING or receipt["intent"].length() != 64 or not ControlContractValidation.is_integer(receipt["revision"], 1, int(record["revision"])): return false
	return true


## Restoring trusted owner state pauses unfinished work without releasing its claim.
static func restore(record: Dictionary, owner_iron_mg: int) -> ServiceResult:
	if not valid(record) or owner_iron_mg < claimed(record) or int(record["revision"]) >= MAX_REVISION: return _failure()
	var next: Dictionary = record.duplicate(true)
	var changed: bool = false
	for job in next["jobs"].values():
		if job["state"] in ["active", "ready"]:
			job["state"] = "paused"
			changed = true
	if changed: next["revision"] = int(next["revision"]) + 1
	return ServiceResult.success(next)


## actor_id and owner_revision come from trusted tick ingress, never request payload.
## Caller must revalidate reach/capabilities and CAS base_owner_revision before commit.
static func plan(record: Dictionary, request: Dictionary, actor_id: String, owner_iron_mg: int, owner_revision: int) -> ServiceResult:
	if not valid(record) or not ControlContractValidation.is_id(actor_id) or owner_iron_mg < claimed(record) or owner_revision < 0 or owner_revision >= MAX_REVISION: return _failure()
	if not ControlContractValidation.has_exact_fields(request, PackedStringArray(["request_id", "job_id", "operation", "expected_revision", "tick"])): return _failure()
	for field in ["request_id", "job_id"]:
		if not ControlContractValidation.is_id(request[field]): return _failure()
	if not OPERATIONS.has(request["operation"]) or not ControlContractValidation.is_integer(request["tick"], 0, MAX_REVISION - 1) or not ControlContractValidation.is_integer(request["expected_revision"], 0, MAX_REVISION - 1): return _failure()
	var normalized: Dictionary = request.duplicate(true)
	normalized["tick"] = int(request["tick"])
	normalized["expected_revision"] = int(request["expected_revision"])
	var intent: String = JSON.stringify([actor_id, normalized], "", true, true).sha256_text()
	var receipts: Dictionary = record["receipts"]
	if receipts.has(request["request_id"]):
		var retained: Dictionary = receipts[request["request_id"]]
		if retained["actor_id"] != actor_id or retained["intent"] != intent: return _failure()
		return ServiceResult.success({"record": record.duplicate(true), "base_owner_revision": owner_revision, "effects": {}, "receipt": retained.duplicate(true), "replayed": true})
	if int(request["expected_revision"]) != int(record["revision"]) or receipts.size() >= MAX_RECEIPTS or int(record["revision"]) >= MAX_REVISION: return _failure()
	var next: Dictionary = record.duplicate(true)
	var jobs: Dictionary = next["jobs"]
	var id: String = request["job_id"]
	var operation: String = request["operation"]
	var tick: int = int(request["tick"])
	var effects: Dictionary = {}
	if operation == "reserve":
		if jobs.has(id) or jobs.size() >= MAX_JOBS or owner_iron_mg - claimed(record) < BILL: return _failure()
		jobs[id] = {"actor_id": actor_id, "blueprint_id": BLUEPRINT, "state": "active", "progress_ticks": 0, "last_tick": tick}
	else:
		if not jobs.has(id) or jobs[id]["actor_id"] != actor_id: return _failure()
		var job: Dictionary = jobs[id]
		if job["state"] in ["cancelled", "completed"] or tick < int(job["last_tick"]): return _failure()
		match operation:
			"advance":
				if job["state"] != "active" or tick != int(job["last_tick"]) + 1: return _failure()
				job["progress_ticks"] = int(job["progress_ticks"]) + 1
				if int(job["progress_ticks"]) == WORK_TICKS: job["state"] = "ready"
			"interrupt":
				if job["state"] not in ["active", "ready"]: return _failure()
				job["state"] = "paused"
			"resume":
				if job["state"] != "paused": return _failure()
				job["progress_ticks"] = mini(int(job["progress_ticks"]), WORK_TICKS - 1)
				job["state"] = "active"
			"cancel": job["state"] = "cancelled"
			"complete":
				if job["state"] != "ready" or tick != int(job["last_tick"]): return _failure()
				job["state"] = "completed"
				effects = {"debit_iron_milligrams": BILL, "blueprint_id": BLUEPRINT, "output_id": "reserved-canister-%s" % id.sha256_text().substr(0, 24)}
		job["last_tick"] = tick
	next["revision"] = int(next["revision"]) + 1
	var receipt: Dictionary = {"actor_id": actor_id, "intent": intent, "job_id": id, "operation": operation, "revision": next["revision"]}
	next["receipts"][request["request_id"]] = receipt
	return ServiceResult.success({"record": next, "base_owner_revision": owner_revision, "effects": effects, "receipt": receipt.duplicate(true), "replayed": false})


static func _failure() -> ServiceResult:
	return ServiceResult.failure(&"construction_reservation_denied", "Reservation state, authority, revision, stock or finite work preconditions failed.")
