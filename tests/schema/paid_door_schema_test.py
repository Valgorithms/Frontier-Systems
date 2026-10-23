"""Validate emitted paid door owner, observation and collision contracts."""
from copy import deepcopy
import json
from pathlib import Path
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(p.read_text(encoding="utf-8-sig")) for p in paths]
registry = Registry().with_resources([(s["$id"], Resource.from_contents(s)) for s in schemas if "$id" in s] + [(p.name, Resource.from_contents(s)) for p, s in zip(paths, schemas)])
def validator(name):
    s = next(s for s in schemas if s.get("$id") == "urn:frontier-systems:schema:" + name)
    Draft202012Validator.check_schema(s)
    return Draft202012Validator(s, registry=registry)
f = json.loads((ROOT / "var/paid-door-fixture.json").read_text())
for field, name in [("persistent", "production-system:v11"), ("legacy", "production-system:v9"), ("observation", "production-observation:v13"), ("contact", "door-contact:v1")]:
    validator(name).validate(f[field])
for field, value in [("materials", {"plate": 0}), ("body_id", ""), ("quarter_turn", 2), ("position", [0, 50, 0]), ("blueprint_revision", 2)]:
    bad = deepcopy(f["persistent"])
    next(iter(bad["doors"].values()))[field] = value
    assert not validator("production-system:v11").is_valid(bad), field
for operation in ["door_build", "door_open", "door_close", "door_remove"]:
    payload = {"expected_revision": 0, "control_epoch": 0}
    payload.update({"position": [0, 0, 0], "quarter_turn": 0} if operation == "door_build" else {"door_id": "door-test"})
    v = validator("production-intent:v1")
    v.validate({"operation": operation, "payload": payload})
    payload["principal_id"] = "forged"
    assert not v.is_valid({"operation": operation, "payload": payload})
print("Paid door schemas: emitted save/legacy/observation/contact, five malformed saves and four strict intents passed")

seal_fixture = json.loads((ROOT / "var/paid-door-seal-fixture.json").read_text())
validator("production-system:v11").validate(seal_fixture["persistent"])
validator("production-observation:v13").validate(seal_fixture["observation"])
for field, value in [("materials", {"plate": 0}), ("blueprint_revision", True), ("materials", {"plate": 200000.5}), ("seal_id", "forged")]:
    bad = deepcopy(seal_fixture["persistent"])
    next(iter(bad["doors"].values()))["seal"][field] = value
    assert not validator("production-system:v11").is_valid(bad), field
for operation in ["door_seal_install", "door_seal_remove"]:
    v = validator("production-intent:v1")
    payload = {"expected_revision": 0, "control_epoch": 0, "door_id": "door-test"}
    v.validate({"operation": operation, "payload": payload})
    payload["materials"] = {"plate": 1}
    assert not v.is_valid({"operation": operation, "payload": payload})
print("Paid gasket emitted save/observation, malformed provenance and strict install/remove intents passed")

# Exercise the public save wrapper with populated current and legacy doors.
world = {"schema_version": 1, "world_id": "seal-schema-world", "region_id": "seal-schema-region", "tick_number": 0, "systems": {"production": seal_fixture["persistent"]}}
wrapper = validator("world-snapshot:v1")
wrapper.validate(world)
old = deepcopy(world)
old["systems"]["production"] = deepcopy(f["persistent"])
old["systems"]["production"]["schema_version"] = 10
for door in old["systems"]["production"]["doors"].values():
    door.pop("seal")
wrapper.validate(old)
for version in [12, True, 10]:
    bad = deepcopy(world)
    bad["systems"]["production"]["schema_version"] = version
    assert not wrapper.is_valid(bad), version
bad = deepcopy(world)
next(iter(bad["systems"]["production"]["doors"].values()))["seal"]["extra"] = 1
assert not wrapper.is_valid(bad)
print("World wrapper accepts current/legacy populated doors and rejects unsupported/mismatched versions and extra seal fields")
