"""Strict reinforcement contracts; emitted runtime evidence is required by CI."""
from copy import deepcopy
import json
from pathlib import Path
import sys

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(p.read_text(encoding="utf-8-sig")) for p in paths]
registry = Registry().with_resources(
    [(s["$id"], Resource.from_contents(s)) for s in schemas if "$id" in s]
    + [(p.name, Resource.from_contents(s)) for p, s in zip(paths, schemas)]
)


def validator(name):
    schema = next(s for s in schemas if s.get("$id") == "urn:frontier-systems:schema:" + name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


for name in ["production-system:v14", "production-observation:v16", "paid-door-observation:v5", "pressure-system:v4", "world-snapshot:v1"]:
    validator(name)
intent = validator("production-intent:v1")
for operation in ["door_reinforcement_install", "door_reinforcement_recover"]:
    value = {"operation": operation, "payload": {"expected_revision": 0, "control_epoch": 0, "door_id": "door-test"}}
    intent.validate(value)
    for field in ["health", "seal_condition", "integrity", "retention_kpa", "materials", "conductance", "principal_id", "gas_moles"]:
        bad = deepcopy(value)
        bad["payload"][field] = 1
        assert not intent.is_valid(bad), (operation, field)

if "--schema-only" in sys.argv:
    print("Reinforcement definitions and strict intent controls passed; runtime fixture not checked")
    sys.exit(0)

fixture = json.loads((ROOT / "var/room-reinforcement-fixture.json").read_text(encoding="utf-8"))
world = fixture["world"]
production = world["systems"]["production"]
pressure = world["systems"]["pressure"]
validator("world-snapshot:v1").validate(world)
validator("production-system:v14").validate(production)
validator("production-system:v14").validate(fixture["pristine"])
validator("pressure-system:v4").validate(pressure)
validator("production-observation:v16").validate(fixture["observation"])
assert production["catalog_revision"] == 3
assert sum(fixture["pristine"]["deposits"].values()) == 39000000
assert production["energy_joules"] == 56000
assert production["store"]["plate"] == 0
assert production["store"]["iron"] == 400000
assert production["store"]["tailings"] == 9600000
for field, value in [("blueprint_revision", True), ("blueprint_id", "client-rating"), ("health", 1)]:
    bad = deepcopy(production)
    next(iter(bad["room_reinforcements"].values()))[field] = value
    assert not validator("production-system:v14").is_valid(bad), field
for revision in [1, 2]:
    bad = deepcopy(fixture["pristine"])
    bad["catalog_revision"] = revision
    assert not validator("production-system:v14").is_valid(bad), revision
for field in ["reinforcement_installed", "reinforcement_intact"]:
    bad = deepcopy(fixture["observation"])
    bad["paid_doors"]["doors"][0][field] = 1
    assert not validator("production-observation:v16").is_valid(bad), field
print("Reinforcement real emitted world, finite budget, owners, observation and negative schemas passed")
