# Changelog — apsira_tools

## 0.2.0 — 2026-10-24

### VIATICUM's deltas as configuration (D-APK-002)

Every "config knob in v0.2" item of D-APK-002 is a key of
`tool/apsira_tools.yaml`. Each default is RELAY's behaviour, so an absent, empty or
v0.1 file reproduces RELAY exactly; all 105 v0.1 tests pass unchanged.
`test/fixtures/viaticum/apsira_tools.yaml` is VIATICUM's file, and its fixtures
prove each key with one passing and one failing case.

- `layering.forbidden_calls`, default `[system-time, random, uuid, clock-package]`:
  the call groups `pure-calls` refuses. VIATICUM drops `clock-package`.
- `layering.extra_layers`, default `{}`: a path prefix that is a layer of a built-in
  kind. VIATICUM: `{app/tutorial/: router}`.
- `layering.forbidden_packages`, default `{}`: the packages a file under a prefix
  never imports, under the new rule `layer-packages`. The rule is counted only when
  the key is set and may be disabled. VIATICUM's `tutorial-packages` maps to it.
- `layering.may_import`, default `{}`: a layer's row of the import matrix replaced.
  VIATICUM: `{l10n: [core, theme, l10n]}`.
- `l10n.text_calls`, default `[Text]`: also `SelectableText` and `TextSpan` (its
  `text:`).
- `coverage.exempt_export_only`, default `true`: `false` fails a barrel lcov lacks.
- `privacy.dependencies_doc`, default unset: `deps_check` needs a table row per
  direct dependency; new flags `--pubspec` (default `pubspec.yaml`) and
  `--dependencies-doc`.
- `privacy.manifest`, default unset: the manifest `manifest_check` reads when none
  is given; the manifest may now also be positional.
- `privacy.approved_permissions`, default unset, and `privacy.approved_heading`,
  default `### 11.1`: every permission approved by that table or the app's own
  signature permission, each declared one with a reason; new flag `--architecture`.

### Changes

- `l10n_check` without its gen-l10n file exits 2 with
  `l10n_check: no l10n config at <path>`, not 255 with a stack trace (the v0.1
  deferral).

### Scripts (D-APK-011)

`lib/scripts/` holds the apps' shell scripts once, driven by `APSIRA_*` settings, and
`dart run apsira_tools:script_path <name>` prints a script's path for the app's
wrapper (README, "Scripts"). Sources: RELAY `09b28810`, VIATICUM `78d38e0`, LYCEUM
`9f4ff27`, each named in the script's header.

- **`session_guard.sh`** is LYCEUM's: `refuse_in_session` exits 3 on `CLAUDECODE`,
  any `CLAUDE_CODE_*`, `AI_AGENT`, `CODESPACES`, `CLOUD_SHELL`, `ARMY_TREE`,
  `ARMY_TASK` or `HOME=/home/user`, the union of VIATICUM's and LYCEUM's markers.
  RELAY's guard missed `ARMY_TREE` and `ARMY_TASK`. The refusal cites D-APK-011 and
  the app's `APSIRA_GUARD_RECORD` instead of LYCEUM's D-004.
- **`build_apk.sh`** is RELAY's, with VIATICUM's `APSIRA_APK_CHECKS` and its
  `build_apk: FAIL (<step>)` lines, and `--dry-run`. It keeps RELAY's exit codes
  (1 no SDK, 2 usage): VIATICUM's 2 for a missing SDK and 64 for usage move.
  It does not call the session guard: it builds no release and reads no key, and
  each app's conductor builds the dev APK in a session.
