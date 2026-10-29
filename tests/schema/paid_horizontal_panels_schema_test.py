"""Check actual owner persistence and retained legacy schema shape contracts."""
from copy import deepcopy
import json
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(p.read_text(encoding="utf-8-sig")) for p in paths]
registry = Registry().with_resources([(s["$id"], Resource.from_contents(s)) for s in schemas if "$id" in s] + [(p.name, Resource.from_contents(s)) for p, s in zip(paths, schemas)])


def validator(version):
    schema = next(s for s in schemas if s.get("$id") == f"urn:frontier-systems:schema:production-system:v{version}")
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


fixture = json.loads((ROOT / "var/paid-panels-fixture.json").read_text())
current = fixture["persistent"]
validator(11).validate(current)
validator(8).validate(fixture["legacy"])
assert not validator(8).is_valid(current)
for field, value in (("materials", {"plate": 0}), ("bounds_millimetres", [0, 50.5, 0, 1000]), ("blueprint_revision", 2), ("principal_id", ""), ("kind", "wall")):
    malformed = deepcopy(current)
    next(iter(malformed["panels"].values()))[field] = value
    assert not validator(11).is_valid(malformed), field
missing = deepcopy(current)
del missing["panels"]
assert not validator(11).is_valid(missing)
print("Paid panel schemas: actual v11, legacy v8 and six malformed records passed")
