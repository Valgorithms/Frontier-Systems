"""Validate real playable-origin snapshots and observations emitted by Godot."""
from copy import deepcopy
import json
from pathlib import Path
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(p.read_text(encoding="utf-8-sig")) for p in paths]
registry = Registry().with_resources([(s["$id"], Resource.from_contents(s)) for s in schemas if "$id" in s] + [(p.name, Resource.from_contents(s)) for p, s in zip(paths, schemas)])
fixture = json.loads((ROOT / "var/finite-bootstrap-fixture.json").read_text())
for field, name in [("world", "world-snapshot:v1"), ("persistent", "production-system:v12"), ("pristine", "production-system:v12"), ("observation", "production-observation:v14")]:
    schema = next(s for s in schemas if s.get("$id") == "urn:frontier-systems:schema:" + name)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, registry=registry)
    validator.validate(fixture[field])
    if field == "world":
        continue
    for key, value in [("catalog_revision", 1), ("schema_version", 99), ("catalog_fingerprint", "unknown")]:
        bad = deepcopy(fixture[field]); bad[key] = value
        assert not validator.is_valid(bad), (field, key)
    for mutation in ("missing", "excess", "foreign"):
        bad = deepcopy(fixture[field])
        if mutation == "missing": del bad["deposits"]["deposit.iron.outcrop"]
        elif mutation == "excess": bad["deposits"]["deposit.iron.outcrop"] = 7000001
        else: bad["deposits"]["client.ore"] = 1
        assert not validator.is_valid(bad), (field, mutation)
print("Finite bootstrap emitted schemas and negative controls passed.")
