#!/usr/bin/env python3
# From viaticum tool/exchange/validate_examples.py @ 78d38e0 and
# lyceum tool/exchange/validate_examples.py @ 9f4ff27 (D-APK-019).
"""Validates exchange files against an app's JSON Schemas.

One validator for every app's `exchange/` folder: VIATICUM's rules and layout,
LYCEUM's rules, layout and export-manifest pairs. Needs Python 3 and
`jsonschema` >= 4 (Draft202012Validator). Reads local files only; run it with
`python3 -I`.

    validate_examples.py --schemas DIR --examples DIR --check [--pairs]
        Every valid example must pass its schema; every invalid example must
        fail, and only for the rule its name gives. With --pairs, each valid
        export must come with its manifest, which must describe it (size,
        sha256, counts, schema_version). Exit 0 when every file has its
        expected verdict, 1 otherwise.

    validate_examples.py --schemas DIR --schema KIND FILE...
        Each FILE against the schema of KIND. Exit 0 when every file is valid,
        1 when any is not.

Either way, one JSON verdict per file on standard output:
    {"file": ..., "schema": ..., "valid": bool,
     "errors": [{"path": "items[3].priority", "rule": 5, "code": "maximum",
                 "message": ...}]}
`path` names the field as the parsers do (empty for the whole file).

The profile follows the schemas in DIR:

  envelope (the shared envelope, C2; LYCEUM's): DIR holds `<app>-export` and
      `export-manifest` schemas, kinds `export` and `manifest`. Examples are
      `valid/<schema>-<x>.json` and `invalid/<rule>-<kind>-<what>.json`.
      Rules: 1 the file and its `format`, 2 `format_version`, 3
      `schema_version`, 4 the manifest's checksums, 5 every other field. A
      pair's manifest names its export as `<app>_json`.
  viaticum (VIATICUM 05 §4.5): DIR holds `seed`, `package` and `results`
      schemas. Examples are `<kind>-<x>.json` beside `invalid/
      <kind>-<rule>-<what>.json`. Rules number package errors only: 1 the
      envelope, 2 the trip, 3 a repeated item, 4 an unknown archive, 5 every
      other field.

Beyond the schemas, the rules JSON Schema cannot state: the file is UTF-8 JSON
without a byte-order mark; vellum_ids unique among a seed's or a package's
archives and a package's items, every item's archive_vellum_id naming an
archive of the package, a results photo's file named by its own viaticum_id
with an extension matching its media_type (VIATICUM); each media path names
its own sha256, no path twice in a manifest's media and missing_media
(LYCEUM).
"""

import argparse
import hashlib
import json
import pathlib
import sys

try:
    import jsonschema
except ImportError:  # pragma: no cover - the prerequisite's message
    sys.exit("validate_examples.py needs jsonschema >= 4 (python3 -m pip install jsonschema)")

VIATICUM_KINDS = ("seed", "package", "results")
VIATICUM_ENVELOPE = {"format", "format_version", "artifact_id", "produced_at", "producer"}
EXTENSIONS = {"image/jpeg": {"jpg", "jpeg"}, "image/heic": {"heic"}}

# The envelope profile's rules and the kinds each applies to.
RULE_KINDS = {
    1: ("export", "manifest"),
    2: ("export", "manifest"),
    3: ("export", "manifest"),
    4: ("manifest",),
    5: ("export", "manifest"),
}
_ROOT_RULES = {"format": 1, "format_version": 2, "schema_version": 3}


class Profile:
    """The kinds of one app's exchange folder, their schemas, its layout and rules."""

    def __init__(self, name, schemas):
        self.name = name
        self.schemas = schemas  # kind -> schema file stem

    @property
    def kinds(self):
        return tuple(self.schemas)

    @property
    def app(self):
        """The envelope profile's app: `lyceum` of `lyceum-export`."""
        return self.schemas["export"][: -len("-export")]


def profile_of(schemas):
    """The profile of the schemas directory `schemas`."""
    stems = sorted(p.name[: -len(".schema.json")] for p in schemas.glob("*.schema.json"))
    exports = [s for s in stems if s.endswith("-export") and s != "export-manifest"]
    if len(exports) == 1 and "export-manifest" in stems:
        return Profile("envelope", {"export": exports[0], "manifest": "export-manifest"})
    if set(VIATICUM_KINDS) <= set(stems):
        return Profile("viaticum", {k: k for k in VIATICUM_KINDS})
    raise SystemExit(f"{schemas}: neither <app>-export + export-manifest nor seed, package, results schemas")


