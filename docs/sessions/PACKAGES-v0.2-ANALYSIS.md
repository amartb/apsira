<!-- army:doc type=generic -->
# Apsira packages v0.2 — the overlap analysis and the operator's rulings (2026-10-24)

**Asked by:** the operator, after RELAY v1/v2, VIATICUM v1 and LYCEUM v1: "UI/visual, notif, auth, etc are things
common to every app … add standardization where possible by creating Apsira packages". **Method:** two read-only
audits across the three apps (UI and flows; platform and infrastructure), spot-checked by the RELAY conductor.
**Heads read:** RELAY `09b28810` (v2.0.1), VIATICUM `bb61374` (v1.0.0), LYCEUM `9f4ff27` (v1.0.0), apsira `98125e9`.

Paths: R = `~/projects/relay`, V = `~/projects/viaticum`, L = `~/projects/lyceum`, under `lib/` unless they begin
with `test/`, `tool/` or `android/`. "Δn" = changed lines in `diff` (both sides); "a/b" = common/total lines after
normalising the app name, comments and whitespace.

## 1. Findings

1. **Only LYCEUM consumes `apsira_core`/`apsira_ui`/`apsira_tools` v0.1.** RELAY and VIATICUM still hold the copies
   D-APK-001 extracted; much of LYCEUM is code ported from RELAY ("ported from relay … @ a7d1c6d4" headers).
2. **All three depend on the same 16 libraries:** crypto, drift, sqlite3, flutter_localizations, intl,
   flutter_local_notifications, flutter_riverpod, riverpod_annotation, go_router, image_picker, path_provider,
   saf_stream, saf_util, share_plus, uuid. R+V add android_alarm_manager_plus, workmanager, freezed_annotation; R+L
   add local_auth, record, just_audio, timezone, flutter_lucide. **Pins differ:** L has flutter_local_notifications
   21 (others 22.3.2), share_plus 12 (13.3.1), record 6 (7.1.2), archive 4.0.9 (4.5.2); V has no flutter_lucide.
3. **The copies have drifted into defects** (verified by the conductor unless marked):
   - **L's `UuidIdGen` is a plain `_uuid.v7()`** (`data/platform/uuid_id_gen.dart`, 16 lines): no in-millisecond
     counter, Clock ignored. R and V keep RFC 9562 §6.2 monotonic order (58/50 lines, Δ16). D-APK-005's
     time-ordered ids depend on it.
   - **R's release guard is weaker:** `R tool/release/local_release.sh` checks CLAUDECODE, AI_AGENT, CODESPACES,
     CLOUD_SHELL, CLAUDE_CODE_*; V and L (`L tool/release/session_guard.sh`) also check ARMY_TREE, ARMY_TASK and
     HOME=/home/user.
   - **WorkManager policy fork:** R `data/platform/workmanager_background_jobs.dart:47` uses
     `ExistingPeriodicWorkPolicy.update`; V uses `keep`/`replace` with `initialDelay` and documents that `update`
     "would … pull that run earlier at every start". `JobConstraints` defaults: false in R, true in V.
   - **R's server-isolate fix `2520b90b`** ("an exclusively() block no longer stops the database server") is absent
     from V's `data/db/server.dart` — latent: V calls no `exclusively(` today.
   - **V's log model diverged** (Δ47 from apsira_core): a `stackHash` (sha256 of frames) and a UUID-only id regex;
     adopting apsira_core v0.1 would lose it.
   - **L notifications:** no lock-screen public version and no actions (Done/Snooze); one channel.
   - **Spanish drift:** "Follow system" = "Seguir el sistema" (R) / "Según el sistema" (V); Delete = Eliminar (R, L)
     / Borrar or Eliminar (V); Done = Listo (L) / Hecho (V). Only 2 ARB keys exist in all three apps; R∩V share 77,
     R∩L 32 (`common*`, `lockPrompt*`, `failure*`).
   - **Three export-envelope dialects** (D-APK-005 wants one): R camelCase `{appVersion, format, schemaVersion,
     version:1}`; L `{app_version, format_version:"1.0", produced_at, producer{app,app_version}, schema_version}`;
     V `{format:"viaticum.seed", format_version, artifact_id, produced_at, producer.app}`.
   - **L hygiene (reported, not verified):** a dead tracked `data/db/database.steps.dart` (2,565 lines) beside the
     generated `migrations/database.steps.dart`; two folders `migration/` and `migrations/`; untracked Lyceum Folio
     leftovers (`lib/data/database/database.g.dart` 64k lines, `lib/services/sync_service.g.dart`,
     `openapi_generator_config.json`) — LYCEUM's thread owns that repo.
4. **D-APK-006's "no package depends on another" blocks most of what is worth sharing** (a component kit needs tokens
   and strings; onboarding needs ui + l10n; db needs core). Its evidence was per-package tags with path deps failing
   to resolve; the operator's ruling A replaces it (§3).

## 2. Candidates, by tier (all three tiers are in scope)

