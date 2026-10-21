# apsira_tools

RELAY's quality tools for every Apsira Flutter app. Pure Dart, run from the app's
root as `bin/` commands. Decided in `../../docs/decisions.md` D-APK-001 and D-APK-002.
Each file names its RELAY source (`// From relay <path> @ 5f606e9`).

| Command | Checks | Exit 1 when |
|---|---|---|
| `dart run apsira_tools:layering_lint [--root <dir>] [--pubspec <file>]` | the import layers, pure domain/core, colour literals, dev-only packages | any of its 14 rules is broken; each finding names `file:line`, the import or call, and the rule |
| `dart run apsira_tools:l10n_check [--l10n-config <l10n.yaml>] [--arb-dir <dir>] [--source-dir <dir>]` | every ARB key in every required locale with matching placeholders; no string literal passed to `Text(` | a key, a locale or a placeholder is missing, or a literal is found |
| `dart run apsira_tools:coverage_gate [--run <test dir>] [--lcov <file>] [--root <dir>] [--min-lines <n>] [--min-branches <n>]` | domain line and branch coverage; every domain file in the report | below a threshold, a domain file missing, or (`--run`) the tests fail |
| `dart run apsira_tools:deps_check [--deps-json <file>] [--allowlist <file>] [--lib <dir>]` | the runtime dependency closure against the allowlist; no network package | a package is not allowlisted, is a network package, or `lib/` imports a banned URI |
| `dart run apsira_tools:manifest_check --manifest <file or dir> [--declared <file>]` | the merged Android manifest against the declared permissions; no `INTERNET` | a permission is forbidden, undeclared or missing |

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
| `layering.shared_packages` | `apsira_core, apsira_ui` | `apsira_core` imports as `core/`, `apsira_ui` as `app/theme/` (D-APK-002) |
| `layering.colour_literal_exempt` | `app/theme/` | path prefixes where colour literals may live |
| `layering.disabled_rules` | none | rule ids whose findings are dropped |
| `l10n.config` | `lib/app/l10n/l10n.yaml` | the gen-l10n file (`--l10n-config` wins) |
| `l10n.required_locales` | `en, es` | locales every key must exist in |
| `l10n.scan_exemptions` | `app/l10n/generated/, features/theme_preview/` | source paths the `Text(` scan skips |
| `coverage.run` | none | the test directory `--run` defaults to |
| `coverage.min_lines`, `coverage.min_branches` | `90`, `85` | the domain thresholds |
| `privacy.allowlist` | `tool/privacy/dependency_allowlist.yaml` | `deps_check` (`--allowlist` wins) |
| `privacy.declared_permissions` | `tool/privacy/declared_permissions.txt` | `manifest_check` (`--declared` wins) |

This package's own `tool/apsira_tools.yaml` is the worked example. It sets every key
to its default, and `package: relay` because the test fixtures are RELAY's tree.
`tool/privacy/` holds RELAY's allowlist and declared permissions, so the defaults
resolve here.

## Analysis options

`lib/analysis_options.yaml` is RELAY's: `flutter_lints`, the strict language modes and
RELAY's linter rules. An app includes it with
`include: package:apsira_tools/analysis_options.yaml`.

## Tests

`dart test` from this directory. The fixtures under `test/fixtures/` are RELAY's, byte
for byte (each directory's `README.md` names the source). The layering suite pins
RELAY's 21 findings in the violations fixture.
