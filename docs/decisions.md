# APSIRA — ecosystem decision log

Status: **living document** (append-only; to change a decision, add a new entry that supersedes it)

Decisions that concern the ecosystem as a whole or its shared packages. App decisions
live in each app's own `docs/02-decision-log.md` and cite these by id (`D-APK-003`),
never copy them.

**Status values:** Decided (chosen by Alejandro), Proposed (recommended by Claude,
becomes Decided on review), Superseded.

---

## Summary

| ID | Decision | Status |
|---|---|---|
| D-APK-001 | Three shared Dart packages in `packages/`: `apsira_core`, `apsira_ui`, `apsira_tools`; extracted from RELAY v1.0.0 | Decided (amended by D-APK-006, D-APK-007, D-APK-011) |
| D-APK-002 | `apsira_tools` v0.1 is RELAY's tooling with per-app configuration; VIATICUM's deltas become config knobs in v0.2 | Decided (amended by D-APK-006) |
| D-APK-003 | Apps pin packages by git reference to a per-package tag; path overrides only for co-development, never committed | Decided (per-package tags superseded by D-APK-007) |
| D-APK-004 | Classes of app: folio (phone), tome (PC), the central app; the charter's membership test | Decided |
| D-APK-005 | Sync lives only in the future central app; individual apps stay network-free and master-app ready | Decided (direction; may change) |
| D-APK-006 | What the v0.1 extraction settled: no package depends on another in v0.x; RELAY's fonts layout; `l10n_check --l10n-config`; no `args`; `disabled_rules` in v0.1; barrel imports | Proposed (P-1 superseded by D-APK-007) |
| D-APK-007 | One version and one shared tag `apsira-v<version>` for every package; packages may depend on each other in the git form at that tag, with a committed `pubspec_overrides.yaml` | Decided |
| D-APK-008 | Shared strings live in an `apsira_l10n` package (en/es, its own delegate); apps keep their own ARBs; built in Phase 2 | Decided |
| D-APK-009 | A package is done only when RELAY, VIATICUM and LYCEUM use it through a patch release; adoption runs in adoption lanes under each app's own rules | Decided |
| D-APK-010 | Policy for what the packages carry: device state per install (C1), LYCEUM's export envelope (C2), media layout per app (C3), RELAY's notifications with VIATICUM's alarm registry (C4) | Decided |
| D-APK-011 | The Tier-1 set at `apsira-v0.2.0` and how each drift is resolved: monotonic UUIDv7, RELAY's FTS rule, `stackHash` with `crypto`, `apsira_jobs`, the session-guard union, the zone channel, one copy of the release scripts | Decided |

---

## D-APK-001 — Three shared Dart packages, extracted from RELAY v1.0.0

- **Status:** Decided (2026-10-21). **Amended by D-APK-006:** no inter-package dependency in v0.x; the shim line is the barrel form; `lib/fonts/` keeps RELAY's nine-file layout. **Amended by D-APK-007:** packages may depend on each other. **Amended by D-APK-011:** `apsira_core` is no longer zero-dependency (it depends on `crypto`), and the `BackgroundJobs` port lives in `apsira_jobs`.
- **Context:** RELAY and VIATICUM copy-ported the same theme, `Result` type, log model and
  tool scripts; the copies already differ by 90–210 lines per script. LYCEUM is the third
  Flutter app. The operator ruled that the shared packages are created now, in this
  repository, with LYCEUM as the first consumer.