def _path(parts):
    out = ""
    for part in parts:
        if isinstance(part, int):
            out += f"[{part}]"
        else:
            out += f".{part}" if out else str(part)
    return out


def _rule(profile, kind, path, code):
    """The rule an error at `path` with `code` breaks, in `profile`'s numbering."""
    if profile.name == "viaticum":
        if kind != "package":
            return None
        if code == "duplicateItemVellumId":
            return 3
        if code in ("unknownArchive", "duplicateArchiveVellumId"):
            return 4
        if path == "" or path.split(".")[0] in VIATICUM_ENVELOPE:
            return 1
        if path in ("trip", "trip.vellum_trip_id", "trip.version"):
            return 2
        return 5
    if path == "":
        return 1
    if code == "pathNotItsHash" or path.endswith(".sha256"):
        return 4
    return _ROOT_RULES.get(path.split(".")[0].split("[")[0], 5)


def _schema_errors(validator, document):
    errors = []
    for error in validator.iter_errors(document):
        parts = list(error.absolute_path)
        if error.validator == "required":
            missing = [f for f in error.validator_value if f not in error.instance]
            for field in missing:
                errors.append((_path(parts + [field]), "required", error.message))
        else:
            errors.append((_path(parts), error.validator, error.message))
    return errors


def _list(value):
    return value if isinstance(value, list) else []


def _entries(document, field):
    return [(i, e) for i, e in enumerate(_list(document.get(field))) if isinstance(e, dict)]


def _unique(entries, field, at, code):
    errors, seen = [], set()
    for i, entry in enumerate(_list(entries)):
        value = entry.get(field) if isinstance(entry, dict) else None
        if not isinstance(value, str):
            continue
        if value in seen:
            errors.append((f"{at}[{i}].{field}", code, f"{field} repeats in {at}"))
        seen.add(value)
    return errors


def _photo_errors(document):
    errors = []

    def check(photos, at):
        for i, photo in enumerate(_list(photos)):
            if not isinstance(photo, dict):
                continue
            file, pid, media = photo.get("file"), photo.get("viaticum_id"), photo.get("media_type")
            if not (isinstance(file, str) and isinstance(pid, str)):
                continue
            stem, _, ext = file.removeprefix("photos/").rpartition(".")
            if stem != pid or ext not in EXTENSIONS.get(media, {ext}):
                errors.append((f"{at}[{i}].file", "photoFile",
                               "file is not photos/<viaticum_id>.<ext of media_type>"))

    for i, item in enumerate(document.get("items") or []):
        if not isinstance(item, dict):
            continue
        check(item.get("photos"), f"items[{i}].photos")
        for j, sub in enumerate(item.get("sub_entries") or []):
            if isinstance(sub, dict):
                check(sub.get("photos"), f"items[{i}].sub_entries[{j}].photos")
    return errors


def _manifest_errors(document):
    errors, seen = [], set()
    for i, entry in _entries(document, "media"):
        path, sha = entry.get("path"), entry.get("sha256")
        if isinstance(path, str) and isinstance(sha, str) and len(sha) == 64:
            if path != f"media/{sha[:2]}/{sha[2:4]}/{sha}":
                errors.append((f"media[{i}].path", "pathNotItsHash",
                               "path is not media/<h[0:2]>/<h[2:4]>/<its sha256>"))
    for field in ("media", "missing_media"):
        for i, entry in _entries(document, field):
            path = entry.get("path")
            if not isinstance(path, str):
                continue
            if path in seen:
                errors.append((f"{field}[{i}].path", "duplicatePath",
                               "path already named in media or missing_media"))
            seen.add(path)
    return errors


