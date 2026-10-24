# APSIRA — the ecosystem

Status: **charter, 2026-10-21** (living document; append, never rewrite history)

Apsira Labs is Alejandro's own family of personal apps. One user, one operator, private
repositories, private releases. This repository is the ecosystem's home: the brand, the
briefs that open each app's planning thread, the shared Dart packages the apps build on,
and this charter. The apps themselves live in their own repositories.

This charter writes down what until now lived only inside RELAY's documents and
VIATICUM's "as RELAY" decisions. Where this file and an app's own documents disagree
about that app, **the app's documents win**; fix this file in the same commit.

---

## 1. What an Apsira app is

An Apsira app is a **standalone, single-user, offline, private** program that Alejandro
uses himself. The qualities below are the membership test. An app that breaks one of
them records the exception in its own decision log with the reason.

1. **Standalone.** It runs on its own, with no backend, no account and no shared
   infrastructure. It is **not a KEYSTONE project**: it runs no service on the KEYSTONE
   host, attaches to none of its shared services, and is not governed by KEYSTONE's
   architecture or standards (VIATICUM D-001). Its `.army.toml` says `keystone = false`.
2. **Offline and private by construction.** A phone app ships with **no `INTERNET`
   permission** (RELAY D-041); a PC app makes only explicit, user-triggered network
   actions. No telemetry, no cloud, no AI features inside the apps. Content is never
   logged.
3. **Apps meet through contracts, not shared databases.** Each app owns one domain.
   Where two apps exchange data, they do it through a **versioned, documented file
   format** carried by hand (VIATICUM `05-exchange-format.md`, RELAY D-131), or a
   read-only inter-app link with mutual verification (`relay/docs/kairos/05-link-contract.md`).
   No app syncs with another on its own (§4).
4. **Sync-ready, not syncing.** Every user-data row has a UUIDv7 `id`, `created_at`,
   `updated_at` and a soft-delete `deleted_at` (RELAY D-014, D-023). Every app has a
   full export of its data in an open, versioned format (RELAY D-131).
5. **Never loses data.** Single write path, one transaction per user action; schema
   changes ship with a migration, a schema dump and a migration test; nothing is
   hard-deleted without an explicit action.
6. **Apsira visual language, app sub-identity.** Tokens from the brand (§3), no colour
   literals outside the theme, dark by default, colour as an accent not a fill, a 1 px
   border on every card (RELAY D-022, D-064–D-066). Each app has its own mark drawn in
   the Apsira language, and shows the Apsira Labs lockup on first open or in About.
7. **Both languages where the app has user text:** English and Spanish, every key in
   both files in the same commit (RELAY D-030). PC apps may be English-only but
   translatable (QUIRE D24).

## 2. Classes of app

| Class | Form | Reference | Members |
|---|---|---|---|
| **folio** | Phone app (Android, Flutter) | RELAY | RELAY, VIATICUM, LYCEUM |
| **tome** | PC app (native desktop; Fedora and Windows) | QUIRE | QUIRE, PRISM (PC first) |
| **the central app** | The one Apsira-branded app that ties the roster together; the only place sync will live (§4) | — | not yet planned |

The briefs are filed by class: `folios/` and `tomes/`. A brief is the input to a planning
thread; it states what the app is for and which needs it answers, never its design.

Lyceum desktop and Vellum are server-side web apps on the KEYSTONE substrate. They are
not a class here: Lyceum desktop is being retired into LYCEUM (a folio), and Vellum's
relation to Apsira is ruled in its own planning thread.

## 3. The brand

`apsira-brand/` holds the symbol, lockups, app icons, favicons, fonts and the Python
sources that generate them. Its `README.md` is the brand standard. Rules every app
follows:

- Brand assets are **copied unchanged**. Never recoloured, outlined, rotated or
  stretched. Each app keeps its copies under `assets/brand/` with a provenance README
  (source path, commit, SHA-256), as RELAY does; QUIRE records them in `PROVENANCE.toml`.
- Colours: Ink `#101513`, Emerald `#00915A`, Ink on dark `#F1F4F2`, Emerald on dark
  `#1FB377`, Dark ground `#0E1311`. Emerald is never body text on white.
- Type: **Archivo Expanded** (600 and 400) for chrome, titles and numerals; normal-width
  Archivo for body text in the folios (RELAY D-055); JetBrains Mono for code and query
  text. QUIRE uses Archivo Expanded for all UI text (ADR-0015); that is its recorded
  exception.
- Per-app icons are drawn in the app's own repository (`tool/icon/`) from a mark the
  operator approves; only the concept comes from the Apsira symbol (RELAY D-077).
