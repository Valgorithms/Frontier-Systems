"""Validate real runtime query/results and structural negative controls."""
import copy
import json
from pathlib import Path
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
fixture = json.loads((ROOT / "var/horizontal-floor-support-fixture.json").read_text())
for name, keys in (("query", ["request"]), ("result", ["supported", "unsupported"])):
    schema = json.loads((ROOT / f"docs/schema/horizontal-floor-support-{name}-v1.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    for key in keys:
        record = fixture[key]
        validator.validate(record)
        for field in record:
            bad = copy.deepcopy(record)
            del bad[field]
            assert not validator.is_valid(bad), field
        bad = dict(record, extra=True)
        assert not validator.is_valid(bad)
    record = fixture[keys[0]]
    if name == "query":
        for field, value in [("expected_production_revision", -1), ("vertical_tolerance_millimetres", 101), ("foot_height_millimetres", True), ("footprint_millimetres", [0, 0.5, 0, 100])]:
            assert not validator.is_valid(dict(record, **{field: value}))
    else:
        assert not validator.is_valid(dict(record, candidate_surface_ids=["same", "same"]))
        assert not validator.is_valid(dict(record, supported=1))
assert fixture["supported"]["supported"] is True
assert fixture["unsupported"]["supported"] is False
print("Floor support request and real supported/unsupported results: schema controls passed")
