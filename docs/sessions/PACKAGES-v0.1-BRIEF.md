# Unit brief — the Apsira shared packages, v0.1.0

**Written:** 2026-10-21 by the APSIRA MIGRATION planning thread. **Governs:** one orchestrated unit on lane
`apsira`, branch `phase/packages-v0.1`. **Decisions in force:** `docs/decisions.md` D-APK-001 (set and
boundaries), D-APK-002 (tools scope), D-APK-003 (pinning). **Rules:** `docs/agent-rules.md`.

## 1. The ask

Create `packages/apsira_core`, `packages/apsira_ui` and `packages/apsira_tools` by extracting RELAY's code at
commit **`5f606e9`** (`git -C ~/projects/relay show 5f606e9:<path>`; never the working tree, which another
session is editing), renaming `Relay*` → `Apsira*`, with each package's tests green, a `CHANGELOG.md` and a
`version: 0.1.0`; plus `tool/check.sh` (the full check with the verdict line `check: PASS`). The unit ends with
the three tags and the push as **operator acts** (give the exact `!` commands; do not tag or push).

The first consumer is LYCEUM (`lyceum-folio/docs/02-decision-log.md` D-012). RELAY and VIATICUM are **not**
edited; they adopt later by typedef shims.

## 2. What each package holds (D-APK-001; file @ 5f606e9)

