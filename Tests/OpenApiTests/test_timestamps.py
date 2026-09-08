"""Offline response-contract tests.

python -m pip install -r Tests/OpenApiTests/requirements.txt
python -B -m unittest discover -s Tests/OpenApiTests -v
"""

import unittest
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator


OPENAPI = Path(__file__).resolve().parents[2] / "openapi"
SECTIONS = {
    "air-quality": ("current", "hourly"),
    "climate": ("daily",),
    "ensemble": ("hourly", "daily"),
    "flood": ("daily",),
    "forecast": ("current", "minutely_15", "hourly", "daily"),
    "historical-weather": ("hourly", "daily"),
    "marine": ("current", "minutely_15", "hourly", "daily"),
    "seasonal": ("hourly", "daily", "weekly", "monthly"),
}
SOLAR_APIS = ("forecast", "historical-weather")
TIME_SAMPLES = (
    ("iso8601", "2026-09-08T00:00"),
    ("unixtime", 1788825600),
    ("unixtime", -315619200),  # Historical data before 1970.
    ("unixtime", 2208988800),  # Climate projections beyond signed 32-bit epochs.
)


class TimestampContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schemas = {}
        for name in SECTIONS:
            document = yaml.safe_load((OPENAPI / f"{name}.yml").read_text(encoding="utf-8"))
            operation = next(iter(document["paths"].values()))["get"]
            schema = operation["responses"]["200"]["content"]["application/json"]["schema"]
            Draft202012Validator.check_schema(schema)
            cls.schemas[name] = schema

    def test_both_timeformats(self):
        # Shapes follow JsonWriter.swift: current is scalar, other sections are arrays.
        for name, sections in SECTIONS.items():
            for timeformat, timestamp in TIME_SAMPLES:
                with self.subTest(api=name, timeformat=timeformat, timestamp=timestamp):
                    response = {}
                    for section in sections:
                        value = timestamp
                        if timeformat == "iso8601" and section in ("daily", "weekly", "monthly"):
                            value = "2026-09-08"
                        response[section] = {"time": value if section == "current" else [value]}
                        response[f"{section}_units"] = {"time": timeformat}
                    if name in SOLAR_APIS:
                        response["daily"].update(sunrise=[timestamp], sunset=[timestamp])
                        response["daily_units"].update(sunrise=timeformat, sunset=timeformat)
                    Draft202012Validator(self.schemas[name]).validate(response)

    def test_timestamp_types_are_not_unrestricted(self):
        for name, sections in SECTIONS.items():
            for section in sections:
                fields = ("time", "sunrise", "sunset") if name in SOLAR_APIS and section == "daily" else ("time",)
                for field in fields:
                    # Require the field to be documented, not silently accepted as an extra property.
                    self.assertIn(field, self.schemas[name]["properties"][section]["properties"])
                    invalid_values = [True, 1788825600.5, {}, []]
                    for value in invalid_values:
                        with self.subTest(api=name, section=section, field=field, value=value):
                            response = {section: {field: value if section == "current" else [value]}}
                            self.assertFalse(Draft202012Validator(self.schemas[name]).is_valid(response))

    def test_time_units_remain_strings(self):
        for name, sections in SECTIONS.items():
            for section in sections:
                fields = ("time", "sunrise", "sunset") if name in SOLAR_APIS and section == "daily" else ("time",)
                for field in fields:
                    with self.subTest(api=name, section=section, field=field):
                        response = {f"{section}_units": {field: 1788825600}}
                        self.assertFalse(Draft202012Validator(self.schemas[name]).is_valid(response))


if __name__ == "__main__":
    unittest.main()