### Tier 1 — near-identical copies; extraction stops the drift
| Package | Contents | Sources and evidence |
|---|---|---|
| `apsira_test` (dev) | Android 14 font scaler; large-text layout checker (`expectLayoutSound`); golden matrix EN/ES × dark/light × 100/200 % + bundled-font loader; a11y pass; token-contrast test (→ apsira_ui's own tests); `prop_core`; pump helpers | scaler R `test/support/android_font_scaler.dart` = V/L `test/support/layout/android_font_scale.dart` (identical); checker V/L `test/support/layout/layout_check.dart` 351/388; goldens R `relay_golden.dart`, V `viaticum_golden.dart`, L `lyceum_golden.dart`; contrast 133/197; `test/support/prop/prop_core.dart` identical R/V (433) |
| `apsira_core` v0.2 | monotonic UUIDv7 IdGen (pure Dart, no `uuid` dep needed); FTS5 match builder; canonical JSON; V's `stackHash` | R `data/platform/uuid_id_gen.dart`; R `data/db/query_sql/fts_match.dart` vs L `domain/search/fts_query.dart` (L drops punctuation-only words); L `domain/export/canonical_json.dart`; V `core/log.dart` |
| `apsira_tools` v0.2 | `session_guard.sh` (V/L markers), `build_apk.sh`, `local_release.sh` skeleton (app name and key env as config; V signs with the debug key, D-059), `codegen.sh`/`check.sh` skeletons; harden `l10n_check` without `l10n.yaml` (v0.1 deferral) | build_apk Δ30 (R~L), Δ93 (R~V); local_release Δ196–217; codegen Δ46/168 |
| `apsira_app` | `ErrorHandlers`; rotating `FileLogSink`; start-phase redirect helper (pending/first open/locked/safe mode); `RestartableRoot`; startup-failure app; SystemClock + ZoneChannel + `ZoneModule.kt`; `BackgroundJobs` + WorkManager adapter (V's keep/replace policy); `PendingPort` stubs; per-install flag files; About page + licences | ErrorHandlers R/V 43/43 identical, L 39/43; FileLogSink Δ22–41; zone adapter in all three (L "a hand port of half of RELAY's zone module"); BackgroundJobs port Δ84, adapter Δ68; About: L `features/settings/ui/about_page.dart` |

### Tier 2 — development speed; needs `apsira_l10n` first
| Package | Contents | Sources and evidence |
|---|---|---|
| `apsira_l10n` | ~40 common strings (OK, Cancel, Undo, Delete, Save, Done, Settings, About, language and theme names, tour buttons, lock prompts, `failureUnknown`) en/es with its own delegate; `AppLanguage` + locale setting; one Spanish wording | R `app/l10n/app_locale_provider.dart` ≈ V `app/l10n/app_language.dart`; L reduced; R 31 / L 36 `common*` keys |
| `apsira_ui` v0.2 | the component kit: `CardSlice`/`GroupHeader`/`GroupCard`, `SectionHeader`/`PageTitle`, `EmptyState`, `SettingsGroup`/rows, bordered sheet and dialog openers, confirm-destructive, `showUndoSnack`, pills + search pill, list row/icon box; component and menu themes (dropped by `ApsiraThemeData.build`, L copied them back); theme-mode setting (hand-written `Notifier`, no codegen); ThemePreview → `example/`; drawer chrome | R `features/notes_list/ui/list_widgets.dart` → L `app/theme/kit/**` (CardSlice 60/63, GroupHeader 18/18); EmptyState R `app/theme/empty_state.dart` / L `kit/state/empty_state.dart`; R has 20+ Undo-snack helpers and the sheet shape in 36 files; menu themes R `relay_theme.dart:296-360` ≈ L `lyceum_theme.dart:37-91` (39/40); ThemePreview R/V 232/386 |
| `apsira_onboarding` | `FirstOpenIntro` (mark, wordmark, lockup as parameters); progress-drawn mark painter; language card; step frame + flow state; `TourPlayer`/`TourStepData`; Help screen + how-to page shell + `/help/tour/:id` pattern; one-time tips, hint rotation, suggestion chips (RELAY's discoverability, D-218) | intro R/V/L `first_open_intro.dart` ≈150/179 ×3; language card ≈41/50 ×3; TourPlayer R `app/theme/tour/tour_player.dart` / V same 235/306; Help R/V 145/205; tips R `app/theme/discovery.dart`, `app/services/one_time_tips.dart` |
| `apsira_storage` (plugin) | SAF backup target + `StorageModule.kt` (free space) + fake; document picker; sharer; photo source | R `core/ports/backup_target.dart`, `data/platform/saf_backup_target.dart` ≈ L (port Δ21, adapter Δ16, Kotlin Δ36); V `folder_access` differs in shape; sharer Δ7/21; photo source Δ41/97 |
| `apsira_lock` | `Authenticator` + local_auth adapter; `ScreenPrivacy` (FLAG_SECURE) port + adapter; lock state machine (5 min default, 0 = at once, never a lock-out); lock cover; lock prompt strings | R `core/ports/authenticator.dart` ≈ L (Δ25/26, comments only); R `features/lock/**` (1,402) vs L `app/services/auth_service.dart` + `features/auth/ui/lock_screen.dart` (446); L has no ScreenPrivacy adapter; V has no lock (gains one) |

### Tier 3 — data-safety critical: a D-APK decision record and crash tests before code
| Package | Contents | Sources and evidence |
|---|---|---|
| `apsira_db` | opener (`openWithSnapshot`, `DatabaseOpening`/`Opened`/`SafeMode`, `openForBackground`, `DatabaseFiles`); server isolate **with R's fix 2520b90b**; restore marker + swap (`<db>.restoring`, `.tmp` + rename, safety copy, wal/shm); `VACUUM INTO` snapshot; `migrateWithForeignKeysOff`; `fsyncDirectory` (three copies, two signatures); migration-chain test harness; DbLog | R `data/db/{opener,server,restore_swap,backup_snapshot}.dart`, `migrations/migrate.dart` ≈ V (opener Δ642, server Δ50, swap Δ155, migrate Δ3); L opener is a plain `LazyDatabase` |
| `apsira_exchange` | one envelope (ruling C2: LYCEUM's shape) with reader, writer, canonical JSON, the generic `sqlite_master` JSON dump, the validator script; readers keep accepting each app's old shape | L `data/db/json_dump.dart`, `json_load.dart`, `domain/export/{envelope,canonical_json}.dart`; R `data/db/json_dump.dart`, `domain/export/json_export_format.dart`; V `domain/exchange/exchange_reader.dart`; validators V/L `tool/exchange/validate_examples.py` (Δ304) |
| `apsira_zip` | streaming ZIP writer + reader + CRC32 (pure `dart:io`); refusal-code hooks for each app's reader | R `data/files/backup_zip_{writer,reader}.dart`, `crc32.dart` ≈ L `bundle_zip_*` (writer Δ30, CRC Δ7, reader Δ226); L: "until apsira_core hosts it" |
| `apsira_notify` (plugin) | `Notifier` + adapter (ruling C4: RELAY's design: int ids, channels, ≤3 actions, `launchResponse`, public version) with V's per-install alarm registry; `AlarmScheduler` + alarm-manager adapter; reminder window planner; permission flow (asked-state per install, ruling C1); **RELAY's vendored, patched flutter_local_notifications moved from `relay/packages/` (D-217)** | R `core/ports/{notifier,alarm_scheduler}.dart`, `data/platform/{local_notifier,alarm_manager_scheduler}.dart`, `domain/reminders/window.dart`, `app/services/notification_permission_service.dart`; V same names (port Δ138/100, adapter Δ319/441, AlarmStore); L `data/platform/notification_service.dart` |

**Not packaged (ruling C3 and the audits):** media/photo stores (three layouts: R dated folders with staging and
quarantine, V `photos/<id>` + sha256, L content-addressed with orphan sweep — stay per app); the settings
key-value store (R/V Drift table, L secure storage + shared_preferences); date/number formatting (V is ISO everywhere,
its D-048); feature flags (none exist); domain content (tour catalogues, help texts, backup manifests, failure codes).

## 3. The operator's rulings (2026-10-24)

| # | Question | Ruling |
|---|---|---|
| A | Package dependencies | **One shared release tag** for all packages (e.g. `apsira-v0.2.0`); packages may depend on each other; apps pin one ref. Supersedes D-APK-006's "no package depends on another in v0.x" and D-APK-003's per-package tags. |
| B | Strings of shared widgets | **A shared `apsira_l10n`** (~40 common strings, en/es, own delegate); apps keep their own ARBs for app text. |
| Scope | Tiers | **All three tiers.** |
| D | Adoption | **Each package lands with all three apps:** a package is done only when RELAY, VIATICUM and LYCEUM all use it, through a patch release of each app; no fourth copy ever exists. Requires amending `docs/agent-rules.md` ("nothing is edited in relay/ or viaticum/"). |
| C1 | Flags on restore to a new phone | **Per install** (VIATICUM's way): first open done, permission asked, tours seen stay with the install; data travels, device state does not. |
| C2 | Export envelope | **LYCEUM's shape** is the standard; RELAY and VIATICUM write it; every reader keeps accepting its app's old shapes. |
| C3 | Media layout | **Keep per app:** no shared media store. |
| C4 | Notifications base | **RELAY's design + VIATICUM's per-install alarm registry** (a restored database never re-arms stale alarms); LYCEUM gains actions and the lock-screen public version. |

Standing rulings that bind every app release: signed releases only on the operator's computer (RELAY D-090; the key
never enters a session); RELAY patches ship signed, never as a dev APK (2026-10-23); the full device checklists run
before each signed release (2026-10-23); one green full suite before any tag (2026-10-23).
