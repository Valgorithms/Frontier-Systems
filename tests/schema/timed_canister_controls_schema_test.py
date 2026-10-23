"""Validate actual host/UI projection fixtures with offline schema resolution."""
import json
from pathlib import Path
from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
paths = list((ROOT / "docs/schema").glob("*.schema.json"))
schemas = [json.loads(path.read_text(encoding="utf-8-sig")) for path in paths]
registry = Registry().with_resources(
    [(schema["$id"], Resource.from_contents(schema)) for schema in schemas if "$id" in schema]
    + [(path.name, Resource.from_contents(schema)) for path, schema in zip(paths, schemas)]
)


def validator(name):
    schema = next(schema for schema in schemas if schema.get("$id") == "urn:frontier-systems:schema:" + name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


fixture = json.loads((ROOT / "var/timed-canister-controls-fixture.json").read_text())
current = validator("production-observation:v12")
current.validate(fixture["current"])
validator("production-observation:v8").validate(fixture["legacy"])
assert not current.is_valid(fixture["legacy"])
for malformed in fixture["malformed"]:
    assert not current.is_valid(malformed)
print(f"Timed canister schema: actual v12, legacy v8 and {len(fixture['malformed'])} negative projections passed")