def _rule_errors(kind, document):
    """The cross-field rules a JSON Schema cannot state, by kind."""
    if not isinstance(document, dict):
        return []
    if kind == "seed":
        return _unique(document.get("archives"), "vellum_id", "archives", "duplicateVellumId")
    if kind == "package":
        archives = document.get("archives")
        items = document.get("items")
        errors = _unique(archives, "vellum_id", "archives", "duplicateArchiveVellumId")
        errors += _unique(items, "vellum_id", "items", "duplicateItemVellumId")
        known = {a.get("vellum_id") for a in _list(archives) if isinstance(a, dict)}
        for i, item in enumerate(_list(items)):
            ref = item.get("archive_vellum_id") if isinstance(item, dict) else None
            if isinstance(ref, str) and ref not in known:
                errors.append((f"items[{i}].archive_vellum_id", "unknownArchive",
                               "archive_vellum_id names no archive of the package"))
        return errors
    if kind == "results":
        return _photo_errors(document)
    if kind == "manifest":
        return _manifest_errors(document)
    return []


def _load(path):
    """The file's JSON, strictly: UTF-8 without a byte-order mark."""
    data = pathlib.Path(path).read_bytes()
    if data.startswith(b"\xef\xbb\xbf"):
        raise ValueError("byteOrderMark")
    try:
        return json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("notJson") from error


def validate(kind, path, validators):
    """The verdict on the file at `path` as a `kind`; `validators` from validators()."""
    profile = validators["_profile"]
    try:
        document = _load(path)
    except ValueError as error:
        found = [("", str(error), "not UTF-8 JSON without a byte-order mark")]
    else:
        found = _schema_errors(validators[kind], document) + _rule_errors(kind, document)
    errors = [
        {"path": p, "rule": _rule(profile, kind, p, code), "code": code, "message": message}
        for p, code, message in found
    ]
    return {"file": str(path), "schema": kind, "valid": not errors, "errors": errors}


def _store(schemas):
    """Every schema under `schemas` (subfolders included), by its $id."""
    store = {}
    for path in sorted(schemas.rglob("*.schema.json")):
        schema = json.loads(path.read_text(encoding="utf-8"))
        jsonschema.Draft202012Validator.check_schema(schema)
        store[schema["$id"]] = schema
    return store


def _validator(schema, store):
    """A Draft 2020-12 validator of `schema` that resolves `$ref`s by $id in `store`."""
    try:  # jsonschema >= 4.18
        from referencing import Registry, Resource

        registry = Registry().with_resources(
            (uid, Resource.from_contents(s)) for uid, s in store.items())
        return jsonschema.Draft202012Validator(schema, registry=registry)
    except (ImportError, TypeError):
        resolver = jsonschema.RefResolver.from_schema(schema, store=store)
        return jsonschema.Draft202012Validator(schema, resolver=resolver)


def validators(schemas):
    """Kind -> validator for the schemas directory `schemas`, and its `_profile`."""
    schemas = pathlib.Path(schemas)
    profile = profile_of(schemas)
    store = _store(schemas)
    out = {"_profile": profile}
    for kind, stem in profile.schemas.items():
        schema = json.loads((schemas / f"{stem}.schema.json").read_text(encoding="utf-8"))
        out[kind] = _validator(schema, store)
    return out


def _relative(path):
    try:
        return path.resolve().relative_to(pathlib.Path.cwd().resolve())
    except ValueError:
        return path


def _say(message):
    print(message, file=sys.stderr)


def _valid_kind(profile, name):
    """The kind and stem of a valid example's name, or (None, None)."""
    for kind, prefix in profile.schemas.items():
        if name.startswith(prefix + "-"):
            return kind, name[len(prefix) + 1:]
    return None, None


def _invalid_kind(profile, name):
    """The kind and rule an invalid example's name gives, or (None, None)."""
    parts = name.split("-")
    if profile.name == "viaticum":
        if len(parts) < 3 or parts[0] not in profile.kinds or not parts[1].isdigit():
            return None, None
        return parts[0], int(parts[1])
    if len(parts) < 3 or not parts[0].isdigit():
        return None, None
    rule, kind = int(parts[0]), parts[1]
    if rule not in RULE_KINDS or kind not in RULE_KINDS[rule]:
        return None, None
    return kind, rule