- In Flutter apps the tokens, type scale, fonts and lockup come from the `apsira_ui`
  package (§5), never from a copied theme file.

## 4. Sync and the central app

Individual apps keep the smallest possible attack surface: no network, no sync of their
own. The ecosystem's direction (operator, 2026-10-21) is **one central Apsira app** that
will own synchronisation for the whole roster through a single path, instead of each
app carrying its own. It is early-stage and may change. Until it exists, the apps'
obligations are the ones in §1.4: stable identifiers, timestamps, soft deletes, and a
versioned export/import bundle that the central app can consume later.

## 5. Shared code

`packages/` holds the Dart packages every Flutter app depends on (decisions D-APK-001,
D-APK-007, D-APK-011, for Tier 2 D-APK-012 to D-APK-017 and, for Tier 3, D-APK-018 to
D-APK-022 in `docs/decisions.md`):

| Package | Holds |
|---|---|
| `apsira_core` | `Result`/`Failure`, the log model, the `Clock` and `IdGen` ports (a monotonic UUIDv7), the FTS5 match builder, canonical JSON. Pure Dart; its one dependency is `crypto`, for the log's `stackHash` (D-APK-011). |
| `apsira_ui` | The Apsira tokens as a `ThemeExtension`, the `ThemeData` builder with its component and menu themes, type scale, shape, chrome icons, the fonts, the lockup, their licences and provenance; the component kit (layout, state views, overlays, the undo snack, pills, search, the drawer chrome) and the settings rows. |
| `apsira_tools` | The layering lint, the l10n check, the coverage gate and the privacy guards, configured per app by `tool/apsira_tools.yaml`; the release and build script skeletons. |
| `apsira_test` | The shared test support: font scaler, large-text layout checker, golden matrix, a11y pass, property testing. |
| `apsira_app` | The app scaffolding every folio repeats: error handlers, file log, start redirect, restartable root, zone channel, per-install flags, About. |
| `apsira_jobs` | The `BackgroundJobs` port and its WorkManager adapter, and the alarm-manager adapter of the alarm registry, for the apps that run background work (RELAY, VIATICUM; D-APK-011, D-APK-022). |
| `apsira_l10n` | The strings the shared widgets show, in English and Spanish, with their own delegate; `AppLanguage` and the language setting (D-APK-012). |
| `apsira_onboarding` | The first-open intro, the language step, tours, the Help shell and the one-time tips (D-APK-017). |
| `apsira_storage` | The backup target over the Storage Access Framework and the other storage ports with their Android adapters (D-APK-015). |
| `apsira_lock` | The app lock: the authenticator, the lock controller, the lock cover, hiding from recent apps and its settings section (D-APK-016). |
| `apsira_db` | The database plumbing: the opener with its pre-migration snapshot and safe mode, the database server, the restore swap, the snapshot, migrations and directory fsync, each app's file layout a parameter (D-APK-018). |
| `apsira_exchange` | LYCEUM's export envelope for every app's export (ruling C2), the released legacy shapes, the table dump and its loader (D-APK-019). |
| `apsira_zip` | RELAY's streaming ZIP: the writer, CRC-32 and the one-pass reader that refuses anything outside its profile; for RELAY and LYCEUM, whose backups and bundles are zips (D-APK-020). |
| `apsira_notify` | RELAY's notifications with app-defined channels, actions and a public version, the permission flow, and the per-install alarm registry (D-APK-021, D-APK-022). |

Every package carries one version and the set one shared tag, `apsira-vX.Y.Z`
(`apsira-v0.4.0`; D-APK-007): apps pin every package by git reference to that tag, never
by path in a committed `pubspec.yaml` (the path consumers are the packages' own `example/`
apps, inside the packages themselves). Packages may depend on each other at the same tag. A package is done
only when every app uses it (D-APK-009). What is app-specific stays in the app: its own
`ThemeExtension`s, the ports no package holds (the shared ones live in their package:
`Clock`/`IdGen` in `apsira_core`, `BackgroundJobs` in `apsira_jobs`, D-APK-011; `BackupTarget`,
`StorageSpace`, `DocumentPicker`, `Sharer` and `PhotoSource` in `apsira_storage`, D-APK-015;
`Authenticator`, `ScreenPrivacy` and `LockSettingsStore` in `apsira_lock`, D-APK-016), its
components beyond `apsira_ui`'s kit, `apsira_onboarding` and `apsira_lock`, its own text
beyond `apsira_l10n`'s keys, its icon art, its codegen. Packages never depend on `build_runner`.

## 6. How an app is built

Every app repository has the same skeleton, so a session moving between apps finds the
same things in the same places:

- `docs/00-brief.md` (this repository's brief, verbatim) → `01-vision-and-scope.md` →
  `02-decision-log.md` (append-only, `D-nnn`, with Status, Decision, Rationale,
  Alternatives, Consequences) → `03-roadmap.md` → data model → architecture → UX →
  phase plans → testing. `docs/README.md` indexes them.
- `docs/agent-rules.md` (the non-negotiables every army brief carries),
  `docs/dependencies.md` (one line per dependency: why, licence, maintained, network I/O),
  `docs/assurance-rules.md` where checks are proportionate (VIATICUM D-052),
  `docs/building.md`.
- `CLAUDE.md` with the non-negotiables, the task workflow, the architecture quick
  reference and the commands.
- `.army.toml` for `amartb/project-agents`: `keystone = false`, a lane named after the
  app, the ledger under `.army/sessions` (gitignored), gates that are static at merge.
- Flutter apps: `lib/{app,core,domain,data,features}` with the layering lint; Drift +
  Riverpod + go_router + freezed; EN and ES ARB files; `drift_schemas/` dumps;
  `test/critical/`; goldens EN/ES × dark/light × 100/200 % text.
- Identity: `com.apsiralabs.<app>` with a `.dev` flavour; sideloaded APKs from
  **private** GitHub Releases, built only on Alejandro's computer. A release key is the
  app's choice (RELAY has one, D-090; VIATICUM signs with the SDK debug key, D-059).
- Phases are planned in the app's planning thread and opened by a `docs/sessions/
  P<n>-KICKOFF.md` brief; one thread runs one phase.

## 7. How an existing app joins Apsira

The procedure that brought Lyceum Folio in (planning thread of 2026-10-21):

1. **Rule the posture first.** Decide, before any code moves, what happens to every
   feature that contradicts §1 (network, sync, shared infrastructure, telemetry). Record
   each as a decision with its reason; "kept as an exception" is a valid ruling, "left
   undecided" is not.
2. **Apply the retirement test** to the app and its siblings (KEYSTONE's product vision
   has the wording): what is used, what is intended, what another app already owns.
   Re-partition domains so that each app owns one.
3. **Decide identity.** A new `com.apsiralabs.<name>` and a fresh key are a new app on
   the phone; the name must not collide with a class word.
4. **Transform in place** unless the code is beyond saving: keep the repository and its
   history; phase the work as P0 (identity, deletion, skeleton, schema), then skin and
   architecture in parallel, then features, then portability, then release.
5. **Write the brief** into `folios/` or `tomes/` here, and copy it to the app's
   `docs/00-brief.md`. Seed the app's decision log with the rulings.
6. **Consume the packages** (§5) from the first commit that touches the theme or the
   core; never compile a copied theme first.

## 8. Roster

| App | Class | Repository | State (2026-10-21) |
|---|---|---|---|
| RELAY | folio | `amartb/relay` | v1.0.0 released; v1.1 UX refinements; KAIROS (v2) planned |
| VIATICUM | folio | `amartb/viaticum` | P5 in progress; exchange contract with Vellum built on Vellum's side |
| QUIRE | tome | `amartb/quire` | M6 merged (app shell and editor); Typst PDF pipeline live |
| PRISM | tome | — | brief only |
| LYCEUM | folio | `amartb/lyceum` | v1.0.0 released privately (2026-10-24); the creative hub, offline, RELAY v2's look |
| the central app | — | — | direction stated (§4); not planned |

## 9. Repository map

| Path | Contents |
|---|---|
| `apsira-brand/` | The brand standard and every asset |
| `folios/`, `tomes/` | Briefs, one per app |
| `packages/` | `apsira_core`, `apsira_ui`, `apsira_tools`, `apsira_test`, `apsira_app`, `apsira_jobs`, `apsira_l10n`, `apsira_onboarding`, `apsira_storage`, `apsira_lock` |
| `docs/decisions.md` | The ecosystem's decision log (`D-APK-nnn`) |
| `docs/agent-rules.md` | The non-negotiables every army brief for this repository carries |
| `docs/sessions/` | Session briefs, analyses, reports and handoffs |
| `docs/intake/` | Intake briefs that start another project's planning thread |
| `tool/check.sh` | The full check: every package's and example's analyze and tests, the shared-tag rules (one `version:`, the git form at `apsira-v<version>`, overrides), `sha256sum -c` of fonts and brand; verdict line `check: PASS` |
| `tool/release.sh` | The operator's tag act: checks, tags `apsira-v<version>`, pushes the tag, proves a consumer resolves it |
| `.army.toml` | The army's configuration for the `apsira` lane |
