"""Versioned chamber schemas; CI requires genuine emitted runtime fixtures."""
from copy import deepcopy
import json
from pathlib import Path
import sys

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(path.read_text(encoding="utf-8-sig")) for path in paths]
registry = Registry().with_resources(
    [(s["$id"], Resource.from_contents(s)) for s in schemas if "$id" in s]
    + [(p.name, Resource.from_contents(s)) for p, s in zip(paths, schemas)]
)


def validator(name):
    schema = next(s for s in schemas if s.get("$id") == "urn:frontier-systems:schema:" + name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


for name in ["production-system:v15", "production-observation:v17", "paid-door-observation:v6", "pressure-system:v5", "world-snapshot:v1"]:
    validator(name)
intent = validator("production-intent:v1")
for operation in ["door_chamber_kit_install", "door_chamber_kit_recover", "door_chamber_commission", "door_chamber_decommission"]:
    value = {"operation": operation, "payload": {"expected_revision": 0, "control_epoch": 0, "door_id": "door-test"}}
    intent.validate(value)
    for field in ["health", "seal_condition", "integrity", "retention_kpa", "materials", "principal_id", "endpoint", "gas_moles"]:
        bad = deepcopy(value)
        bad["payload"][field] = 1
        assert not intent.is_valid(bad), (operation, field)

if "--schema-only" in sys.argv:
    print("Chamber schema definitions and strict intents passed; emitted runtime fixture not checked")
    sys.exit(0)

fixture = json.loads((ROOT / "var/paid-chamber-fixture.json").read_text(encoding="utf-8"))
world = fixture["world"]
production = world["systems"]["production"]
pressure = world["systems"]["pressure"]
observation = fixture["observation"]
validator("world-snapshot:v1").validate(world)
validator("production-system:v15").validate(production)
validator("production-system:v15").validate(fixture["pristine"])
validator("pressure-system:v5").validate(pressure)
validator("production-observation:v17").validate(observation)
assert production["catalog_revision"] == 4
assert sum(fixture["pristine"]["deposits"].values()) == 54000000
assert production["energy_joules"] == 28250
assert production["store"]["plate"] == 600000
assert production["store"]["iron"] == 400000
assert production["store"]["tailings"] == 15600000
for field, value in [("materials", {"plate": 6000001}), ("policy_id", "client-rating"), ("health", 1)]:
    bad = deepcopy(production)
    next(iter(bad["chamber_kits"].values()))[field] = value
    assert not validator("production-system:v15").is_valid(bad), field
for field, value in [("outer_endpoint", "habitat_main"), ("policy_id", "client-rating"), ("retention_kpa", 999)]:
    bad = deepcopy(pressure)
    bad["paid_chamber"][field] = value
    assert not validator("pressure-system:v5").is_valid(bad), field
for field in ["chamber_kit_installed", "reinforcement_intact"]:
    bad = deepcopy(observation)
    bad["paid_doors"]["doors"][0][field] = 1
    assert not validator("production-observation:v17").is_valid(bad), field
for legacy_version in [11, 12, 13, 14]:
    bad = deepcopy(production)
    bad["schema_version"] = legacy_version
    assert not validator(f"production-system:v{legacy_version}").is_valid(bad)
print("Chamber genuine emitted finite budget, persistence, observation and negative schemas passed")