def _pair_errors(profile, export_path, manifest_path):
    """What the manifest says about its export that is not so."""
    data = export_path.read_bytes()
    export = json.loads(data.decode("utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    named = manifest.get(f"{profile.app}_json") or {}
    tables = export.get("tables", {})
    found = []
    if named.get("size") != len(data):
        found.append(f"{profile.app}_json.size")
    if named.get("sha256") != hashlib.sha256(data).hexdigest():
        found.append(f"{profile.app}_json.sha256")
    if manifest.get("counts") != {t: len(rows) for t, rows in tables.items()}:
        found.append("counts")
    if manifest.get("schema_version") != export.get("schema_version"):
        found.append("schema_version")
    return found


def _check_valid(paths, validators, pairs):
    profile = validators["_profile"]
    failures, exports, manifests = 0, {}, {}
    for path in paths:
        kind, stem = _valid_kind(profile, path.name)
        if kind is None:
            _say(f"{path.name}: no schema for this name")
            failures += 1
            continue
        verdict = validate(kind, _relative(path), validators)
        print(json.dumps(verdict, ensure_ascii=False))
        if not verdict["valid"]:
            _say(f"{path.name}: expected valid")
            failures += 1
            continue
        if kind in ("export", "manifest"):
            (exports if kind == "export" else manifests)[stem] = path
    if not pairs:
        return failures
    for stem in sorted(set(exports) | set(manifests)):
        if stem not in exports or stem not in manifests:
            _say(f"{stem}: an export and its manifest come in pairs")
            failures += 1
            continue
        wrong = _pair_errors(profile, exports[stem], manifests[stem])
        if wrong:
            _say(f"{manifests[stem].name}: does not describe its export: {', '.join(wrong)}")
            failures += 1
    return failures


def _check_invalid(paths, validators):
    profile = validators["_profile"]
    failures = 0
    for path in paths:
        kind, rule = _invalid_kind(profile, path.name)
        if kind is None:
            _say(f"{path.name}: its name gives no kind and rule of this folder")
            failures += 1
            continue
        verdict = validate(kind, _relative(path), validators)
        print(json.dumps(verdict, ensure_ascii=False))
        rules = {e["rule"] for e in verdict["errors"]}
        if verdict["valid"] or rules != {rule}:
            _say(f"{path.name}: expected to fail rule {rule} only, got {sorted(rules, key=str)}")
            failures += 1
    return failures


def check(validators, examples, pairs=False):
    """Every example under `examples` has its expected verdict: 0, or 1."""
    examples = pathlib.Path(examples)
    profile = validators["_profile"]
    failures = 0
    if profile.name == "viaticum":
        valid = sorted(examples.glob("*.json"))
        stray = [p for p in examples.rglob("*") if p.is_file() and p.parent not in (examples, examples / "invalid")]
    else:
        valid = sorted((examples / "valid").glob("*.json"))
        stray = [p for p in examples.rglob("*") if p.is_file() and p.parent.name not in ("valid", "invalid")]
    for path in sorted(stray):
        _say(f"{path.relative_to(examples)}: not where this folder's examples go")
        failures += 1
    failures += _check_valid(valid, validators, pairs)
    failures += _check_invalid(sorted((examples / "invalid").glob("*.json")), validators)
    _say(f"validate_examples: {failures} unexpected verdict(s)")
    return 1 if failures else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--schemas", required=True, type=pathlib.Path, help="the app's exchange/schemas")
    parser.add_argument("--examples", type=pathlib.Path, help="the app's exchange/examples (--check)")
    parser.add_argument("--pairs", action="store_true", help="each export comes with the manifest describing it")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="every example has its expected verdict")
    mode.add_argument("--schema", metavar="KIND", help="validate FILEs against this kind's schema")
    parser.add_argument("files", nargs="*", metavar="FILE")
    args = parser.parse_args(argv)
    loaded = validators(args.schemas)
    if args.check:
        if args.examples is None:
            parser.error("--check needs --examples")
        return check(loaded, args.examples, pairs=args.pairs)
    if args.schema not in loaded["_profile"].kinds:
        parser.error(f"--schema: one of {', '.join(loaded['_profile'].kinds)}")
    invalid = 0
    for file in args.files:
        verdict = validate(args.schema, pathlib.Path(file), loaded)
        print(json.dumps(verdict, ensure_ascii=False))
        invalid += not verdict["valid"]
    return 1 if invalid else 0


if __name__ == "__main__":
    sys.exit(main())