- **`local_release.sh`** reproduces each app's release through settings:
  `APSIRA_SIGNING=release-key` with `APSIRA_KEY_PREFIX` and either
  `APSIRA_KEY_FINGERPRINT` (LYCEUM's inline `apksigner` check) or
  `APSIRA_FINGERPRINT_CHECK` (RELAY's `verify_fingerprint.dart`), or
  `APSIRA_SIGNING=debug-key` (VIATICUM D-059); `APSIRA_VERSION_CODE=commit-count`
  (RELAY, `--build-number`) or `version-dart`; `APSIRA_NOTES=issues` (RELAY,
  VIATICUM) or `changelog` (LYCEUM, before the build); `APSIRA_RELEASE_CHECK`
  (VIATICUM's `tool/check.sh`); `APSIRA_VERSION_DEFINE` (LYCEUM's
  `--dart-define`). The guard runs first; `--dry-run` prints the build's commands.
  Changes from the apps' copies: the tag must be `v<x.y.z>` without leading zeros
  (LYCEUM's rule) in every app; `build/release/<tag>/` is emptied first in every app
  (RELAY kept old files); the publish lines always check that the repository is
  private first; VIATICUM's `backup fixture: not applicable` line is gone.
- **`check.sh`, `codegen.sh`** are skeletons: the step lists come from
  `APSIRA_CHECK_STEPS` / `APSIRA_CODEGEN_STEPS`, every step runs to the end, and the
  verdict is `check: PASS` or `check: FAIL (<steps>)`. `codegen --check`'s
  back-up-and-compare stays in each app's own step.

### Migration

None for RELAY or LYCEUM. VIATICUM copies `test/fixtures/viaticum/apsira_tools.yaml`
with its own paths and keeps the items the README lists under "Stays in
VIATICUM".

Replace `tool/build_apk.sh` and `tool/release/local_release.sh` with the README's
wrappers. The release wrapper refuses in a session (exit 3) before it runs `dart`:
RELAY's and VIATICUM's check the markers themselves, LYCEUM's sources the
`tool/release/session_guard.sh` it keeps for `operator_acts.sh`. A failing
`script_path` exits 1. `local_release.sh --help` names the app's signing values and
steps from its settings, as LYCEUM's own help did. A test that counted the stub calls
of a run now sees `dart run apsira_tools:script_path local_release` first (as for
`build_apk`), and a stub that fails every `dart` call fails that one. Tests that pinned VIATICUM's `build_apk.sh` exit codes 2 (no SDK) and 64
(usage) now expect 1 and 2.

## 0.1.0 — 2026-10-21

First release: RELAY's five tools at `5f606e9` (`v1.0.0`), each file headed with its
source, as `bin/` commands (`dart run apsira_tools:<tool>`) configured per app by
`tool/apsira_tools.yaml`. An absent or empty file reproduces RELAY exactly.

### Changes from RELAY (each recorded in `docs/decisions.md`)

- **`layering.shared_packages` (D-APK-002), two additions.** Defaults to
  `[apsira_core, apsira_ui]`. `package:apsira_core/` counts as `core/`, so domain
  and core may import it. `package:apsira_ui/` counts as `app/theme/`, so it is
  allowed wherever the theme is (features, theme, l10n, the app shell) and refused in
  domain, core, data and services. `shared_packages: []` restores RELAY's
  treatment of both as foreign packages.
- **`l10n_check --l10n-config` (P-5).** RELAY's `--config <l10n.yaml>` is renamed,
  because `--config` now names the tools file in every command. RELAY's own gate
  ran `l10n_check` with no flags, so it is unaffected.
- **`layering.disabled_rules` comes forward into v0.1.** D-APK-002 listed it among
  the v0.2 knobs; this release already carries it (D-APK-006).
- Every RELAY constant is a config key: `package` (default: the pubspec name),
  `layering.{root, domain_packages, feature_packages, colour_literal_exempt,
  disabled_rules}`, `l10n.{config, required_locales, scan_exemptions}`,
  `coverage.{run, min_lines, min_branches}`, `privacy.{allowlist,
  declared_permissions}`. Flags on the command line still win. An unknown key, a
  wrong type, an unknown rule or shared package, or unparsable YAML exits 2 naming
  the key and the file.
- Findings that told the reader which file to edit name the configured allowlist and
  declared-permissions files. The rule texts of `feature-packages` and
  `colour-literals` name their config keys instead of RELAY's file and theme class.

### Not carried from RELAY's suites (P-7)

The tests that read RELAY's own tree are not carried; the fixture tests are, unchanged.

- `layering`: group *the repository*.
- `l10n_complete`: group *the real ARB files* and *finds no string literal passed to
  Text( in lib/*.
- `privacy_guards`: groups *android backup* and *log*, plus the tests that read RELAY's
  manifests, `docs/05-architecture.md`, `dart pub deps`, resolved packages or `lib/`.
- The l10n command-line tests pass a gen-l10n file with `--l10n-config`; RELAY's
  `lib/app/l10n/l10n.yaml` is not in this package.

### Consumers

Add `apsira_tools` as a dev dependency (`packages/README.md`), copy
`tool/apsira_tools.yaml` and set `package` and the keys whose RELAY default does not
fit. `lib/analysis_options.yaml` is RELAY's analysis options, for
`include: package:apsira_tools/analysis_options.yaml`.
