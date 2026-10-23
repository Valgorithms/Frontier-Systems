extends RefCounted
class_name ChamberRecoveryRecords

## Bounded paid provenance and accounting. Production owns these jobs and bank;
## Pressure carries only the identical audit value, never a second energy bank.
const DEFINITION: String = "item.chamber-recovery-pump.fabricated"
const BLUEPRINT: String = "blueprint.chamber-recovery-pump.v1"
const MASS: int = 600000
const ASSEMBLY_JOULES: int = 1000
const MAX_ASSEMBLIES: int = 32
const MAX_JOBS: int = 128
const LIMIT: int = 9007199254740000
const ANCHOR: Array = [5600, 0, -4400]
const BILL: Dictionary = {"plate": 400000, "iron": 200000}


static func initial() -> Dictionary:
	return {"schema_version": 1, "assemblies": [], "jobs": [], "accounting": empty_accounting()}


static func empty_accounting() -> Dictionary:
	return {"schema_version": 1, "sequence": 0, "last_assembly_id": "", "last_job_id": "", "last_batch_tick": 0, "last_quantity_moles": 0.0, "last_charged_joules": 0, "returned_moles": 0.0, "paid_joules": 0, "jobs": []}


static func fingerprint() -> String:
	return JSON.stringify(blueprint(), "", true).sha256_text()


static func blueprint() -> Dictionary:
	return {"schema_version": 1, "blueprint_id": BLUEPRINT, "definition_id": DEFINITION, "definition_revision": 1, "materials_milligrams": BILL.duplicate(), "assembly_joules": ASSEMBLY_JOULES, "external_volume_millilitres": 6000}


static func definition() -> Dictionary:
	return {"schema_version": 1, "definition_id": DEFINITION, "revision": 1, "tags": ["item.handheld", "equipment.chamber-pump"], "mass_milligrams": 0, "volume_millilitres": 6000, "storage": null}


static func matches_definition(value: Variant) -> bool:
	return _matches_pinned(value, definition())


static func matches_blueprint(value: Variant) -> bool:
	return _matches_pinned(value, blueprint())


