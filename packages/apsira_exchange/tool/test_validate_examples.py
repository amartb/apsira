# From lyceum tool/exchange/test_validate_examples.py @ 9f4ff27, with
# VIATICUM's rules (tool/exchange/validate_examples.py @ 78d38e0) (D-APK-019).
"""Checks for tool/validate_examples.py on VIATICUM's and LYCEUM's exchange folders.

Run from the package directory:
    python3 -I -B -m unittest discover -s tool -p 'test_*.py'
Needs Python 3 and jsonschema >= 4, like the validator it checks. The two
`exchange/` folders are copied from VIATICUM v1.0.0 and LYCEUM v1.0.0 under
test/fixtures/exchange/. Scratch files go to build/army/scratch/exchange-test,
never /tmp.
"""

import contextlib
import hashlib
import io
import json
import shutil
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import validate_examples as v  # noqa: E402

PACKAGE = HERE.parent
FIXTURES = PACKAGE / "test" / "fixtures" / "exchange"
LYCEUM = FIXTURES / "lyceum-v1.0.0"
VIATICUM = FIXTURES / "viaticum-v1.0.0"
VALID = LYCEUM / "examples" / "valid"
INVALID = LYCEUM / "examples" / "invalid"
SCRATCH = PACKAGE / "build" / "army" / "scratch" / "exchange-test"


def _quiet(call, *args, **kwargs):
    """call(*args) with the validator's verdict lines kept off the test output."""
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return call(*args, **kwargs)


