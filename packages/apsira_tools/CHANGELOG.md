# Changelog — apsira_tools

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
