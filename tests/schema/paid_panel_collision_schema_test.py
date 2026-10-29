"""Validate emitted real-owner geometry; payment/overlap remain owner validation."""
import copy
import json
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((ROOT / "docs/schema/paid-panel-collision-descriptors-v1.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
fixture = json.loads((ROOT / "var/paid-panel-collision-fixture.json").read_text())
for record in fixture.values():
    validator.validate(record)
    for field in record:
        bad = copy.deepcopy(record)
        del bad[field]
        assert not validator.is_valid(bad), field
    for extra in ("principal_id", "materials", "surface_contact", "session_id"):
        assert not validator.is_valid(dict(record, **{extra: True})), extra
    for field in ("production_revision", "production_tick", "inventory_tick"):
        for value in (-1, True, 0.5):
            assert not validator.is_valid(dict(record, **{field: value})), field
    assert not validator.is_valid(dict(record, coordinate_frame="display_metres"))
    assert not validator.is_valid(dict(record, boxes=record["boxes"] * 65))
    for field in record["boxes"][0]:
        bad = copy.deepcopy(record)
        del bad["boxes"][0][field]
        assert not validator.is_valid(bad), field
    for field, value in (("center_millimetres", [0, 0, 0]), ("center_millimetres", [0.5, -6, 0]),
                         ("size_millimetres", [50, 0, 50]), ("size_millimetres", [1050, 12, 50]),
                         ("size_millimetres", [51, 12, 50]), ("principal_id", "foreign")):
        bad = copy.deepcopy(record)
        bad["boxes"][0][field] = value
        assert not validator.is_valid(bad), field
    for box in record["boxes"]:
        bad = copy.deepcopy(record)
        bad["boxes"] = [dict(box, kind="ceiling" if box["kind"] == "floor" else "floor")]
        assert not validator.is_valid(bad), "face-kind mismatch"
assert fixture["complete"]["production_revision"] == fixture["restored"]["production_revision"]
assert fixture["complete"]["boxes"] != fixture["restored"]["boxes"]
print("Paid panel collision real-owner result schemas: passed")