- **Decision:** `packages/` holds three packages, extracted from RELAY at commit
  `5f606e9` (tag `v1.0.0`; `lib/app/theme`, `lib/core` and `tool/` are unchanged between
  that commit and RELAY `main` `c5b35a9`):
  - **`apsira_core`** (pure Dart, zero dependencies): `result.dart` (`Failure`, `Result`,
    `Ok`, `Err`), `log.dart` (`LogLevel`, `LogValue`, `LogRecord`, `LogSink`, `Log`,
    `redacted`), the ports `Clock` (RELAY's full surface, every method pure) and `IdGen`
    (`uuid()` only), and `testing/fake_clock.dart` for consumers' tests.
  - **`apsira_ui`** (Flutter): `ApsiraTheme` (RELAY's `RelayTheme`: the token
    `ThemeExtension` with `light`/`dark`, `of`, `lerp`, `copyWith`), `ApsiraFamily` and
    `ApsiraFamilyColors`, the light and dark colour sets (the only colour literals),
    `ApsiraThemeData.build`, typography (every `TextStyle` carries `package:
    'apsira_ui'`), radii/sizes/spacing/shapes, `ApsiraIcons` (chrome glyphs only; the
    package owns the `flutter_lucide` pin), the fonts (Archivo Expanded 400/600, Archivo
    variable, JetBrains Mono variable), the reversed Apsira Labs lockup, the OFL licence
    texts, `SHA256SUMS` for fonts and brand, `ApsiraBrand.lockupReversed`,
    `ApsiraBrand.registerLicences()`, and a provenance test.
  - **`apsira_tools`** (pure Dart, `bin/`): `layering_lint`, `l10n_check`,
    `coverage_gate`, `deps_check`, `manifest_check`, driven by a per-app
    `tool/apsira_tools.yaml`; RELAY's lint fixtures as its test suite; an
    `analysis_options.yaml` for apps to include.
- **What stays per app:** the app's `<App>Theme` file, which composes
  `ApsiraThemeData.build(ApsiraTheme.dark)` with the app's own `ThemeExtension`s
  (VIATICUM's `StateRole` and room set; LYCEUM's module accents); `theme_mode_provider`
  and anything else generated by `build_runner`; stored-icon registries; components; the
  other RELAY ports (`AlarmScheduler`, `VaultTarget`, …: their failure codes and channels
  are the app's); `codegen.sh`, `build_apk.sh`, `release/`, `icon/`.
- **Rules:** a package never depends on `build_runner`; a package requires the lowest
  Flutter any live consumer pins (`apsira_ui` needs ≥ 3.47); apps never construct
  `ApsiraTheme`, only `copyWith` from `light`/`dark`.
- **Alternatives rejected:** an `apsira_brand` asset package (5.9 MiB of PNG and PDF in
  every pub cache for one PNG; `apsira-brand/` stays plain files and `apsira_ui` carries
  only the two TTFs and the lockup, byte-identical by test); sharing all fifteen RELAY
  ports (would force a lowest common denominator nobody consumes); a melos workspace
  (three packages on one machine do not need it, and a shared lockfile would couple
  consumers that pin differently); keeping copy-porting (a third copy, more drift).
- **Consequences:** RELAY and VIATICUM adopt in their own later sessions through typedef
  shims (`typedef RelayTheme = ApsiraTheme;` plus re-exports; `core/result.dart` becomes
  `export 'package:apsira_core/result.dart';`). Nothing in this decision edits either
  repository. Token values, contrast, the type scale and font loading are the package's
  tests; screens' goldens stay in the apps, and a token bump that moves a golden is a
  per-app re-approval.

## D-APK-002 — `apsira_tools` v0.1 is RELAY's tooling with configuration; VIATICUM's deltas are v0.2

- **Status:** Decided (2026-10-21). **Amended by D-APK-006:** `disabled_rules` is already in v0.1; `--config` names the tools file and `l10n_check` takes `--l10n-config`.
- **Decision:** v0.1 ports RELAY's five tools unchanged in behaviour, replacing their
  constants (`_package`, the per-layer package allowlists, the colour-literal exemption
  directories, the locales, the coverage thresholds, the privacy file paths) with keys
  in `tool/apsira_tools.yaml`; an empty file reproduces RELAY exactly. Two additions:
  `package:apsira_core/` counts as pure (domain and core may import it) and
  `package:apsira_ui/` is a theme-layer import allowed wherever `app/theme/` is.
- **The honest gap:** VIATICUM's lint is a different program (no `colour-literals`
  rule, extra layers `app/tutorial/` and `features/spike_lab/`, different allowlists),
  and its `l10n_check`, `coverage_gate`, `deps_check` and `manifest_check` differ by
  200–370 lines. v0.1 does not cover VIATICUM. Each delta is read before extraction and
  listed in this log as either "config knob in v0.2" (`extra_layers`, `disabled_rules`)
  or "VIATICUM-specific, stays in VIATICUM".
- **Consequences:** VIATICUM keeps its copies until v0.2; LYCEUM uses v0.1 from its first
  theme commit.
- **Delta list (2026-10-21).** VIATICUM `20f05f6` against RELAY `5f606e9`, tool by tool.
  Each difference is either a "config knob in v0.2" (a value or toggle a key could
  carry; "v0.1 key" marks the ones `tool/apsira_tools.yaml` already carries) or
  "VIATICUM-specific" (logic that stays in VIATICUM).
  - `layering_lint`:
    - `domain_packages` is `{collection, crypto, meta}`. Config knob in v0.2 (v0.1 key).
    - `feature_packages` lacks `json_annotation`. Config knob in v0.2 (v0.1 key).
    - There is no `colour-literals` rule. Config knob in v0.2 (v0.1 key
      `disabled_rules`).
    - There are no clock-package time readers among the forbidden calls; VIATICUM's
      domain cannot import `clock`. Config knob in v0.2 (forbidden-call set).
    - `app/tutorial/` is an extra router-like layer that may import features. Config
      knob in v0.2 (`extra_layers`).
    - Rule `tutorial-packages`: `app/tutorial/` never imports `flutter_riverpod`,
      `riverpod` or `riverpod_annotation`. Config knob in v0.2 (per-layer forbidden
      packages).
    - `app/l10n/` may not read `domain/`. Config knob in v0.2 (per-layer import
      matrix).
    - `features/spike_lab/` is a dev-only `lab` layer: it may import any package or a
      dev-only one and may silence `depend_on_referenced_packages`, and no feature
      imports it (rule `lab-imports`). VIATICUM-specific.
  - `l10n_check`:
    - The gen-l10n file is `l10n.yaml` at the root. Config knob in v0.2 (v0.1 key
      `l10n.config`).
    - `scan_exemptions` adds `features/spike_lab/`. Config knob in v0.2 (v0.1 key).
    - The scan also flags literals passed to `SelectableText(` and to
      `TextSpan(text:`. Config knob in v0.2 (generic; a candidate default).
    - `archivalTerms`: nine Spanish archival ARB keys must hold fixed values.
      VIATICUM-specific.
  - `coverage_gate`:
    - There is no `--run` mode; it reads an existing `coverage/lcov.info`. Config knob
      in v0.2 (v0.1 key `coverage.run` unset).
    - There is no export-only (barrel) exemption, so a barrel missing from lcov fails.
      Config knob in v0.2 (toggle).
  - `deps_check`:
    - A new check: every direct and dev dependency needs a row in
      `docs/dependencies.md`, with new flags `--pubspec` and `--dependencies-doc`.
      Config knob in v0.2 (an optional dependency-table check).
    - On a clean run it prints the dependency paths that reach each network exception.
      The summary differs: no unused-allowlist line. VIATICUM-specific.
  - `manifest_check`:
    - The manifest may be a positional argument as well as `--manifest`. Config knob in
      v0.2 (CLI shape).
    - `--architecture` (default `docs/07-architecture.md`): every requested and
      declared permission must be in its §11.1 table, every declared one needs a
      reason, and the app's own signature permissions are allowed. Config knob in v0.2
      (approved-permissions source).
    - The `<application>` backup attributes must be set (`allowBackup="false"`, or
      the `ViaticumBackupAgent` with `fullBackupOnly` and its data-extraction
      rules). VIATICUM-specific.

## D-APK-003 — Pinning by git reference to a per-package tag

- **Status:** Decided (2026-10-21). **Superseded in part by D-APK-007:** the per-package tags give way to one shared tag `apsira-v<version>`; the git form, the lock and the gitignored co-development override in apps stand.
- **Decision:** The committed form in every app is a `git:` dependency on this
  repository with `ref:` a per-package tag and `path:` the package directory:

  ```yaml
  apsira_ui:
    git:
      url: git@github.com:amartb/apsira.git
      ref: apsira_ui-v0.1.0
      path: packages/apsira_ui
  ```

  `pubspec.lock` records the resolved commit, so any checkout of the app rebuilds
  against the same bytes; `flutter pub get --offline` works from the pub cache after
  the first fetch, so `gate_setup` is unchanged. For co-development an app may use a
  gitignored `pubspec_overrides.yaml` with `dependency_overrides: {apsira_ui: {path:
  ../apsira/packages/apsira_ui}}`; it is never committed.
- **Tags:** `apsira_core-vX.Y.Z`, `apsira_ui-vX.Y.Z`, `apsira_tools-vX.Y.Z`; `version:` in
  each `pubspec.yaml` equals its tag (checked by `tool/check.sh`). No repository-wide
  tag. Semver at 0.x: minor = breaking (a token value change is breaking: goldens move),
  patch = additive.
- **Propagation is pull, never push:** a change lands here with a `CHANGELOG.md` entry
  naming the migration; each app adopts in its own session by changing its `ref:` lines,
  running `flutter pub get`, regenerating goldens and adding a decision-log line. A tag
  must be pushed before a consumer can pin it, so an apsira cycle ends with tag and push.
- **Alternatives rejected:** a committed `path:` dependency (records only
  `../apsira/packages/…`, builds against whatever the sibling working tree holds that
  day, and breaks the army's worktree model: a lane mid-edit would silently change every
  app's gate results); a `file://` URL (ties the lock to one machine's layout).
- **Consequences:** each app's `docs/dependencies.md` carries one row per package, kind
  `git`, version `<tag> @ <sha>`; the privacy `dependency_allowlist.yaml` lists them with
  "no network I/O".

## D-APK-004 — Classes of app and the membership test

- **Status:** Decided (2026-10-21).
- **Decision:** The charter (`README.md` §1–§2) defines a **folio** as a phone app
  (Android, Flutter; reference RELAY), a **tome** as a PC app (native desktop; reference
  QUIRE), and **the central app** as the one Apsira-branded app that ties the roster
  together. The membership test is the charter's §1: standalone, offline and private,
  contracts not shared databases, sync-ready not syncing, never loses data, Apsira
  visual language, both languages. KEYSTONE membership and Apsira membership are
  mutually exclusive for folios and tomes (VIATICUM D-001 stands).
- **Rationale:** "folio" and "tome" were used in the briefs' filing but never defined;
  the definitions were inferred from the filing and confirmed by the operator. Lyceum
  Folio's name collided with the class word, hence LYCEUM.

## D-APK-005 — Sync lives only in the central app

- **Status:** Decided as direction (2026-10-21); early-stage, may change.
- **Decision:** No individual app carries a sync mechanism. A future central Apsira app
  owns synchronisation for the whole roster through one path. Until then every app is
  **master-app ready**: UUIDv7 ids, `created_at`/`updated_at`/`deleted_at` (RELAY D-023),
  and a versioned export/import bundle (RELAY D-131; VIATICUM's envelope conventions)
  that the central app can read.
- **Consequences:** LYCEUM removes the LAN sync it inherited from Lyceum Folio (its
  D-009); VIATICUM's earlier rejection of LAN sync (its decision log, "LAN sync, as LYCEUM
  and Folio") becomes the ecosystem rule.

## D-APK-006 — What the v0.1 extraction settled

- **Status:** Proposed (2026-10-21). **P-1 superseded by D-APK-007:** packages may depend on each other at the shared tag.
- **Context:** Extracting the three packages from RELAY `5f606e9` met points that
  D-APK-001, D-APK-002 and `packages/README.md` left open or got wrong. Each was settled
  in the session plan (P-1 to P-5, R-9) and is recorded here.
- **Decision:**
  - **No package depends on another in v0.x (P-1).** `apsira_ui` does not depend on
    `apsira_core`; nothing in RELAY's theme imports the core. Evidence (scratch pub
    test, 2026-10-21): an app pinning `a` at tag `t2` and `b`, which has
    `a: path: ../a`, at tag `t1` on the same commit fails: "Because every version of b
    from git depends on a from git … at 7e65cc… and app depends on a from git … at t2,
    b from git is forbidden." With an edge, the consuming snippet of
    `packages/README.md` (each package pinned by its own tag) would not resolve.
  - **`apsira_ui/lib/fonts/` keeps RELAY's `assets/fonts/` layout (P-2):** all nine
    files (the four TTFs, `LICENSE-Archivo.txt`, `OFL-Archivo.txt`,
    `OFL-JetBrainsMono.txt`, `SHA256SUMS`, `README.md`), so `sha256sum -c SHA256SUMS`
    checks RELAY's file unchanged and `LICENSE-Archivo.txt` sits beside the TTFs as in
    `apsira-brand/06-fonts/`. `lib/licenses/` holds only Lucide's `lucide.txt`.
  - **`l10n_check --l10n-config` (P-5).** RELAY's `--config <l10n.yaml>` is renamed,
    because `--config` names `tool/apsira_tools.yaml` in every tool. RELAY's gate ran
    `l10n_check` without flags, so adoption is unaffected.
  - **`args` is not a dependency of `apsira_tools` (P-3).** RELAY's tools parse their
    own flags; `--config` joins each hand-written parser. `yaml` is the only dependency.
  - **`layering.disabled_rules` comes forward into v0.1.** D-APK-002 listed it among the
    v0.2 knobs; v0.1 already carries it (rule ids whose findings are dropped; an unknown
    id exits 2), so VIATICUM's missing `colour-literals` rule is configurable today.
  - **Barrel imports (R-9).** Each package's `src/` is private; apps import
    `package:apsira_core/apsira_core.dart`, `package:apsira_core/testing.dart` and
    `package:apsira_ui/apsira_ui.dart`. D-APK-001's shim line
    `export 'package:apsira_core/result.dart';` names a library that does not exist;
    the shim is `export 'package:apsira_core/apsira_core.dart' show Failure, Result,
    Ok, Err;`.
- **Alternatives rejected:** `apsira_ui` depending on `apsira_core` by a committed
  `path: ../apsira_core` (an app pinning both by their own tags fails version solving,
  as above); the same edge by `git: ref: apsira_core-v0.1.0` plus an uncommitted
  override (resolution needs the network and a tag that exists only after the
  operator's push, so `tool/check.sh` could not run before the release); moving the OFL
  texts to `lib/licenses/` (breaks the verbatim `SHA256SUMS`) or copying them there
  (two copies to keep identical); a different tools-wide flag name (contradicts the
  per-app `--config` of D-APK-002); rewriting five parsers on `args` (behaviour risk,
  no gain).
- **Consequences:** an app pins each package it uses by that package's own tag. A
  future edge between packages needs a new decision that keeps that snippet resolving.
  RELAY's and VIATICUM's adoption sessions use the barrel shim above.

## D-APK-007 — One version, one shared tag; packages may depend on each other

- **Status:** Decided (2026-10-24, operator ruling A). Supersedes D-APK-003's per-package tags and D-APK-006 P-1.
- **Context:** D-APK-006 P-1 forbade any edge between packages, because a package pinned by its own tag could not
  depend on another pinned by a different tag. Most of what is worth sharing next needs an edge: a component kit
  needs the tokens and the strings, onboarding needs `apsira_ui` and `apsira_l10n`, a database package needs the
  core (`docs/sessions/PACKAGES-v0.2-ANALYSIS.md` §1.4). The operator ruled one shared release tag instead. The
  conductor proved the scheme on a scratch repository before it was written down (2026-10-24; two packages, `b`
  depends on `a`, tagged `apsira-v0.2.0`, an app pinning both at the tag):
  1. b declares `a: {path: ../a}` → FAILS: "Because every version of b from git depends on a from git ../repo at
     097022b… in packages/a and app depends on a from git ../repo at apsira-v0.2.0 in packages/a, b from git is
     forbidden." (a path dep inside a git dep resolves to the commit sha, not the ref name: same as D-APK-006 P-1.)
  2. b declares `a: {git: {url: <same url>, ref: apsira-v0.2.0, path: packages/a}}` and commits
     `packages/b/pubspec_overrides.yaml` = `dependency_overrides: {a: {path: ../a}}` → app `dart pub get` PASSES
     (a and b both "from git at 03b04a", lock ref apsira-v0.2.0, one resolved-ref); inside the repo
     `dart pub get --offline` in packages/b PASSES with "a 0.2.0 from path ../a (overridden in ./pubspec_overrides.yaml)".
     pubspec_overrides.yaml applies only to the root package, so consumers never see it.
- **Decision:**
  - Every package carries the same `version:`, and a release is one annotated tag `apsira-v<version>` on the
    commit that holds them all. Each `CHANGELOG.md` has a `## <version> — <date>` section, "no change" included.
  - A package may depend on another. The dependency is exactly
    `apsira_core: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v<version>, path: packages/apsira_core } }`,
    one line, in `dependencies` or `dev_dependencies`. A `path:` dependency is a defect.
  - A package with apsira dependencies commits `pubspec_overrides.yaml` holding `name: { path: ../name }` for the
    transitive closure of those dependencies, and nothing else. Inside this repository every package then resolves
    against its siblings' working tree, offline and before the tag exists. Apps still never commit an override
    (D-APK-003).
  - `tool/check.sh` enforces all of it: the versions are equal, each CHANGELOG has the section, a tag that exists
    carries that version in every package, every apsira dependency is the exact git form at the tag, and every
    override file is the closure (`bash tool/check.sh --release` runs only these steps).
    `tool/test/shared_tag_check_test.sh` proves six broken trees fail, one passes, and a dependency on the
    never-cut `apsira-v9.9.9` resolves with `dart pub get --offline` through its override.
  - `tool/release.sh` is the tag act, the operator's alone. It refuses in a session (exit 3), requires a clean
    `main` equal to `origin/main`, equal versions, an absent tag and its own `check: PASS`, then tags, pushes the
    tag and proves that a scratch consumer pinning every package at the tag resolves with `flutter pub get`.
- **Alternatives rejected:** per-package tags with path edges (fails version solving, result 1 above); per-package
  tags with git edges (an app pinning `apsira_ui-v0.3.0` would drag the `apsira_core` tag `apsira_ui` names, so
  two tags must move together anyway, with no check that they do); a pub workspace (one shared lock couples the
  packages' resolution, and a git consumer of a workspace member is unproven, D-APK-001); an uncommitted override
  in packages (every lane and `tool/check.sh` would need the network and a tag that does not exist yet).
- **Consequences:** an app pins every apsira package at one ref and moves them together. A package that has not
  changed still gets the new version and a "no change in behaviour" CHANGELOG section. The pre-0.2 tags
  (`apsira_core-v0.1.0`, `apsira_ui-v0.1.0`, `apsira_tools-v0.1.0`) stay as history.

## D-APK-008 — Shared strings in `apsira_l10n`

- **Status:** Decided (2026-10-24, operator ruling B). Built in Phase 2 (`apsira-v0.3.0`).
- **Context:** the shared widgets of Tier 2 need text (OK, Cancel, Undo, Delete, the language and theme names, the
  tour buttons, the lock prompts). Only two ARB keys exist in all three apps today, and the Spanish has drifted:
  "Seguir el sistema" against "Según el sistema", "Eliminar" against "Borrar", "Listo" against "Hecho" (analysis
  §1.3).
- **Decision:** an `apsira_l10n` package holds about forty common strings in English and Spanish with its own
  localizations delegate, `AppLanguage` and the locale setting, and one Spanish wording for each. Apps keep their
  own ARBs for their own text and add the package's delegate. Until it exists, a package widget takes its visible
  strings as constructor parameters; a package never hard-codes one.
- **Alternatives rejected:** strings as constructor parameters for good (every app re-translates the same forty
  words, and the drift stays); one merged ARB per app generated from the package (codegen in the apps' build for
  text they do not own).
- **Consequences:** Phase 2 builds `apsira_l10n` first; the component kit, onboarding and lock depend on it. Each
  app's adoption names the keys it drops and any Spanish wording that changes for its users.

## D-APK-009 — Adoption in all three apps, through adoption lanes

- **Status:** Decided (2026-10-24, operator ruling D). Amends `docs/agent-rules.md`.
- **Context:** v0.1 was consumed only by LYCEUM; RELAY and VIATICUM kept the copies D-APK-001 extracted, and the
  copies drifted into defects (analysis §1). The rule "nothing is edited in `relay/` or `viaticum/`" kept every
  adoption out of reach of the work that built the packages.
- **Decision:**
  - A package is done only when RELAY, VIATICUM and LYCEUM all use it through a patch release of each app, and no
    copy of its code is left in any of them. A package whose consumers are fewer by decision names them
    (`apsira_jobs`: RELAY and VIATICUM, D-APK-011).
  - Work in this repository never edits an app repository. Adoption runs in an **adoption lane**: a task in the
    app's own repository, on its own branch (`phase/apsira-v0-N-adoption` from its `origin/main`) and in its own
    ledger, under its `CLAUDE.md`, `docs/agent-rules.md` and decision log. Inside the app, the app's rules bind.
  - An adoption lane deletes the copies a package replaces (a one-line barrel shim only where more than twenty
    importers would churn, listed for removal in the next phase), keeps the app's behaviour except the ruled
    changes, records each ruled change and each moved pin in the app's decision log, and re-approves any golden
    that moves in the commit that moves it.
  - While a phase co-develops, the lane uses a gitignored override into this repository's integration worktree;
    after the operator's `tool/release.sh` it pins `ref: apsira-v<version>` and commits the lock.
- **Alternatives rejected:** adoption left to each app's own later sessions (the v0.1 outcome: two of three apps
  never adopted); editing the apps from this repository's lanes (bypasses the apps' rules, gates and owners).
- **Consequences:** each phase ends with one shared tag and one patch release of each app, signed on the
  operator's computer. An app thread that owns the app's open phase agrees when the adoption lands.

## D-APK-010 — Policy for device state, the envelope, media and notifications

- **Status:** Decided (2026-10-24, operator rulings C1–C4).
- **Decision:**
  - **C1 — device state is per install.** Three classes of flag stay with the install and never travel in a
    backup or an export: **first open done**, **permission asked** (each runtime permission's asked-state), and
    **tours and tips seen**. A restore onto a new phone brings the data and shows first open, the permission
    flow and the tours again. Packages keep these flags in per-install files, never in the app's database
    (VIATICUM's way). RELAY's restore changes accordingly, recorded in its decision log.
  - **C2 — one export envelope, LYCEUM's shape:** `format_version`, `produced_at`, `producer {app, app_version}`,
    `schema_version`. RELAY and VIATICUM write it; every reader keeps accepting its own app's older shapes, so no
    backup or export already made stops importing. Built in `apsira_exchange` (Phase 3).
  - **C3 — media layout stays per app.** RELAY's dated folders with staging and quarantine, VIATICUM's
    `photos/<id>` with sha256 and LYCEUM's content-addressed store with its orphan sweep are each the app's; no
    package holds a shared media store.
  - **C4 — notifications are RELAY's design** (int ids, channels, at most three actions, `launchResponse`, the
    lock-screen public version) **with VIATICUM's per-install alarm registry**, so a restored database never
    re-arms stale alarms. LYCEUM gains actions and the public version. Built in `apsira_notify` (Phase 3).
- **Alternatives rejected:** device flags inside the backup (a restored phone would skip the permission flow and
  never ask); a fourth envelope designed fresh (three readers would still need the old shapes); one media store
  (three layouts with different integrity guarantees, and no defect to fix); LYCEUM's single-channel notifier as
  the base (no actions, no public version).
- **Consequences:** C1 applies from Phase 1 (`apsira_app`'s install flags); C2 and C4 land in Phase 3, each with
  its D-APK record and crash-matrix tests before any code moves.

## D-APK-011 — The Tier-1 set at `apsira-v0.2.0` and the drift resolutions

- **Status:** Decided (2026-10-24: operator ruling R-1; conductor rulings R-2, R-3, R-8, R-10 and R-11). Amends D-APK-001 (`apsira_core`
  depends on `crypto`) and the charter `README.md` §5.
- **Context:** Phase 1 packages the near-identical copies (analysis §2 Tier 1) and has to choose one behaviour
  wherever the copies differ. The source of each extracted file is named in its header, `// From <app> <path> @
  <commit>` (RELAY `09b28810`, VIATICUM `78d38e0`, LYCEUM `9f4ff27`).
- **Decision:** the set is `apsira_core` 0.2, `apsira_ui` 0.2 (no change in behaviour), `apsira_tools` 0.2,
  `apsira_test`, `apsira_app` and `apsira_jobs`, all at `apsira-v0.2.0`. Each drift resolves as follows:
  - **IdGen** is RELAY's monotonic UUIDv7 (RFC 9562 §6.2 in-millisecond counter, the `Clock` honoured), in pure
    Dart without the `uuid` package. LYCEUM's plain `v7()` loses the order D-APK-005 relies on.
  - **`ftsMatch`** is RELAY's `fts_match.dart` unchanged: a word with no token stays a quoted phrase that matches
    nothing. LYCEUM's builder returns `null` for such input, which is observably neutral, because its single
    caller maps `null` to no results (critique probe, SQLite 3.45.1). No app's search results move.
  - **`stackHash`** (sha256 of the stack frames) comes from VIATICUM's log model, computed with `crypto` ^3.0.7, a
    dart-lang package every app already depends on. It is `apsira_core`'s first dependency (ruling R-1, N2-a).
  - **`LogValue.id`** accepts UUIDs only (VIATICUM's privacy rule), and **`LogValue.blockId`** carries RELAY's
    six-character block ids, redacting anything else.
  - **`apsira_jobs`** holds the `BackgroundJobs` port, `JobConstraints` and the WorkManager adapter, with
    VIATICUM's `keep`/`replace` policy and `initialDelay` (RELAY's `update` pulled the next run earlier at every
    start) and RELAY's constraint defaults. Its consumers are RELAY and VIATICUM only: LYCEUM's reminders run on exact
    notification alarms without WorkManager (LYCEUM D-034), and putting the adapter in `apsira_app` would put
    `workmanager` in its APK (ruling R-1, N1-a).
  - **The session guard** of the release scripts refuses on the union of VIATICUM's and LYCEUM's markers:
    `CLAUDECODE`, any `CLAUDE_CODE_*`, `AI_AGENT`, `CODESPACES`, `CLOUD_SHELL`, `ARMY_TREE`, `ARMY_TASK` and
    `HOME=/home/user`. RELAY's guard missed the army's two.
  - **The zone channel** (`ZoneModule.kt`, channel `apsira_app/zone`) is registered on the UI engine only, as
    RELAY does; background engines receive the zone as job input.
  - **`PendingPort`** is RELAY's base with VIATICUM's `Result` stubs (`pendingResult()`, `portPending`). Its
    `pending()` message is `portPending: <port>: the platform implementation lands with <task>`: RELAY's text after
    VIATICUM's prefix, which every app's tests accept.
  - **`ZoneChangeReceiver` and `enqueueResync`** belong in `apsira_jobs`, never `apsira_notify` (ruling R-3). They
    move in Phase 1 if `androidx.work` compiles from `apsira_jobs` with no artifact new to either APK (T6 branch 1);
    otherwise they stay a named exception in RELAY and VIATICUM until Phase 3, destined for `apsira_jobs`
    (branch 2). **Branch taken: 1** (T6, 2026-10-24). `workmanager_android` 0.10.9's `BackgroundWorker`, its
    `DART_TASK_KEY` and the top-level `PAYLOAD_PREFIX` are public. Its `androidx.work:work-runtime:2.11.2` is an
    `implementation` dependency, the artifact and version RELAY and VIATICUM already name. So `apsira_jobs`' Android
    build names that project and artifact, adding nothing to either APK, and holds `ZoneResync.kt` and the
    `<receiver>`. The debug builds of `apsira_jobs/example` and `apsira_app/example` compile the plugins'
    Kotlin. `tool/check.sh` does not build them, so the next change under `packages/*/android` builds them by
    hand as part of its proof.
  - **The release and build scripts** are one copy in `apsira_tools` (`lib/scripts/`), driven by `APSIRA_*`
    settings. Changes from the apps' copies: the tag is `v<x.y.z>` without leading zeros in every app (LYCEUM's
    rule); `build/release/<tag>/` is emptied before the build (RELAY kept old files); the publish lines first
    check that the repository is private; VIATICUM's `backup fixture: not applicable` line is gone;
    `build_apk.sh` keeps RELAY's exit codes, 1 for a missing SDK and 2 for usage (VIATICUM's were 2 and 64).
    Only `local_release.sh` calls the session guard. `build_apk.sh` stays unguarded, as in all three apps: it
    builds no release and reads no key, and each app's conductor builds the dev APK in a session (ruling R-11).
    This repository's `tool/release.sh` runs in the operator's own terminal: a `!` line in a Claude Code
    session inherits the session's markers, and the guard exits 3.
  - **`RELAY_PROP_*` and `VIATICUM_PROP_*`** are renamed `APSIRA_PROP_SCALE` and `APSIRA_PROP_SEED`
    (`apsira_test`'s `prop_core`); each app's long or nightly run sets the new names. A rename only.
  - **Other changes a consumer sees.** RELAY's log lines with a stack gain the `stackHash=<16 hex>` suffix
    (ruling R-8). VIATICUM's `SystemClock.nowUtc()` is truncated to whole milliseconds (RELAY's, the `Clock`
    contract). LYCEUM's `readZoneId()` returned `null` where `ZoneChannel.zoneId()` throws; its adoption
    catches. `apsira_test`'s layout check is LYCEUM's superset, with VIATICUM's `sideways` check behind
    `LayoutHost.forbidSideways`; VIATICUM loses only false failures (a `Badge` over its child, an
    `IndexedStack`'s hidden children, text a scroll view carries clear of a floating button, a clip measured
    against what its scroll view left visible). The golden matrix is LYCEUM's with RELAY's `goldenMatrix`.
  - **Kept for `apsira_ui` 0.3:** the light theme's `TextButton` text (`accentFill` on `ground`) measures
    4.39:1, under the 4.5:1 of Flutter's `textContrastGuideline`. `apsira_ui` 0.2.0 changes no behaviour, so
    the fix goes with the component and menu themes of Phase 2's `apsira_ui` 0.3 (ruling R-10).
- **Alternatives rejected:** the adapter inside `apsira_app` (reverses LYCEUM D-034) or one per app (the policy
  fork can recur); a hand-written SHA-256 (owns a crypto primitive) or the hash inside `FileLogSink` (changes
  VIATICUM's `LogRecord` and its tests); LYCEUM's token-less `null` (moves RELAY's results).
- **Consequences:** `apsira_core` is "pure Dart, depends only on `crypto`", and the app ports beyond `Clock` and
  `IdGen` that are shared live in their package (`BackgroundJobs` in `apsira_jobs`); the charter §5 says so.
  RELAY gains `keep`/`replace` and the `stackHash=` suffix; LYCEUM's ids become monotonic; VIATICUM keeps
  `stackHash`. Each is a line in the app's decision log at adoption.
