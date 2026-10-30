# APSIRA — Phase plans

Status: **seeded by the APSIRA PLANNING thread, 2026-10-30** (living document). Each unit's army planner turns its
rows into `01-plan.md` (owned files, acceptance criteria, waves); the conductor keeps this file as executed at each
milestone. Paths follow `05-architecture.md` (`lib/` the app, `android/` its Kotlin, `hub/` the hub program).

## 1. How v1 is orchestrated (D-026)

**Phases are milestones, not silos.** v1 is one task graph (§2). A phase is the set of tasks integrated for its
milestone and its signed release (D-025). Work is dispatched by readiness (dependencies integrated) and priority
(earlier milestone first), not by phase order.

- **Rolling planning.** Unit N+1 is planned while unit N executes, on the first lane that frees after N's plan is
  applied. Later-milestone tasks are pulled forward when a lane would otherwise idle; their milestone does not
  change.
- **Three kinds of work, three places** (`03` §Before M1):
  - **this lane** (`master-app/`): every `P<n>-<nn>` row below;
  - **the apsira lane** (`packages/`): the `K<n>-<nn>` rows, under the repository's `docs/agent-rules.md`, each
    group closed by one shared tag (T1–T3) that this lane then pins;
  - **adoption lanes** in each app's repository (`A-<app>-<n>`), opened by that app's own thread or conductor with
    a brief this lane writes; never edited from here.
- **Operator acts** (`O-<n>`) are listed in the graph where they block a task; the conductor asks for them when the
  task before them is integrated, never earlier, and records the pasted result (redacted) in the ledger.
- **Lanes:** `max_lanes` 4 across every live unit on the host, as the siblings; Flutter gates one at a time
  (`agent-rules.md` §This host).
- **Tasks:** IDs `P<n>-<nn>` (split parts `P<n>-<nn>a`), one squash commit `<type>(P<n>-<nn>): <summary>`.
  Branches `phase/p<n>-<slug>`, integration `session/p<n>-<slug>`.
- **Checks** (`assurance-rules.md`): merges on analyze and codegen; seven bundle validations designed from the work
  (§3); delta checks for fixes and closes; the full check once, at the v1 exit.
- **Releases and device sessions:** each milestone ends in a release candidate built and signed by APSIRA's release
  script in candidate mode, **outside any session** (D-035), one bundled device session on it with `apsira_link`'s
  example app as the consumer (`08` §6), then the signed release (D-025). The conductor builds only `dev` APKs. No
  phone in any release step; device findings become fix tasks. Milestones never wait for other apps' adoption lanes.
- **Docs** change in the task that changes behaviour; a contract (`docs/contracts/`) changes only in a task that
  names it, with its version bumped.

## 2. The v1 task graph

Areas: **A** app shell and tooling · **D** data and services · **H** hub (`hub/`) · **K** Kotlin and manifest ·
**M** pure domain · **U** features and UI · **P** package (apsira lane) · **O** operator act.

