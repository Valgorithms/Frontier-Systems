"""Validate emitted pressure-room contracts; run after paid_door_pressure_room_test.gd."""
from copy import deepcopy
import json
from pathlib import Path

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


fixture = json.loads((ROOT / "var/paid-door-pressure-fixture.json").read_text())
validator("world-snapshot:v1").validate(fixture["world"])
validator("production-observation:v13").validate(fixture["observation"])
pressure = fixture["world"]["systems"]["pressure"]
v = validator("pressure-system:v2")
v.validate(pressure)
for field, value in [("policy_id", "client-rated"), ("schema_version", True), ("region_id", "foreign"), ("extra", 1)]:
    bad = deepcopy(pressure)
    next(iter(bad["constructed_rooms"].values()))[field] = value
    assert not v.is_valid(bad), field
for operation in ["door_room_commission", "door_room_decommission"]:
    intent = {"operation": operation, "payload": {"door_id": "door-test", "expected_revision": 0, "control_epoch": 0}}
    validator("production-intent:v1").validate(intent)
    for field in ["pressure_kpa", "volume_m3", "policy_id", "principal_id"]:
        bad = deepcopy(intent)
        bad["payload"][field] = 1
        assert not validator("production-intent:v1").is_valid(bad), field
for field, value in [("volume_m3", 0), ("leaking", 1), ("extra", 1)]:
    bad = deepcopy(fixture["observation"])
    bad["paid_doors"]["doors"][0]["pressure_room"][field] = value
    assert not validator("production-observation:v13").is_valid(bad), field
print("Paid pressure-room emitted world/owner/observation, strict intents and malformed policy/observation checks passed")
