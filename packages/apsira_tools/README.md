# apsira_tools

RELAY's quality tools for every Apsira Flutter app, pure Dart, run from the app's
root as `bin/` commands; and the build and release scripts RELAY, VIATICUM and LYCEUM
each carried, in one copy ("Scripts"). Decided in `../../docs/decisions.md` D-APK-001,
D-APK-002 and D-APK-011. Each file names its source: the tools RELAY's
(`// From relay <path> @ 5f606e9`), the scripts RELAY `09b28810`, VIATICUM `78d38e0`
and LYCEUM `9f4ff27`.

| Command | Checks | Exit 1 when |
|---|---|---|
| `dart run apsira_tools:layering_lint [--root <dir>] [--pubspec <file>]` | the import layers, pure domain/core, colour literals, dev-only packages | any of its 14 rules is broken; each finding names `file:line`, the import or call, and the rule |
| `dart run apsira_tools:l10n_check [--l10n-config <l10n.yaml>] [--arb-dir <dir>] [--source-dir <dir>]` | every ARB key in every required locale with matching placeholders; no string literal passed to the `l10n.text_calls` | a key, a locale or a placeholder is missing, or a literal is found; exit 2 with `l10n_check: no l10n config at <path>` when the gen-l10n file is absent |
| `dart run apsira_tools:coverage_gate [--run <test dir>] [--lcov <file>] [--root <dir>] [--min-lines <n>] [--min-branches <n>]` | domain line and branch coverage; every domain file in the report | below a threshold, a domain file missing, or (`--run`) the tests fail |
| `dart run apsira_tools:deps_check [--deps-json <file>] [--allowlist <file>] [--lib <dir>] [--pubspec <file>] [--dependencies-doc <file>]` | the runtime dependency closure against the allowlist; no network package; with a dependencies document, a row per direct dependency | a package is not allowlisted, is a network package, `lib/` imports a banned URI, or a direct dependency has no row |
| `dart run apsira_tools:manifest_check [--manifest] <file or dir> [--declared <file>] [--architecture <file>]` | the merged Android manifest against the declared permissions; no `INTERNET`; with an approved-permissions document, each permission approved or the app's own, each declared one with a reason | a permission is forbidden, undeclared, missing, unapproved or without a reason |

Every command also takes `--config <file>` (default `tool/apsira_tools.yaml`) and exits
2 on bad usage, including a config error.

## Configuration

`tool/apsira_tools.yaml` in the app replaces RELAY's constants. An absent or empty file
reproduces RELAY exactly, with `package` taken from the pubspec's `name:`. A flag on
the command line wins over the file. An unknown key, a wrong type, an unknown rule
or shared package, or unparsable YAML exits 2 naming the key and the file.

| Key | RELAY default | Read by |
|---|---|---|
| `package` | the pubspec name | `layering_lint`: `package:<package>/` maps to `layering.root` |
| `layering.root` | `lib` | `layering_lint` (`--root` wins) |
| `layering.domain_packages` | `clock, collection, freezed_annotation, meta, path, rrule, time` | packages `domain/` and `core/` may import |
| `layering.feature_packages` | RELAY's list (see `tool/apsira_tools.yaml`) | packages `features/` may import |
| `layering.shared_packages` | `apsira_core, apsira_ui` | `apsira_core` imports as `core/`, `apsira_ui` as `app/theme/` (D-APK-002); no other package may be named |
| `layering.colour_literal_exempt` | `app/theme/` | path prefixes where colour literals may live |
| `layering.disabled_rules` | none | rule ids whose findings are dropped |
| `l10n.config` | `lib/app/l10n/l10n.yaml` | the gen-l10n file (`--l10n-config` wins) |
| `l10n.required_locales` | `en, es` | locales every key must exist in |
| `l10n.scan_exemptions` | `app/l10n/generated/, features/theme_preview/` | source paths the `Text(` scan skips |
| `coverage.run` | none | the test directory `--run` defaults to |
| `coverage.min_lines`, `coverage.min_branches` | `90`, `85` | the domain thresholds |
| `privacy.allowlist` | `tool/privacy/dependency_allowlist.yaml` | `deps_check` (`--allowlist` wins) |
| `privacy.declared_permissions` | `tool/privacy/declared_permissions.txt` | `manifest_check` (`--declared` wins) |