def _canonical(document):
    """The app's canonical JSON: sorted keys, no whitespace, a final LF."""
    text = json.dumps(document, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return (text + "\n").encode("utf-8")


class _Scratch(unittest.TestCase):
    def setUp(self):
        shutil.rmtree(SCRATCH, ignore_errors=True)
        SCRATCH.mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(SCRATCH, ignore_errors=True)

    def _rules(self, verdict):
        return {e["rule"] for e in verdict["errors"]}


class BothAppsTest(_Scratch):
    """AC-14.5: each app's committed examples have their expected verdicts."""

    def test_every_viaticum_example_has_its_expected_verdict(self):
        args = ["--schemas", str(VIATICUM / "schemas"), "--examples", str(VIATICUM / "examples"), "--check"]
        self.assertEqual(_quiet(v.main, args), 0)

    def test_every_lyceum_example_and_pair_has_its_expected_verdict(self):
        args = ["--schemas", str(LYCEUM / "schemas"), "--examples", str(LYCEUM / "examples"),
                "--check", "--pairs"]
        self.assertEqual(_quiet(v.main, args), 0)

    def test_each_valid_file_passes_and_each_invalid_file_fails_its_rule(self):
        for root in (VIATICUM, LYCEUM):
            validators = v.validators(root / "schemas")
            profile = validators["_profile"]
            examples = root / "examples"
            valid = sorted((examples / "valid").glob("*.json")) if profile.name == "envelope" \
                else sorted(examples.glob("*.json"))
            self.assertTrue(valid)
            for path in valid:
                with self.subTest(path.name):
                    kind, _ = v._valid_kind(profile, path.name)
                    self.assertTrue(v.validate(kind, path, validators)["valid"])
            invalid = sorted((examples / "invalid").glob("*.json"))
            self.assertTrue(invalid)
            for path in invalid:
                with self.subTest(path.name):
                    kind, rule = v._invalid_kind(profile, path.name)
                    verdict = v.validate(kind, path, validators)
                    self.assertFalse(verdict["valid"])
                    self.assertEqual(self._rules(verdict), {rule})

    def test_the_profile_follows_the_schemas(self):
        self.assertEqual(v.profile_of(VIATICUM / "schemas").name, "viaticum")
        envelope = v.profile_of(LYCEUM / "schemas")
        self.assertEqual(envelope.name, "envelope")
        self.assertEqual(envelope.schemas, {"export": "lyceum-export", "manifest": "export-manifest"})
        self.assertEqual(envelope.app, "lyceum")
        with self.assertRaises(SystemExit):
            v.profile_of(SCRATCH)

    def test_a_planted_wrong_example_makes_each_check_fail(self):
        for root, planted, pairs in (
            (VIATICUM, "package-small.json", False),
            (LYCEUM, "valid/lyceum-export-minimal.json", True),
        ):
            with self.subTest(root.name):
                examples = SCRATCH / root.name
                shutil.copytree(root / "examples", examples)
                path = examples / planted
                document = json.loads(path.read_text(encoding="utf-8"))
                document["format"] = "another-format"
                path.write_bytes(_canonical(document))
                validators = v.validators(root / "schemas")
                self.assertEqual(_quiet(v.check, validators, examples, pairs=pairs), 1)

    def test_an_invalid_example_failing_another_rule_makes_check_fail(self):
        examples = SCRATCH / "viaticum"
        shutil.copytree(VIATICUM / "examples", examples)
        wrong = examples / "invalid" / "package-1-envelope.json"
        wrong.rename(examples / "invalid" / "package-2-envelope.json")
        self.assertEqual(_quiet(v.check, v.validators(VIATICUM / "schemas"), examples), 1)


class ViaticumRulesTest(_Scratch):
    @classmethod
    def setUpClass(cls):
        cls.validators = v.validators(VIATICUM / "schemas")

    def _package(self):
        return json.loads((VIATICUM / "examples" / "package-small.json").read_text(encoding="utf-8"))

    def _judge(self, kind, document):
        path = SCRATCH / "doc.json"
        path.write_bytes(_canonical(document))
        return v.validate(kind, path, self.validators)

    def test_an_item_naming_no_archive_is_rule_4_and_a_repeated_item_rule_3(self):
        package = self._package()
        package["items"][0]["archive_vellum_id"] = "0c1e2f30-4a5b-4c6d-8e7f-999999999999"
        verdict = self._judge("package", package)
        self.assertEqual([(e["rule"], e["code"]) for e in verdict["errors"]], [(4, "unknownArchive")])
        package = self._package()
        package["items"].append(dict(package["items"][0]))
        self.assertIn(3, self._rules(self._judge("package", package)))

    def test_a_results_photo_not_named_by_its_id_is_an_error_without_a_rule(self):
        results = json.loads((VIATICUM / "examples" / "results-small.json").read_text(encoding="utf-8"))
        photos = [p for item in results["items"] for p in item.get("photos") or []]
        self.assertTrue(photos)
        photos[0]["file"] = photos[0]["file"].replace(".heic", ".jpg")
        verdict = self._judge("results", results)
        self.assertEqual([(e["rule"], e["code"]) for e in verdict["errors"]], [(None, "photoFile")])

    def test_schema_mode_exits_1_when_a_file_is_invalid(self):
        good = SCRATCH / "good.json"
        good.write_bytes(_canonical(self._package()))
        bad = SCRATCH / "bad.json"
        planted = self._package()
        del planted["trip"]
        bad.write_bytes(_canonical(planted))
        base = ["--schemas", str(VIATICUM / "schemas"), "--schema", "package"]
        self.assertEqual(_quiet(v.main, base + [str(good)]), 0)
        self.assertEqual(_quiet(v.main, base + [str(good), str(bad)]), 1)


class LyceumRulesTest(_Scratch):
    """LYCEUM's own checks, as its test_validate_examples.py states them."""

    @classmethod
    def setUpClass(cls):
        cls.validators = v.validators(LYCEUM / "schemas")

    def _export(self):
        return json.loads((VALID / "lyceum-export-minimal.json").read_text(encoding="utf-8"))

    def _manifest(self):
        return json.loads((VALID / "export-manifest-minimal.json").read_text(encoding="utf-8"))

    def _judge(self, kind, document, name="doc.json", validators=None):
        path = SCRATCH / name
        path.write_bytes(_canonical(document))
        return v.validate(kind, path, validators or self.validators)

    def test_a_planted_wrong_format_fails_rule_1_only(self):
        document = self._export()
        document["format"] = "lyceum-backup"
        verdict = self._judge("export", document)
        self.assertFalse(verdict["valid"])
        self.assertEqual(self._rules(verdict), {1})

    def test_schema_mode_exits_1_when_a_file_is_invalid(self):
        good = SCRATCH / "good.json"
        good.write_bytes(_canonical(self._export()))
        planted = self._export()
        planted["format"] = "lyceum-backup"
        bad = SCRATCH / "bad.json"
        bad.write_bytes(_canonical(planted))
        base = ["--schemas", str(LYCEUM / "schemas"), "--schema", "export"]
        self.assertEqual(_quiet(v.main, base + [str(good)]), 0)
        self.assertEqual(_quiet(v.main, base + [str(good), str(bad)]), 1)

    def test_the_valid_pair_is_canonical_json(self):
        for path in sorted(VALID.glob("*.json")):
            with self.subTest(path.name):
                data = path.read_bytes()
                self.assertEqual(data, _canonical(json.loads(data)))

    def test_every_rule_has_an_invalid_example_of_each_kind_it_applies_to(self):
        names = {p.name.split("-")[0] + "-" + p.name.split("-")[1] for p in INVALID.glob("*.json")}
        for rule, kinds in v.RULE_KINDS.items():
            for kind in kinds:
                with self.subTest(rule=rule, kind=kind):
                    self.assertIn(f"{rule}-{kind}", names)

    def test_unknown_keys_are_allowed(self):
        document = self._export()
        document["added_in_1_1"] = {"anything": [1, "two"]}
        document["producer"]["build"] = "x"
        self.assertTrue(self._judge("export", document)["valid"])
        manifest = self._manifest()
        manifest["added_in_1_1"] = True
        self.assertTrue(self._judge("manifest", manifest)["valid"])

    def test_a_later_minor_is_read_and_another_major_is_rule_2(self):
        document = self._export()
        document["format_version"] = "1.7"
        self.assertTrue(self._judge("export", document)["valid"])
        for version in ("2.0", "0.9", "1", "1.01", 1.0):
            with self.subTest(version=version):
                document["format_version"] = version
                self.assertEqual(self._rules(self._judge("export", document)), {2})

    def test_schema_version_must_be_a_positive_integer(self):
        for value in ("1", 1.5, 0, None):
            with self.subTest(value=value):
                manifest = self._manifest()
                manifest["schema_version"] = value
                self.assertEqual(self._rules(self._judge("manifest", manifest)), {3})

    def test_tables_are_an_object_of_arrays_of_scalar_rows(self):
        document = self._export()
        document["tables"] = {"added_in_1_1": [{"id": "a", "n": 1, "r": 0.5, "blob": "AAE=", "gone": None}]}
        self.assertTrue(self._judge("export", document)["valid"])
        for tables in ([], {"added": {}}, {"added": [[]]}, {"added": [{"x": True}]},
                       {"added": [{"x": {"nested": 1}}]}, {"Works": []}):
            with self.subTest(tables=tables):
                document["tables"] = tables
                self.assertEqual(self._rules(self._judge("export", document)), {5})

    def _table_schemas(self):
        """A scratch copy of schemas/ with one table, `notes`: `id` text key, `n` nullable integer."""
        schemas = SCRATCH / "schemas"
        shutil.copytree(LYCEUM / "schemas", schemas)
        tables = schemas / "tables"
        shutil.rmtree(tables, ignore_errors=True)
        tables.mkdir()
        (tables / "notes.schema.json").write_text(json.dumps({
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": "urn:lyceum:exchange:1.0:table:notes",
            "type": "object",
            "required": ["id", "n"],
            "properties": {"id": {"type": "string"}, "n": {"type": ["integer", "null"]}},
            "additionalProperties": {"type": ["integer", "number", "string", "null"]},
        }), encoding="utf-8")
        (schemas / "lyceum-tables.schema.json").write_text(json.dumps({
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": "urn:lyceum:exchange:1.0:lyceum-tables",
            "type": "object",
            "propertyNames": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
            "properties": {"notes": {"type": "array", "items": {"$ref": "urn:lyceum:exchange:1.0:table:notes"}}},
            "additionalProperties": {"type": "array", "items": {
                "type": "object", "additionalProperties": {"type": ["integer", "number", "string", "null"]}}},
        }), encoding="utf-8")
        return schemas

    def test_a_row_is_judged_by_its_table_schema(self):
        validators = v.validators(self._table_schemas())
        document = self._export()
        document["tables"] = {"notes": [{"id": "a", "n": None}, {"id": "b", "n": 2, "later": "x"}]}
        self.assertTrue(self._judge("export", document, "rows.json", validators)["valid"])
        for row, at in (({"id": 7, "n": 1}, "tables.notes[0].id"), ({"n": 1}, "tables.notes[0].id"),
                        ({"id": "a", "n": "1"}, "tables.notes[0].n")):
            with self.subTest(row=row):
                document["tables"] = {"notes": [row]}
                verdict = self._judge("export", document, "rows.json", validators)
                self.assertEqual([(e["path"], e["rule"]) for e in verdict["errors"]], [(at, 5)])

    def test_produced_at_is_utc_with_z(self):
        document = self._export()
        for good in ("2026-10-22T21:09:30Z", "2026-10-22T21:09:30.123Z", "2026-10-22T21:09:30.123456Z"):
            document["produced_at"] = good
            self.assertTrue(self._judge("export", document)["valid"], good)
        for bad in ("2026-10-22T21:09:30+02:00", "2026-10-22 21:09:30Z", "2026-13-01T00:00:00Z"):
            document["produced_at"] = bad
            self.assertEqual(self._rules(self._judge("export", document)), {5}, bad)

    def test_a_byte_order_mark_breaks_rule_1(self):
        path = SCRATCH / "bom.json"
        path.write_bytes(b"\xef\xbb\xbf" + _canonical(self._export()))
        verdict = v.validate("export", path, self.validators)
        self.assertEqual([(e["rule"], e["code"]) for e in verdict["errors"]], [(1, "byteOrderMark")])

    def test_a_media_path_that_does_not_name_its_hash_breaks_rule_4(self):
        sha = "ab" * 32
        other = "cd" * 32
        manifest = self._manifest()
        manifest["media"] = [{"path": f"media/ab/ab/{sha}", "sha256": sha, "size": 3}]
        self.assertTrue(self._judge("manifest", manifest)["valid"])
        manifest["media"] = [{"path": f"media/cd/cd/{other}", "sha256": sha, "size": 3}]
        verdict = self._judge("manifest", manifest)
        self.assertEqual([(e["rule"], e["code"]) for e in verdict["errors"]], [(4, "pathNotItsHash")])
        manifest["media"] = [{"path": f"media/cd/cd/{sha}", "sha256": sha, "size": 3}]
        self.assertEqual(self._rules(self._judge("manifest", manifest)), {4})

    def test_a_path_in_media_and_missing_media_twice_breaks_rule_5(self):
        sha = "ab" * 32
        manifest = self._manifest()
        manifest["media"] = [{"path": f"media/ab/ab/{sha}", "sha256": sha, "size": 3}]
        manifest["missing_media"] = [{"path": f"media/ab/ab/{sha}", "reason": "damaged"}]
        verdict = self._judge("manifest", manifest)
        self.assertEqual([(e["rule"], e["code"]) for e in verdict["errors"]], [(5, "duplicatePath")])

    def test_missing_media_may_be_absent_and_its_reason_is_closed(self):
        manifest = self._manifest()
        del manifest["missing_media"]
        self.assertTrue(self._judge("manifest", manifest)["valid"])
        manifest["missing_media"] = [{"path": "media/ab/ab/" + "ab" * 32, "reason": "lost"}]
        self.assertEqual(self._rules(self._judge("manifest", manifest)), {5})

    def test_pairs_fail_when_a_manifest_does_not_describe_its_export(self):
        examples = SCRATCH / "examples"
        shutil.copytree(LYCEUM / "examples", examples)
        manifest_path = examples / "valid" / "export-manifest-minimal.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["counts"] = {"works": 1}
        manifest_path.write_bytes(_canonical(manifest))
        self.assertEqual(_quiet(v.check, self.validators, examples, pairs=True), 1)
        self.assertEqual(_quiet(v.check, self.validators, examples, pairs=False), 0)
        manifest_path.unlink()
        self.assertEqual(_quiet(v.check, self.validators, examples, pairs=True), 1)

    def test_the_valid_manifest_describes_the_valid_export(self):
        data = (VALID / "lyceum-export-minimal.json").read_bytes()
        lyceum = self._manifest()["lyceum_json"]
        self.assertEqual(lyceum["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(lyceum["size"], len(data))

    def test_a_file_outside_valid_and_invalid_makes_check_fail(self):
        examples = SCRATCH / "examples"
        shutil.copytree(LYCEUM / "examples", examples)
        (examples / "stray.json").write_text("{}", encoding="utf-8")
        self.assertEqual(_quiet(v.check, self.validators, examples, pairs=True), 1)


if __name__ == "__main__":
    unittest.main()