## JSON numbers decode as floats; Dictionary equality distinguishes them from
## integer literals. Validate exact quantities before conversion, never truncate.
static func _matches_pinned(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_INT:
		return ControlContractValidation.is_integer(value, expected, expected)
	if typeof(value) != typeof(expected): return false
	if typeof(expected) == TYPE_DICTIONARY:
		if value.size() != expected.size(): return false
		for key in expected:
			if not value.has(key) or not _matches_pinned(value[key], expected[key]): return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if value.size() != expected.size(): return false
		for index in range(expected.size()):
			if not _matches_pinned(value[index], expected[index]): return false
		return true
	return value == expected


static func root_id(assembly_id: String) -> String:
	return "world.chamber-pump-%s" % assembly_id


static func capacity() -> Dictionary:
	return {"max_mass_milligrams": MASS, "max_volume_millilitres": 6000, "max_items": 1, "accepted_tags": ["equipment.chamber-pump"]}


static func current(value: Dictionary) -> Dictionary:
	for assembly in value.get("assemblies", []):
		if assembly.state != "salvaged": return assembly
	return {}


static func active_job(value: Dictionary) -> Dictionary:
	for job in value.get("jobs", []):
		if job.state in ["running", "paused"]: return job
	return {}


static func mass(state: Dictionary) -> int:
	return 0 if current(state.get("chamber_recovery", {})).is_empty() else MASS


static func payloads(state: Dictionary) -> Dictionary:
	var assembly: Dictionary = current(state.get("chamber_recovery", {}))
	return {} if assembly.is_empty() else {assembly.item_id: MASS}


static func fields(value: Variant, names: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and ControlContractValidation.has_exact_fields(value, PackedStringArray(names))


static func number(value: Variant, minimum: float = 0.0) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum


static func integer(value: Variant, minimum: int = 0, maximum: int = LIMIT) -> bool:
	return ControlContractValidation.is_integer(value, minimum, maximum)


static func summary(job: Dictionary) -> Dictionary:
	return {"job_id": job.job_id, "assembly_id": job.assembly_id, "returned_moles": job.returned_moles, "paid_joules": job.spent_joules}


static func valid_accounting(value: Variant, tick: int) -> bool:
	if not fields(value, ["schema_version", "sequence", "last_assembly_id", "last_job_id", "last_batch_tick", "last_quantity_moles", "last_charged_joules", "returned_moles", "paid_joules", "jobs"]): return false
	if not integer(value.schema_version, 1, 1) or not integer(value.sequence) or not integer(value.last_batch_tick, 0, tick) or not integer(value.last_charged_joules, 0, 250) or not integer(value.paid_joules, 0, 100000): return false
	if not number(value.returned_moles) or not number(value.last_quantity_moles) or float(value.last_quantity_moles) > 0.1 or typeof(value.jobs) != TYPE_ARRAY or value.jobs.size() > MAX_JOBS: return false
	var returned: float = 0.0
	var paid: int = 0
	var last_found: bool = false
	for index in range(value.jobs.size()):
		var job: Variant = value.jobs[index]
		if not fields(job, ["job_id", "assembly_id", "returned_moles", "paid_joules"]): return false
		if job.job_id != "chamber-recovery-job-%d" % (index + 1) or not ControlContractValidation.is_id(job.assembly_id) or not number(job.returned_moles) or not integer(job.paid_joules, 0, 25000): return false
		if (float(job.returned_moles) == 0.0) != (int(job.paid_joules) == 0): return false
		returned += float(job.returned_moles)
		paid += int(job.paid_joules)
		if job.job_id == value.last_job_id and job.assembly_id == value.last_assembly_id and float(job.returned_moles) >= float(value.last_quantity_moles) and int(job.paid_joules) >= int(value.last_charged_joules): last_found = true
	if returned != float(value.returned_moles) or paid != int(value.paid_joules): return false
	if int(value.sequence) == 0: return value.last_assembly_id == "" and value.last_job_id == "" and int(value.last_batch_tick) == 0 and float(value.last_quantity_moles) == 0.0 and int(value.last_charged_joules) == 0 and returned == 0.0 and paid == 0
	return last_found and float(value.last_quantity_moles) > 0.0 and int(value.last_charged_joules) > 0 and int(value.sequence) <= paid


static func valid(value: Variant, bank: int, tick: int) -> bool:
	if not fields(value, ["schema_version", "assemblies", "jobs", "accounting"]) or not integer(value.schema_version, 1, 1): return false
	if typeof(value.assemblies) != TYPE_ARRAY or value.assemblies.size() > MAX_ASSEMBLIES or typeof(value.jobs) != TYPE_ARRAY or value.jobs.size() > MAX_JOBS or not valid_accounting(value.accounting, tick): return false
	var assemblies: Dictionary = {}
	var living: int = 0
	for index in range(value.assemblies.size()):
		var assembly: Variant = value.assemblies[index]
		if not fields(assembly, ["schema_version", "assembly_id", "item_id", "definition_id", "definition_revision", "blueprint_id", "blueprint_fingerprint", "materials", "principal_id", "body_id", "world_id", "region_id", "chamber_id", "original_condition_permille", "assembly_spent_joules", "state"]): return false
		if not integer(assembly.schema_version, 1, 1) or assembly.assembly_id != "chamber-recovery-assembly-%d" % (index + 1) or assembly.item_id != "item-%s" % assembly.assembly_id: return false
		if assembly.definition_id != DEFINITION or not integer(assembly.definition_revision, 1, 1) or assembly.blueprint_id != BLUEPRINT or assembly.blueprint_fingerprint != fingerprint() or assembly.materials != BILL: return false
		if not integer(assembly.original_condition_permille, 1000, 1000) or not integer(assembly.assembly_spent_joules, ASSEMBLY_JOULES, ASSEMBLY_JOULES) or assembly.state not in ["carried", "mounted", "salvaged"]: return false
		for key in ["principal_id", "body_id", "world_id", "region_id", "chamber_id"]:
			if not ControlContractValidation.is_id(assembly[key]): return false
		assemblies[assembly.assembly_id] = assembly
		if assembly.state != "salvaged": living += 1
	if living > 1 or bank < 0 or bank + value.assemblies.size() * ASSEMBLY_JOULES + int(value.accounting.paid_joules) > 100000: return false
	if value.accounting.jobs.size() != value.jobs.size(): return false
	var active: int = 0
	for index in range(value.jobs.size()):
		var job: Variant = value.jobs[index]
		if not fields(job, ["schema_version", "job_id", "assembly_id", "principal_id", "body_id", "control_epoch", "initial_moles", "target_moles", "returned_moles", "spent_joules", "max_joules", "state", "last_batch_tick", "next_eligible_tick"]): return false
		if not integer(job.schema_version, 1, 1) or job.job_id != "chamber-recovery-job-%d" % (index + 1) or not assemblies.has(job.assembly_id): return false
		var assembly: Dictionary = assemblies[job.assembly_id]
		if job.principal_id != assembly.principal_id or job.body_id != assembly.body_id or not integer(job.control_epoch): return false
		if not number(job.initial_moles) or float(job.initial_moles) <= 0.0 or not number(job.target_moles) or float(job.target_moles) != float(job.initial_moles) * 0.2 or not number(job.returned_moles) or float(job.returned_moles) > float(job.target_moles): return false
		if not integer(job.max_joules, 1, 25000) or not integer(job.spent_joules, 0, int(job.max_joules)) or not integer(job.last_batch_tick, 0, tick) or not integer(job.next_eligible_tick, 0, LIMIT): return false
		if (float(job.returned_moles) == 0.0) != (int(job.spent_joules) == 0) or (int(job.spent_joules) == 0) != (int(job.last_batch_tick) == 0): return false
		if job.state not in ["running", "paused", "completed", "cancelled"] or (job.state == "completed") != (float(job.returned_moles) == float(job.target_moles)): return false
		if job.state in ["running", "paused"]:
			active += 1
			if assembly.state != "mounted" or int(job.next_eligible_tick) < int(job.last_batch_tick) + 60: return false
		if value.accounting.jobs[index] != summary(job): return false
	return active <= 1


static func inventory_links(state: Dictionary, inventory: Dictionary) -> bool:
	var recovery: Dictionary = state.get("chamber_recovery", initial())
	var active: Dictionary = current(recovery)
	var owner: Dictionary = inventory.get("owner", {})
	var items: Array = owner.get("ledger", {}).get("items", [])
	var found: int = 0
	if not active.is_empty():
		var matching_body: bool = false
		for body in inventory.get("bodies", []):
			if body.body_id == active.body_id and body.principal_id == active.principal_id: matching_body = true
		if not matching_body: return false
		if active.state == "mounted" and not ChamberRecoveryPreparation.supported(state): return false
	for job in recovery.jobs:
		var valid_binding: bool = false
		for body in inventory.get("bodies", []):
			if body.body_id == job.body_id and body.principal_id == job.principal_id and int(body.control_epoch) >= int(job.control_epoch): valid_binding = true
		if not valid_binding: return false
	for item in items:
		if item.definition_id != DEFINITION: continue
		found += 1
		if active.is_empty() or item.item_id != active.item_id or int(item.definition_revision) != 1 or int(item.condition_permille) > int(active.original_condition_permille): return false
		if active.state == "mounted":
			if item.container_id != root_id(active.assembly_id): return false
		else:
			# Carried items may be nested; the real owner decoder has already checked
			# the graph. Follow containers without inventing another catalog.
			var roots: Dictionary = {}
			for container in owner.ledger.containers: roots[container.container_id] = container.owner_item_id
			var locations: Dictionary = {}
			for physical in items: locations[physical.item_id] = physical.container_id
			var root: String = item.container_id
			for depth in range(65):
				if not roots.has(root): return false
				if roots[root] == "": break
				if not locations.has(roots[root]) or depth == 64: return false
				root = locations[roots[root]]
			var matched: bool = false
			for body in owner.get("bodies", []):
				if body.body_id == active.body_id and body.body_container_id == root: matched = true
			if not matched: return false
	if found != (0 if active.is_empty() else 1): return false
	for assembly in recovery.assemblies:
		if state.get("cargo", {}).has(assembly.item_id) or state.get("structures", {}).has(assembly.item_id) or state.get("loose_parts", {}).has(assembly.item_id) or state.get("machinery", {}).get("parts", {}).has(assembly.item_id): return false
	var expected: String = root_id(active.assembly_id) if not active.is_empty() and active.state == "mounted" else ""
	var roots_found: int = 0
	var locations_found: int = 0
	for container in owner.get("ledger", {}).get("containers", []):
		if not String(container.container_id).begins_with("world.chamber-pump-"): continue
		if container.container_id != expected or container.owner_item_id != "" or container.capacity != capacity() or container.get("is_open", true) != true: return false
		roots_found += 1
	for location in inventory.get("world_storage", []):
		if not String(location.container_id).begins_with("world.chamber-pump-"): continue
		if location.container_id != expected or location.position_millimetres != ANCHOR or location.accessible != false: return false
		locations_found += 1
	return roots_found == (1 if expected != "" else 0) and locations_found == roots_found


static func denied() -> ServiceResult:
	return ServiceResult.failure(&"chamber_recovery_rejected", "Paid chamber recovery provenance, accounting or admission is invalid.")
