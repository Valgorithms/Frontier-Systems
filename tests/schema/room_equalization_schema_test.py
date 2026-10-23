"""Validate the finite manual bypass fixture, or definitions with --schema-only."""
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


for name in ["pressure-system:v3", "production-system:v13", "production-observation:v15", "paid-door-observation:v4", "world-snapshot:v1"]:
    validator(name)
intent = validator("production-intent:v1")
for operation in ["door_bypass_install", "door_bypass_open", "door_bypass_close", "door_bypass_recover"]:
    value = {"operation": operation, "payload": {"expected_revision": 0, "control_epoch": 0, "door_id": "door-test"}}
    intent.validate(value)
    for field in ["gas_moles", "conductance", "principal_id", "ambient_id", "materials", "pressure_kpa"]:
        bad = deepcopy(value)
        bad["payload"][field] = 1
        assert not intent.is_valid(bad), (operation, field)

if "--schema-only" in sys.argv:
    print("Bypass schema definitions and strict positive/negative intent controls passed; runtime fixture not checked")
    sys.exit(0)

fixture = json.loads((ROOT / "var/room-equalization-fixture.json").read_text())
validator("world-snapshot:v1").validate(fixture["world"])
validator("world-snapshot:v1").validate(fixture["legacy_world"])
validator("production-system:v13").validate(fixture["world"]["systems"]["production"])
validator("pressure-system:v3").validate(fixture["world"]["systems"]["pressure"])
validator("production-observation:v15").validate(fixture["observation"])
part = fixture["world"]["systems"]["production"]["room_bypasses"]
assert len(part) == 1
for field, value in [("blueprint_revision", True), ("blueprint_id", "client-hardware"), ("extra", 1)]:
    bad = deepcopy(fixture["world"]["systems"]["production"])
    next(iter(bad["room_bypasses"].values()))[field] = value
    assert not validator("production-system:v13").is_valid(bad), field
for value in [1, "open", None, {}]:
    bad = deepcopy(fixture["world"]["systems"]["pressure"])
    bad["room_valves"][next(iter(part))] = value
    assert not validator("pressure-system:v3").is_valid(bad), value
for field in ["bypass_installed", "bypass_open"]:
    bad = deepcopy(fixture["observation"])
    bad["paid_doors"]["doors"][0][field] = 1
    assert not validator("production-observation:v15").is_valid(bad), field
print("Bypass emitted finite world/owners/observation, legacy world, strict intents and malformed controls passed")
