"""Phase 1 backend schemas; runtime mode requires the genuine paid-route fixture."""
from copy import deepcopy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(path.read_text(encoding="utf-8-sig")) for path in paths]
names = ["chamber-recovery-accounting:v1", "chamber-recovery-assembly:v1",
         "chamber-recovery-job:v1", "chamber-recovery:v1",
         "production-system:v16", "pressure-system:v6", "world-snapshot:v1"]
by_id = {schema["$id"]: schema for schema in schemas if "$id" in schema}
for name in names:
    assert "urn:frontier-systems:schema:" + name in by_id, name
if "--syntax-only" in sys.argv:
    print("Schema JSON syntax and required identities passed; no metaschema or runtime validation")
    sys.exit(0)

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

registry = Registry().with_resources(
    [(schema["$id"], Resource.from_contents(schema)) for schema in schemas if "$id" in schema]
    + [(path.name, Resource.from_contents(schema)) for path, schema in zip(paths, schemas)]
)


def validator(name):
    schema = by_id["urn:frontier-systems:schema:" + name]
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


for name in names:
    validator(name)
if "--schema-only" in sys.argv:
    print("Phase 1 backend metaschemas passed; runtime fixture not checked")
    sys.exit(0)

world = json.loads((ROOT / "var/chamber-recovery-fixture.json").read_text(encoding="utf-8"))
production = world["systems"]["production"]
pressure = world["systems"]["pressure"]
validator("world-snapshot:v1").validate(world)
validator("production-system:v16").validate(production)
validator("pressure-system:v6").validate(pressure)
assert production["energy_joules"] == 27250
assert production["store"]["plate"] == production["store"]["iron"] == 200000
recovery = production["chamber_recovery"]
assert recovery["accounting"] == pressure["pump_accounting"]
assert len(recovery["assemblies"]) == len(recovery["jobs"]) == 1
assert recovery["assemblies"][0]["state"] == "mounted"
assert recovery["jobs"][0]["max_joules"] == 25000
assert recovery["jobs"][0]["target_moles"] == recovery["jobs"][0]["initial_moles"] * 0.2
for field, value in [("assembly_spent_joules", 0), ("definition_revision", 2),
                     ("materials", {"plate": 400000, "iron": 200001}), ("free_energy", 1)]:
    bad = deepcopy(production)
    bad["chamber_recovery"]["assemblies"][0][field] = value
    assert not validator("production-system:v16").is_valid(bad), field
for field, value in [("max_joules", 25001), ("spent_joules", -1),
                     ("next_eligible_tick", 9007199254740001), ("target_moles", -1)]:
    bad = deepcopy(production)
    bad["chamber_recovery"]["jobs"][0][field] = value
    assert not validator("production-system:v16").is_valid(bad), field
for field, value in [("sequence", -1), ("last_quantity_moles", 0.100001),
                     ("last_charged_joules", 251), ("paid_joules", 100001)]:
    bad = deepcopy(pressure)
    bad["pump_accounting"][field] = value
    assert not validator("pressure-system:v6").is_valid(bad), field
assert not validator("production-system:v15").is_valid(production)
assert not validator("pressure-system:v5").is_valid(pressure)
print("Genuine paid-route Phase 1 backend fixture and schema negatives passed")
