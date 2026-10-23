"""Validate actual owner adapter output and reject forged/partial result shapes."""
import copy
import json
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((ROOT / "docs/schema/paid-floor-locomotion-result-v1.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
fixture = json.loads((ROOT / "var/paid-floor-locomotion-fixture.json").read_text())
for record in fixture.values():
    validator.validate(record)
    for field in record:
        bad = copy.deepcopy(record)
        del bad[field]
        assert not validator.is_valid(bad), field
    for extra in ("candidate_surface_ids", "principal_id", "position_millimetres", "surface_contact"):
        assert not validator.is_valid(dict(record, **{extra: True})), extra
    for field in ("production_revision", "production_tick", "inventory_tick", "body_action_epoch"):
        for invalid in (-1, True, 0.5):
            assert not validator.is_valid(dict(record, **{field: invalid})), field
    assert not validator.is_valid(dict(record, supported=1))
    for key in ("locomotion", "profiling"):
        bad = copy.deepcopy(record)
        bad[key]["extra"] = True
        assert not validator.is_valid(bad)
assert fixture["supported"]["supported"] is True
assert fixture["unsupported"]["supported"] is False
print("Paid floor locomotion actual owner results: schema controls passed")
