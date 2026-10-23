"""Validate real own-panel host observations; runtime enforces grid/closure coherence."""
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


def validator(version):
    schema = next(s for s in schemas if s.get("$id") == f"urn:frontier-systems:schema:production-observation:v{version}")
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, registry=registry)


fixture = json.loads((ROOT / "var/horizontal-panel-controls-fixture.json").read_text())
current = validator(11)
current.validate(fixture["current"])
for version, record in zip((7, 8, 9), fixture["legacy"]):
    validator(version).validate(record)
    assert not current.is_valid(record)
schema_rejections = 0
for record in fixture["malformed"]:
    if not current.is_valid(record):
        schema_rejections += 1
        continue
    # Unique IDs and same-owner revision coherence are runtime constraints.
    view = record["horizontal_panels"]
    ids = [s["surface_id"] for s in view["surfaces"]]
    assert len(ids) != len(set(ids)) or view["closure"]["production_revision"] != record["state_revision"]
print(f"Panel controls schemas: real v10, legacy v7-9, {schema_rejections} schema and {len(fixture['malformed']) - schema_rejections} semantic rejections passed")