### `apsira_core` — pure Dart, zero dependencies, `sdk: ^3.13.0`
| From RELAY | To |
|---|---|
| `lib/core/result.dart` | `lib/src/result.dart` |
| `lib/core/log.dart` (imports only result) | `lib/src/log.dart` |
| `lib/core/ports/clock.dart` (full surface; every method pure) | `lib/src/clock.dart` |
| `lib/core/ports/id_gen.dart` (`uuid()` only; `blockId*` stays in RELAY) | `lib/src/id_gen.dart` |
| `test/fakes/` FakeClock (and FakeIdGen if present) | `lib/testing/fake_clock.dart`, `lib/testing/fake_id_gen.dart` (a `testing` library, importable by consumers' tests) |
| `test/core/*` for result, log, clock | `test/` |
Public library: `lib/apsira_core.dart` exporting the four; `lib/testing.dart` exporting the fakes.

### `apsira_ui` — Flutter, `flutter: ">=3.47.0"`, depends on `flutter_lucide` (RELAY's pin) and `apsira_core`
| From RELAY | To |
|---|---|
| `lib/app/theme/relay_colors.dart` (the only colour literals) | `lib/src/colors.dart` (`ApsiraLightColors`, `ApsiraDarkColors`) |
| `lib/app/theme/relay_theme.dart` (`RelayTheme` ThemeExtension, `RelayFamily`, `RelayFamilyColors`, `RelayThemeData.build`) | `lib/src/theme.dart` (`ApsiraTheme`, `ApsiraFamily`, `ApsiraFamilyColors`, `ApsiraThemeData`); `build(tokens, {List<ThemeExtension> extensions = const []})` so an app adds its own extensions |
| `lib/app/theme/relay_typography.dart` | `lib/src/typography.dart`; every `TextStyle` gets `package: 'apsira_ui'`; `ApsiraFonts` exposes bare and qualified (`packages/apsira_ui/Archivo`) family names; `ThemeData.fontFamily` receives the qualified name |
| `lib/app/theme/relay_shape.dart` | `lib/src/shape.dart` |
| `lib/app/theme/app_icons.dart` — **chrome glyphs only** (`back`, `chevron`, `plus`, `verified`, `running`, `failed`, `folder`, `dragHandle`, `warning`); the stored-icon registry stays in RELAY | `lib/src/icons.dart` (`ApsiraIcons`) |
| `assets/fonts/*.ttf`, `SHA256SUMS`, `README.md` | `lib/fonts/` (assets must sit under `lib/` to be bundled from a package) |
| `assets/brand/apsira-labs-horizontal-reversed-1600w.png` | `lib/brand/` + `lib/brand/SHA256SUMS` |
| `assets/licenses/*` (Archivo OFL, JetBrains Mono OFL, lucide) | `lib/licenses/` |
| `test/app/theme/relay_theme_test.dart` (its token table read from `docs/06` — make it the test's own constant), `relay_typography_test.dart`, `relay_shape_test.dart`, `relay_fonts_test.dart`, `test/critical/tokens_contrast_test.dart` | `test/` |
New: `lib/src/brand.dart` with `ApsiraBrand.lockupReversed` (an `AssetImage` with `package: 'apsira_ui'`) and
`ApsiraBrand.registerLicences()` (adds the OFL texts to `LicenseRegistry`, RELAY's `registerIconLicences` pattern);
`test/brand_provenance_test.dart`: every file under `lib/fonts` and `lib/brand` matches `SHA256SUMS` **and** the
same-named file under `../../apsira-brand/` (`06-fonts/`, `02-lockups/horizontal/png/`); skips the second half
with a notice when that directory is absent. `pubspec.yaml` declares the `fonts:` (ArchivoExpanded 400/600;
Archivo variable at 400/500/600/700; JetBrainsMono variable) and `assets:` (licences, brand) exactly as RELAY's
`pubspec.yaml` does, paths relative to `lib/`. One golden `test/goldens/token_sheet` so a value change is visible.
Public library: `lib/apsira_ui.dart`.

### `apsira_tools` — pure Dart, `bin/`, depends on `yaml`, `args` (and `path` if RELAY's tools do)
| From RELAY | To |
|---|---|
| `tool/layering_lint.dart` | `lib/src/layering_lint.dart` + `bin/layering_lint.dart` |
| `tool/l10n_check.dart` | `lib/src/l10n_check.dart` + `bin/l10n_check.dart` |
| `tool/coverage_gate.dart` | `lib/src/coverage_gate.dart` + `bin/coverage_gate.dart` |
| `tool/privacy/deps_check.dart` | `lib/src/deps_check.dart` + `bin/deps_check.dart` |
| `tool/privacy/manifest_check.dart` | `lib/src/manifest_check.dart` + `bin/manifest_check.dart` |
| `test/critical/layering_test.dart` + `test/fixtures/layering/**` (and the l10n/coverage fixtures RELAY has) | `test/` |
| `analysis_options.yaml` | `lib/analysis_options.yaml` (for apps to `include:`) |
Every constant that was RELAY's becomes a key in a per-app **`tool/apsira_tools.yaml`** read by every `bin/`
(`--config <path>`, default `tool/apsira_tools.yaml`); an empty or absent file reproduces RELAY's values exactly:
```yaml
package: lyceum                 # default: the pubspec name
layering:
  root: lib
  domain_packages: [...]         # RELAY default: clock, collection, freezed_annotation, meta, path, rrule, time
  feature_packages: [...]        # RELAY default list
  shared_packages: [apsira_core, apsira_ui]   # NEW: apsira_core counts as pure (domain/core may import it); apsira_ui is a theme-layer import
  colour_literal_exempt: [app/theme/]
  disabled_rules: []
l10n: { config: lib/app/l10n/l10n.yaml, required_locales: [en, es], scan_exemptions: [app/l10n/generated/] }
coverage: { run: test/domain, min_lines: 90, min_branches: 85 }
privacy: { allowlist: tool/privacy/dependency_allowlist.yaml, declared_permissions: tool/privacy/declared_permissions.txt }
```
The lint's two behavioural additions (`shared_packages`) are the only changes from RELAY; record them under
D-APK-002 in the package's CHANGELOG. Read VIATICUM's copies of the same five tools **only to list their deltas**
in `docs/decisions.md` under D-APK-002 as "config knob in v0.2" or "VIATICUM-specific"; do not port them.

### Root
- `tool/check.sh`: for each package `flutter pub get --offline || flutter pub get`, `dart analyze --fatal-infos`
  (or `flutter analyze`), tests; `version:` of each pubspec equals the tag it would get (`apsira_<pkg>-v<version>`,
  checked against `git tag` only if such a tag exists); `sha256sum -c` of `lib/fonts/SHA256SUMS` and
  `lib/brand/SHA256SUMS`; prints `check: PASS` or `check: FAIL` as its last line.
- Each package: `pubspec.yaml` (`publish_to: none`, `version: 0.1.0`), `README.md`, `CHANGELOG.md` (section
  `## 0.1.0 — 2026-10-21`), `LICENSE` (all rights reserved, Alejandro; the brand and fonts keep their own licences).
- Header comment in every extracted file: `// From relay <path> @ 5f606e9`.

## 3. Tasks (a starting cut; the planner may re-cut, not widen)
| Id | Owns | Depends on |
|---|---|---|
| T1 `apsira_core` | `packages/apsira_core/**` | — |
| T2 `apsira_ui` | `packages/apsira_ui/**` | — (may depend on T1 for `apsira_core`; if so use a `pubspec_overrides.yaml` path override inside the lane, never committed) |
| T3 `apsira_tools` | `packages/apsira_tools/**`, the D-APK-002 delta list in `docs/decisions.md` | — |
| T4 root check and records | `tool/check.sh`, `packages/README.md` touch-ups, `docs/sessions/` report | T1, T2, T3 |
Wave 1 = T1, T2, T3 in three lanes. Checks: bundled (one checkpoint over T1–T3 if the assurance planner wants one,
focus: the provenance test, the lint fixtures, the `package:` font qualification actually loading in a widget
test), then the full final validation with `APSIRA_FULL_CHECK=1`.

## 4. Exit criteria
- `bash tool/check.sh` prints `check: PASS`.
- `sha256sum -c packages/apsira_ui/lib/fonts/SHA256SUMS` and `.../brand/SHA256SUMS` pass, and the same files are
  byte-identical to `apsira-brand/06-fonts/*` and `apsira-brand/02-lockups/horizontal/png/*-reversed-1600w.png`.
- A consumer smoke test exists inside `apsira_ui/test`: a `MaterialApp` built with
  `ApsiraThemeData.build(ApsiraTheme.dark)` renders a `Text` whose resolved `fontFamily` is
  `packages/apsira_ui/ArchivoExpanded`.
- `dart run apsira_tools:layering_lint --root test/fixtures/layering/clean` passes and `.../violations` fails
  naming each rule, from the package's own directory.
- Nothing changed in `relay/` or `viaticum/` (`git -C ~/projects/relay status --porcelain` unchanged from before).

## 5. Operator acts at the end (give exactly these)
```
! cd ~/projects/apsira && git tag apsira_core-v0.1.0 && git tag apsira_ui-v0.1.0 && git tag apsira_tools-v0.1.0 && git push origin phase/packages-v0.1 --tags
```
and the merge of `phase/packages-v0.1` into `main` (PR or fast-forward) when the operator chooses.