| Task | Area | What | Depends on | Earliest start |
|---|---|---|---|---|
| **P0 — Foundation** |||||
| P0-01 | A | App skeleton: `pubspec.yaml` at the current shared tag, `dev`/`prod` flavours, `com.apsiralabs.apsira` (D-002), bootstrap, theme, router, ARB EN/ES, About, first open (intro, language), the settings shell | — | P0 |
| P0-02 | A | `tool/`: codegen, `test_area.sh` (honouring `APSIRA_TEST_SCOPE`), `android_unit_tests.sh`, `hub_tests.sh`, `build_apk.sh`, `check.sh`; privacy guards with D-024's permission list | P0-01 | P0 |
| P0-03 | H | Hub skeleton: `hub/` Dart program, config file (paths, ports, hub address as configuration, D-004), content-free logging, the sandbox harness (scratch root, fake systemd, fake `restic`/`rest-server` binaries) | — | P0 |
| P0-04 | A | The Apsira symbol as the icon, copied unchanged with its provenance README and SHA-256 (D-002) | P0-01 | P0 |
| P0-05 | A | Release tooling on the ASTROLABE model (D-025): the release script refusing in a session, candidate mode, `CHANGELOG.md`; its test runs a stubbed copy | P0-01 | P0 |
| P0-06 | A | The lane's configuration (D-026): `.army.toml` placement settled, gates wired to `tool/` | P0-02 | P0 |
| K1-01 | P | `apsira_lock`: mandatory mode (no off switch, re-confirm API) (D-018) | — | P0 |
| K1-02 | P | `apsira_link`: the trust core — caller package and `hasSigningCertificate` check, the fingerprint table type, "unavailable" result (D-016) | — | P0 |
| K1-T | P | Shared tag **T1** | K1-01, K1-02 | P0 tail |
| O-1 | O | Hub acts H1: accounts and groups, `/var/lib/apsira-data` with the RC bind mounts, TLS certificate, repository and passwords, units, LAN-only firewall rule, DHCP reservation (`10` §2–§8) | P0-03 | P0 tail |
| O-2 | O | GitHub fine-grained read-only token into `/etc/apsira/github-token` (`10` §7) | O-1 | before P1-06 |
| O-3 | O | Proton VPN "allow LAN connections" on the phone and the tablet (D-005) | — | before M1's device session |
| O-4 | O | APSIRA's release key and recorded fingerprint (`release-signing.md`) | P0-05 | before `v0.1.0` |
| **M1 — Pairing + build shelf** |||||
| P1-01 | H | Mutual-TLS endpoint: the hub's own certificate, client-certificate verification, the device registry | P0-03 | P1 wave 1 |
| P1-02 | H | Pairing: one-time code, QR payload (code, hub fingerprint, LAN address), pair and revoke endpoints | P1-01 | P1 wave 2 |
| P1-03 | K | Device key in the Android Keystore, usable in the background without a fresh unlock (D-015 addendum); the Kotlin mutual-TLS `HubClient` pinned to the hub (D-027) | P0-01 | P1 wave 1 |
| P1-04 | D | Schema v1: hub, devices, shelf catalogue, installed versions, settings (`04`); migration chain; `drift_schemas/` | P0-01 | P1 wave 1 |
| P1-05 | D U | Pairing and revocation flow (scan with the camera, used on this screen only, D-029; confirm; revoke another device); "at home" = the hub answers (D-024) | P1-02, P1-03, P1-04, K1-T | P1 wave 3 |
| P1-11 | D H | The sync and vault keys (D-028): made on the first device, wrapped by a Keystore key, the recovery sheet shown once; the sealed hand-over to a new device through the hub (`/v1/keys/*`) or typed from the sheet; no copy on the hub | P1-05 | P1 wave 3 |
| P1-06 | H | Shelf fetcher: GitHub Releases with the token; RCs from the read-only bind mounts (`rc` in the version, `.sha256`, notes from `.notes.md` or none, D-035); SHA-256 and certificate check; changelog text | P1-01, O-2 | P1 wave 2 |
| P1-07 | D | The recorded-fingerprint table (each app's own release fingerprint, from its `release-signing.md`; VIATICUM absent until it has one, D-031; no debug certificate) as build configuration, with its pinning test | K1-T | P1 wave 1 |
| P1-08 | K | Installer: `PackageInstaller` session after a second certificate check on the device; `REQUEST_INSTALL_PACKAGES` | P1-07 | P1 wave 2 |
| P1-09 | U | Shelf screen (per app: installed, available, RC marked, changelog, one tap); the status screen with the shelf tile and the hub banner (D-019); the mandatory lock wired | P1-05, P1-06, P1-08 | P1 wave 3 |
| P1-10 | H | Install/upgrade script for the hub's units and files, run by the operator; tested against the fake systemd | P1-01 | P1 wave 2 |
| **M2 — Backup home + archive** |||||
| K2-01 | P | `apsira_storage`: the APSIRA adapter of `BackupTarget` (write, read, list through the link) | K1-T | P1 tail |
| K2-02 | P | `apsira_link`: backup-schedule calls (`backup_now` on the app's provider), `restore_offer` answered by the app's own restore (D-034); the archive calls | K1-T | P1 tail |
| K2-T | P | Shared tag **T2** | K2-01, K2-02 | P2 wave 1 |
| P2-01 | H | Store: `rest-server --append-only` under `apsira-store`, the repository's init, the prune timer with D-008's retention | P1-10 | P2 wave 1 |
| P2-02 | H | Backup intake (`POST /v1/backups/{package}`): a device's ciphertext stream into a snapshot tagged by app and device; snapshot listing per app; restore stream | P2-01, P1-01 | P2 wave 2 |
| P2-03 | K | The on-device link: one content provider called through `ContentResolver.call`, the per-call fingerprint check, backup hand-over in and restore out (`contracts/app-link.md`) | P1-07 | P2 wave 1 |
| P2-04 | D | Backup registry, the vault-key encryption of the queue (D-028), and the central schedule (nightly, at home, charging) through `apsira_jobs`; own-schedule hand-overs queued on the device until home | P2-03, P1-04, P1-11 | P2 wave 2 |
| P2-05 | D | Restore (D-034): `restore_offer` to the app; on its `restore_open(snapshot)`, the sealed snapshot fetched from the hub, opened with the vault key and streamed plain; the app restores through its own path | P2-02, P2-03 | P2 wave 3 |
| P2-06 | D U | New phone in one go: pair, receive the keys, reinstall every shelf app, offer each its latest snapshot, with progress and per-app failures | P2-05, P1-09 | P2 wave 3 |
| P2-07 | H | Archive: ciphertext items (D-028), put/get/list/release, `stored` → `secured` once inside a snapshot (D-010) | P2-01 | P2 wave 2 |
| P2-08 | K D | Archive calls on the link for ATRIUM (`contracts/atrium-offload.md`) | P2-03, P2-07 | P2 wave 3 |
| P2-09 | U | Backup-health tile, per-app backup screen (schedule mode, history, restore), the "not independent" flag (D-014) | P2-04, P2-05 | P2 wave 3 |
| A-*-1 | — | Adoption briefs for every covered folio (T2's adapter, schedule calls and `restore_offer`; VIATICUM once it has a release key) and the cross-app asks of D-036 (ATRIUM's offload, VIATICUM's release key), written into `docs/sessions/` for each app's thread | K2-T | P2 wave 2 |
| **M3 — Gateway** |||||
| K3-01 | P | `apsira_link`: gateway delivery calls (source, version, payload stream) | K1-T | P2 tail |
| P3-01 | H | Source framework: sources as hub configuration (`GET`/`PUT /v1/config`, revision and `409`) read back by every device, ids `kairos.holidays.<region>` · `currency.rates.ecb` · `gtfs.static.<feed>`, several per kind, `live`/`dark` state (D-033); per-source cadence on the hub's own schedule; fetch, validate against the source's contract, versioned cache, last error | P1-10 | P2 tail |
| P3-02 | H | Holiday packs (D-030): verify the open holiday dataset (candidate: OpenHolidays API), build packs in KAIROS's own format validated against its schema, yearly with the six-month re-check; the source stays dark until RELAY's thread accepts | P3-01 | P3 wave 1 |
| P3-03 | H | ECB euro reference rates, working days | P3-01 | P3 wave 1 |
| P3-04 | H | GTFS feeds from Spain's National Access Point, the ones he picks (nothing seeded), weekly and before validity ends | P3-01 | P3 wave 1 |
| P3-05 | D K | Collection at home into the device's cache; delivery over the link (`gateway_status`, `gateway_open`) to the app that asks, its parameter picking the instance | P2-03, K3-01 | P3 wave 2 |
| P3-06 | U | Gateway-freshness tile; the sources screen (cadence per source, feed picking) | P3-05 | P3 wave 2 |
| **M4 — Notification regime** |||||
| K4-01 | P | `apsira_notify`: the policy check before posting (`notify_policy`, the deadline of `contracts/app-link.md` §6.1, fallback), the silent companion channel for `quiet`, `digest_add`/`withdraw`, `breakthrough = urgent` per call, the digest tap through `launchResponse()` | K1-T | P3 wave 1 |
| K3-T | P | Shared tag **T3** | K3-01, K4-01 | P3 wave 2 |
| P4-01 | M | Regime domain: quiet hours and focus modes, kind priorities, digest times, breakthroughs; one pure decision function; settings kept per device until M5 (D-033) | P0-01 | P2 tail |
| P4-02 | K D | The policy answer on the link, within the budget; held items for digests | P2-03, P4-01 | P4 wave 1 |
| P4-03 | D | Digest posting at each digest time; entries open their app (D-012) | P4-02 | P4 wave 2 |
| P4-04 | U | Regime screens: modes and schedules, per-app kinds, digest times | P4-01 | P4 wave 1 |
| A-*-3 | — | Adoption briefs: T3 for RELAY (holidays once it accepts D-030; the "urgent" mark on reminders), ASTROLABE (rates), every `apsira_notify` consumer (the policy check) | K3-T | P4 wave 1 |
| **M5 — Sync core + the v1 exit** |||||
| P5-01 | M | Sync format and merge: change records, versions and their bases, the hybrid logical clock from `Clock`, per-field merge, R10–R14 (`contracts/sync-envelope.md`) | P0-01 | P3 tail |
| P5-02 | H | Mailbox: per-device drop and pick-up, ciphertext only, revoked devices refused | P1-01 | P4 wave 1 |
| P5-03 | D | Sync encryption: batches sealed with the sync key made in P1-11 (`contracts/sync-envelope.md`) | P1-11, P5-01 | P4 wave 2 |
| P5-04 | D | APSIRA's personal settings as the client (D-033): tables declared shared or device-only, change log in the same transaction; hub configuration never in the mailbox | P5-01, P1-04 | P5 wave 1 |
| P5-05 | U | Conflicts list, "2 versions" badge and "View edits" for settings | P5-04 | P5 wave 2 |
| O-5 | O | The recovery sheet (sync and vault keys) printed and kept (R26, D-028) | P1-11 | M1 device session |
| X-EXIT | A | v1 exit: the one full check, `v1.0.0-rc.1`, the device session, fixes, the signed `v1.0.0` | all | M5 tail |

**Operator acts as gates.** O-1 and O-2 block the hub's real install, not its tests: every `H` task is proved in the
sandbox (`08` §5), so the graph never waits on them until a device session.

## 3. Bundle validations (`assurance-rules.md` §2)

| Bundle | Tasks | Seam | Focus | Negative controls |
|---|---|---|---|---|
| **V-1 Trust** (M1) | P1-01, P1-02, P1-03, P1-05, P1-07, P1-11 | device ↔ hub, the fingerprint table, the keys | pairing once, revocation refused, pinning, unknown certificate refused; keys never on the hub | a reused pairing code; a revoked device; a hub certificate swapped; an app fingerprint off by one digit; a debug-signed caller |
| **V-2 Shelf** (M1) | P1-06, P1-08, P1-09, P1-10 | hub catalogue → device installer | checksum and certificate checked twice; no `.dev` or debug-signed build listed; RC marked | a tampered APK; an RC signed by the wrong key; a `.dev` APK in the builds folder |
| **V-3 Backup safety** (M2) | P2-01, P2-02, P2-03, P2-04, K2-01 | app adapter → link → hub → store | never lost; append-only for the hub account; the hub sees ciphertext only; one snapshot per hand-over; retention exact | the hub account forgetting a snapshot; a stream cut mid-way; a duplicate hand-over; plaintext reaching the hub |
| **V-4 Restore and archive** (M2) | P2-05, P2-06, P2-07, P2-08, P2-09 | store → device → app restore; ATRIUM ↔ archive | restore equals source; the new phone reinstalls and restores every app; offload and fetch-back identical | a snapshot of the wrong app handed over; a fetched document with a changed byte |
| **V-5 Gateway** (M3) | P3-01–P3-06, K3-01 | source → hub cache → device → app | cadence on a fake clock; invalid payloads never offered; home-only collection | a malformed pack; a fetch scheduled from the phone |
| **V-6 Regime** (M4) | P4-01–P4-04, K4-01 | `apsira_notify` ↔ the policy answer | quiet hours, breakthroughs, digests; the fallback with APSIRA missing or slow | an alarm held in quiet hours; a policy answer past its budget blocking a post |
| **V-7 Sync core** (M5) | P5-01–P5-05 | settings → change log → mailbox → other device | R10–R14 on settings; ciphertext only at the hub; revoked device refused | an edit discarded on a clash; plaintext in the mailbox |
| **v1 exit** | all | the app and hub never ran whole | `check` once, `coverage` | — |

P0's tasks, P1-04's schema and the package tags' own suites are in no bundle: their tests, the merge gates and the
apsira lane's `tool/check.sh` are what check them.