The v0.2 keys make VIATICUM's tools configuration (D-APK-002's "config knob in
v0.2" items). Their defaults are RELAY's behaviour, so a v0.1 file still
reproduces RELAY.

| Key (v0.2) | RELAY default | Read by |
|---|---|---|
| `layering.forbidden_calls` | `system-time, random, uuid, clock-package` | the call groups `pure-calls` refuses in domain and core |
| `layering.extra_layers` | none | path prefixes that are a layer of a built-in kind (`root`, `router`, `shell`, `services`, `theme`, `l10n`, `core`, `domain`, `data`) |
| `layering.forbidden_packages` | none | path prefixes and the packages a file under one never imports; rule `layer-packages`, counted only when set |
| `layering.may_import` | none | a layer's row of the import matrix replaced by the layers it may import (rows `domain`, `core`, `data`, `services`, `theme`, `l10n`, `feature`) |
| `l10n.text_calls` | `Text` | the calls the scan refuses a literal in: `Text`, `SelectableText` (first argument), `TextSpan` (its `text:`) |
| `coverage.exempt_export_only` | `true` | `false` fails an export-only library (a barrel) that lcov lacks, instead of a notice |
| `privacy.dependencies_doc` | none | `deps_check`: the document needing a table row per direct and dev dependency but `flutter` (`--dependencies-doc` wins) |
| `privacy.manifest` | none | `manifest_check`: the manifest when the command line names none |
| `privacy.approved_permissions` | none | `manifest_check`: the document approving permissions (`--architecture` wins) |
| `privacy.approved_heading` | `### 11.1` | the section whose table rows (`` `NAME` ``) approve `android.permission.NAME` |

`test/fixtures/viaticum/apsira_tools.yaml` is VIATICUM's file.

`apsira_app` and `apsira_jobs` have no layer of their own: the lint treats them as
any third-party package. `domain/` and `core/` may import them only when
`layering.domain_packages` lists them, `features/` only when
`layering.feature_packages` does, and every other layer freely. An app whose `core/`
imports the `BackgroundJobs` port lists `apsira_jobs` there; the barrel also exports
the WorkManager adapter, so the lint then lets `core/` import the adapter too.

### Stays in VIATICUM

These deltas are VIATICUM's own logic (D-APK-002), not knobs:

- `layering_lint`: the dev-only `lab` layer `features/spike_lab/` and its rule
  `lab-imports`.
- `l10n_check`: `archivalTerms`, the Spanish archival ARB keys with fixed values.
- `deps_check`: the printed dependency paths to each network exception, and its
  summary line without the unused-allowlist part.
- `manifest_check`: the `<application>` backup attributes
  (`ViaticumBackupAgent`).

This package's own `tool/apsira_tools.yaml` is the worked example. It sets every key
to its default, and `package: relay` because the test fixtures are RELAY's tree.
`tool/privacy/` holds RELAY's allowlist and declared permissions, so the defaults
resolve here.

## Analysis options

`lib/analysis_options.yaml` is RELAY's: `flutter_lints`, the strict language modes and
RELAY's linter rules. An app includes it with
`include: package:apsira_tools/analysis_options.yaml`. The including app must have `flutter_lints` in its own `dev_dependencies`: the include resolves lint names, not packages.

## Scripts

`lib/scripts/` holds the apps' shell scripts once, driven by `APSIRA_*` settings
(D-APK-011). An app keeps its script paths as small wrappers: each sets the
settings and runs the package's file, which
`dart run apsira_tools:script_path <name>` prints (exit 2 for an unknown name). Each
script's `--help` lists every setting and its default.

