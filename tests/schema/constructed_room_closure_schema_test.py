"""Shape checks; geometric semantics are exercised by the Godot regression."""
from copy import deepcopy
import json
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
NAMES = (
    "constructed-room-closure-v1.schema.json",
    "constructed-room-surface-v1.schema.json",
    "constructed-wall-boundaries-v1.schema.json",
)
schemas = {
    name: json.loads((ROOT / "docs/schema" / name).read_text(encoding="utf-8"))
    for name in NAMES
}
for schema in schemas.values():
    Draft202012Validator.check_schema(schema)
registry = Registry().with_resources(
    (name, Resource.from_contents(schema)) for name, schema in schemas.items()
)
validator = Draft202012Validator(schemas[NAMES[0]], registry=registry)
fixture = {
    "schema_version": 1,
    "production_revision": 42,
    "walls": {"schema_version": 1, "production_revision": 42, "boundaries": []},
    "surfaces": [{
        "surface_id": "floor-a", "kind": "floor",
        "bounds_millimetres": [5100, 6900, -4500, -3500],
        "height_millimetres": 0,
    }],
}
validator.validate(fixture)
ceiling = deepcopy(fixture)
ceiling["surfaces"][0].update(kind="ceiling", height_millimetres=2000)
validator.validate(ceiling)
invalids = []
for key in fixture:
    bad = deepcopy(fixture)
    del bad[key]
    invalids.append(bad)
for key, values in {
    "surface_id": ["", " ", "x" * 129, True],
    "kind": ["wall", True],
    "height_millimetres": [1, 2000, True, 0.5],
    "bounds_millimetres": [[0, 1, 2], [0, 1, 2, 3, 4], [True, 1, 2, 3],
                           [0.5, 1, 2, 3], [-100501, 1, 2, 3]],
}.items():
    for value in values:
        bad = deepcopy(fixture)
        bad["surfaces"][0][key] = value
        invalids.append(bad)
for value in [-1, 9007199254740001, True, 1.5]:
    bad = deepcopy(fixture)
    bad["production_revision"] = value
    invalids.append(bad)
bad = deepcopy(fixture)
bad["surfaces"] *= 65
invalids.append(bad)
bad = deepcopy(fixture)
bad["surfaces"][0]["paid"] = True
invalids.append(bad)
bad = deepcopy(ceiling)
bad["surfaces"][0]["height_millimetres"] = 0
invalids.append(bad)
for bad in invalids:
    assert not validator.is_valid(bad), bad
print(f"Room closure schemas: 3 valid schemas, floor/ceiling and {len(invalids)} rejection controls passed.")
