"""Validate emitted host envelopes and complete collision-only geometry."""
import copy
import json
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((ROOT / "docs/schema/paid-panel-contact-observation-v1.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
fixture = json.loads((ROOT / "var/paid-panel-contact-fixture.json").read_text())
for record in fixture.values():
    validator.validate(record)
    for field in record:
        bad = copy.deepcopy(record)
        del bad[field]
        assert not validator.is_valid(bad), field
    for field in ("sequence", "inventory_restore", "production_restore"):
        for value in (-1, True, 0.5, 9007199254740001):
            assert not validator.is_valid(dict(record, **{field: value})), field
    for field in ("principal_id", "materials", "session_id", "session_epoch", "movement_grant"):
        assert not validator.is_valid(dict(record, **{field: True})), field
    bad = copy.deepcopy(record)
    bad["geometry"]["boxes"] *= 65
    if record["geometry"]["boxes"]:
        assert not validator.is_valid(bad), "capacity"
        bad = copy.deepcopy(record)
        bad["geometry"]["boxes"][0]["size_millimetres"][0] = 51
        assert not validator.is_valid(bad), "grid"
assert fixture["complete"]["geometry"]["production_revision"] == fixture["restored"]["geometry"]["production_revision"]
assert fixture["complete"]["production_restore"] < fixture["restored"]["production_restore"]
assert fixture["complete"]["geometry"]["boxes"] != fixture["restored"]["geometry"]["boxes"]
assert fixture["atomic"]["inventory_restore"] > fixture["complete"]["inventory_restore"]
assert fixture["empty"]["geometry"]["boxes"] == []
print("Paid panel contact emitted host envelope schemas: passed")