| Script | Does | Exit |
|---|---|---|
| `session_guard.sh` | sourced; `refuse_in_session <script>` refuses on `CLAUDECODE`, any `CLAUDE_CODE_*`, `AI_AGENT`, `CODESPACES`, `CLOUD_SHELL`, `ARMY_TREE`, `ARMY_TASK` or `HOME=/home/user`, citing D-APK-011 and `APSIRA_GUARD_RECORD` | 3 in a session |
| `build_apk.sh [--dry-run] [debug\|profile]` | the dev APK, `./gradlew :app:process<Prod>ReleaseManifest`, `APSIRA_MANIFEST_CHECK`, each of `APSIRA_APK_CHECKS`, then `APK:` and `SHA-256:`. It builds no release and reads no key, so it runs in a session too | 1 no SDK or a step failed (`build_apk: FAIL (<step>)`), 2 usage or settings |
| `local_release.sh [--dry-run] v<x.y.z> [--build-number <n>] [--issues <file>]` | refuses in a session first, then the checkout, versionCode, notes, release check, prod build, manifest check, certificate (`APSIRA_SIGNING=release-key`) or the SDK debug key (`debug-key`), and `build/release/<tag>/<id>-<x.y.z>.apk` | 1 an input or step, 2 usage or settings, 3 session |
| `check.sh`, `codegen.sh` | every step of `APSIRA_CHECK_STEPS` / `APSIRA_CODEGEN_STEPS` (one `<name>: <command>` per line, the script's arguments as `"$@"`), each to the end, `ok <step>` / `FAIL <step>`, then the verdict `check:` / `codegen:` `PASS` or `FAIL (<steps>)` | 1 a step failed, 2 a bad list (`FAIL (settings)`) |

`--dry-run` prints the commands (`flutter build`, the checks, `apksigner`, `gh`) and
reads, builds and creates nothing; `<versionCode>`, `<ANDROID_HOME>` and `<newest>`
stand for what only a real run knows. The tests run every app's settings below in a
dry run and against stub tools, and assert the lines each app's own scripts run at
the commits D-APK-011 names.

One wrapper per app, its `tool/release/local_release.sh`:

```bash
#!/usr/bin/env bash
# RELAY: release key, verify_fingerprint.dart, commit-count versionCode (D-090).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export APSIRA_APP=Relay APSIRA_APP_ID=relay APSIRA_GUARD_RECORD=D-090 \
  APSIRA_KEY_PREFIX=RELAY \
  APSIRA_FINGERPRINT_CHECK='dart run tool/release/verify_fingerprint.dart' \
  APSIRA_MANIFEST_CHECK='dart run tool/privacy/manifest_check.dart --manifest' \
  APSIRA_VERSION_CODE=commit-count APSIRA_NOTES=issues
script="$(dart run apsira_tools:script_path local_release)"
exec bash "$script" "$@"
```

```bash
#!/usr/bin/env bash
# VIATICUM: the SDK debug key (D-059), tool/check.sh before the build.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export APSIRA_APP=Viaticum APSIRA_APP_ID=viaticum APSIRA_SIGNING=debug-key \
  APSIRA_GUARD_RECORD='docs/building.md §3' APSIRA_SIGNING_DOC='docs/building.md §3' \
  APSIRA_MANIFEST_CHECK='dart run tool/privacy/manifest_check.dart' \
  APSIRA_VERSION_CODE=version-dart APSIRA_RELEASE_CHECK='bash tool/check.sh' \
  APSIRA_NOTES=issues
script="$(dart run apsira_tools:script_path local_release)"
exec bash "$script" "$@"
```

```bash
#!/usr/bin/env bash
# LYCEUM: release key with its certificate SHA-256, CHANGELOG notes (D-004).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export APSIRA_APP=LYCEUM APSIRA_APP_ID=lyceum APSIRA_GUARD_RECORD=D-004 \
  APSIRA_KEY_PREFIX=LYCEUM \
  APSIRA_KEY_FINGERPRINT=5782212c870dd120e1b480f434a39c06ec9b69171f6dbe920ba29afe5540fc6a \
  APSIRA_VERSION_CODE=version-dart APSIRA_VERSION_DEFINE=LYCEUM_VERSION \
  APSIRA_NOTES=changelog
script="$(dart run apsira_tools:script_path local_release)"
exec bash "$script" "$@"
```

`tool/build_apk.sh` is the same wrapper from `..` with `build_apk`: RELAY sets its
`APSIRA_MANIFEST_CHECK`, VIATICUM its `APSIRA_MANIFEST_CHECK` and
`APSIRA_APK_CHECKS='dart run tool/privacy/apk_plugins_check.dart'`, LYCEUM nothing.
The wrapper's `dart run` reads only the package config; the guard still runs before
the release script reads its arguments, settings or any key.

## Tests

`dart test` from this directory. The fixtures under `test/fixtures/` are RELAY's, byte
for byte (each directory's `README.md` names the source), except `viaticum/`, which
proves each v0.2 key with one passing and one failing case. The layering suite pins
RELAY's 21 findings in the violations fixture. `test/scripts/` runs the scripts in a
scratch app root with stub `flutter`, `dart`, `gh`, `gradlew` and `apksigner`, in a
clean environment.
