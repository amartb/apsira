# APSIRA — Roadmap

Status: **seeded by the APSIRA PLANNING thread, 2026-10-30** (living document)

v1 is one task graph cut into five milestones, one per slice of D-006, in that order. Each milestone ends in a
**signed private release** (D-025): `v0.1.0` … `v0.4.0`, and `v1.0.0` after the fifth, so the shelf is usable from
the first. A milestone is not a wall: the next unit is planned while the current one runs, and later tasks are pulled
forward when their dependencies are in (`07-phase-plans.md` §1). No dates: a milestone is done when its criteria
below are proved.

Work outside this app's code runs in three other kinds of unit, placed where the milestone that needs them can
consume them (`07` §2):

- **Package units** in the `apsira` lane (D-017, D-026): each lands as one shared tag `apsira-v<x.y.z>` before the
  milestone that pins it.
- **Hub acts**: the operator's privileged steps on amb811 from `10-hub-runbook.md`, typed by him (accounts, groups,
  units, firewall), and his outside acts (the GitHub token, the Proton VPN setting, the release key).
- **Adoption lanes** in each app's own repository, branch and ledger, under that app's rules (D-APK-009). APSIRA
  works without them and **its milestones do not wait for them**: each is proven with `apsira_link`'s example app as
  the consumer (D-035). An app gains a feature when it adopts.

## Before M1 — P0, foundation

| Unit | Delivers |
|---|---|
| **P0** (this repo) | The `master-app/` skeleton on the current shared tag: flavours `dev`/`prod`, `com.apsiralabs.apsira` (D-002), bootstrap, theme, router, ARB EN/ES, About, first open; `tool/` (codegen, check, test areas, APK build, privacy guards with D-024's permission list); the hub program's skeleton (`hub/`, `05`); the Apsira symbol copied unchanged with its provenance (D-002); the lane's configuration (D-026); release tooling on the ASTROLABE model (D-025) |
| **Tag T1** (apsira lane) | `apsira_lock`'s mandatory mode (D-018); `apsira_link`'s trust core: the caller check and the recorded-fingerprint table (D-016, D-017) |
| **Hub acts H1** (operator) | The `apsira` and `apsira-store` accounts, the `apsira-read` and `apsira-keys` groups, `/var/lib/apsira-data` on the system disk with the RC bind mounts, the TLS certificate, the repository and its passwords, the read-only GitHub token, the units and the LAN-only firewall rule (`10` §2–§8); a DHCP reservation for amb811; Proton VPN's "allow LAN connections" on the phone and the tablet (`10` §9, D-005) |
| **Operator** | APSIRA's release key and its recorded fingerprint (`release-signing.md`), before `v0.1.0` |

## Milestones

| Milestone | Slice (D-006) | Delivers | Needs |
|---|---|---|---|
| **M1** (`v0.1.0`) | Pairing + build shelf | The hub's mutual-TLS endpoint and device registry; pairing by QR at home with the camera used only there (D-029), and revocation (D-015); the sync and vault keys, the recovery sheet and the sealed hand-over to a second device (D-028); "home" by reaching the hub (D-024); the mandatory lock (D-018); the shelf: releases from GitHub, RCs signed by each app's release script from the builds folders, checksum and certificate checks, one-tap install with changelog, only apps with their own release key (D-007, D-031, D-035); the status screen with the shelf tile and the hub banner (D-019) | T1, H1 |
| **M2** (`v0.2.0`) | Backup home + archive | The append-only snapshot store and its pruning (D-008); backups and offloaded documents encrypted on the device (D-028); the on-device link's backup handover (D-016); central or own schedule per app; restore offered by APSIRA and performed by the app, and the new phone in one go (D-009, D-034); the archive with offload and fetch-back (D-010); the "not independent" flag until the SSD (D-014); the backup-health tile | T2 |
| **M3** (`v0.3.0`) | Gateway | Sources as hub configuration both devices share (`/v1/config`), ids `kairos.holidays.<region>`, `currency.rates.ecb`, `gtfs.static.<feed>` (D-033); the hub's own scheduler with a cadence per source; ECB rates, GTFS feeds he picks, holiday packs built from open data in KAIROS's format, dark until RELAY accepts (D-011, D-030); collection at home; delivery over the link; the gateway-freshness tile | T3 |
| **M4** (`v0.4.0`) | Notification regime | Quiet hours and focus modes, kind priorities, digests, breakthroughs (D-012), kept per device until M5 (D-033); the policy answer over the link; the digest notification; the regime screens | T3 |
| **M5** (`v1.0.0`) | Sync core + the v1 exit | The sync format, encryption and mailbox (D-013); APSIRA's personal settings as its only client (D-033), with the Conflicts list and "View edits" for them; the v1 exit: the one full check, the device session, the signed `v1.0.0` | — |

### Shared tags (apsira lane, D-017)

| Tag | Holds | Before |
|---|---|---|
| **T1** | `apsira_lock` mandatory mode; `apsira_link` trust core | M1 |
| **T2** | `apsira_link`'s APSIRA adapter of `apsira_storage`'s `BackupTarget` (write and read through the link); `apsira_link`'s backup-schedule calls (asked for a backup, report done); the archive calls ATRIUM uses | M2 |
| **T3** | `apsira_link`'s gateway delivery calls; `apsira_notify`'s policy check with its fallback when APSIRA is missing or slow, and the kinds an app declares | M3 |

Each tag's version is whatever the apsira lane releases next; a tag may carry other package work. *Proposed:* T2 and
T3 are cut as soon as their parts are green, so adoption lanes can start while APSIRA's milestone still runs.

### Adoption (each app's own lane, D-APK-009)

| App | Adopts | From tag | Gains |
|---|---|---|---|
| RELAY, LYCEUM, ATRIUM, ASTROLABE (STYLUS when it exists; VIATICUM once it has its own release key, D-031) | the `BackupTarget` adapter, the schedule calls and `restore_offer` (D-034) | T2 | backups home, restore from APSIRA, central schedule |
| ATRIUM | the archive calls (`contracts/atrium-offload.md`), its offload UI in its own thread (D-010) | T2 | offload and fetch-back |
| RELAY (KAIROS) | gateway delivery of holiday packs, once it accepts D-030's source; the "urgent" mark on reminders (D-012) | T3 | fresh holidays beside the bundled baseline (RELAY K-046); urgent reminders through quiet hours |
| ASTROLABE | gateway delivery of rates; currency as a quantity (ASTROLABE D-017) | T3 | currency conversion |
| every `apsira_notify` consumer | the policy check, its notification kinds declared | T3 | quiet hours, priorities, digests |
| TRANSIT (future) | GTFS delivery | T3 | its timetables; the feeds are fetched from M3 on |

### Cross-app asks (D-036; each ruled in that app's own thread)

| App | Ask | Blocks |
|---|---|---|
| ATRIUM | Take up `contracts/atrium-offload.md`; rule whether standing and vault-guarded items may be offloaded | ecosystem criterion 5 (`01` §4.2) |
| RELAY | Accept D-030's open holiday data in place of K-094's hand curation; add the "urgent" mark to reminders | the holiday source going live; urgent reminders |
| VIATICUM | A release key of its own (D-031) | VIATICUM on the shelf and the link |
| Every folio | Adopt the shared tags in an adoption lane (D-017) | the ecosystem criteria |

## Milestone criteria (on the host; the phone only in each release's device session)

Each milestone ends in an RC signed by APSIRA's release script, one bundled device session on it with
`apsira_link`'s example app as the consumer, then the signed release (D-025 addendum, D-035).

### M1
- Pairing: a device with the one-time code pairs once; the code is refused a second time; a revoked device's
  handshake is refused by the hub; a device that does not pin the hub's certificate cannot connect (`pairing_test`,
  `revocation_test`, against a sandboxed hub).
- Shelf: an APK whose SHA-256 or signing certificate does not match is shown as refused and never handed to the
  installer; a `.dev` build or a debug-signed APK is never listed; an RC is listed and marked, its notes from its
  `.notes.md` or "No notes" (`shelf_integrity_test`).
- Keys: the recovery sheet is shown once; a second device receives the sealed keys or takes them typed; the hub holds
  no copy (`key_handover_test`).
- The lock cannot be turned off; install and revoke ask again (`mandatory_lock_test`).
- Static gates green; the manifest is exactly D-024's list (no location, no notification listener); the hub's
  sandboxed suite green; in the device session, APSIRA installs the next RC (signed by its release script, outside
  any session) from its own shelf over the installed `v0.1.0`.

### M2
- **Never lost:** a backup streamed through the adapter and handed to the hub is listed as a snapshot whose restore,
  decrypted on the device, equals the source byte for byte; an interrupted hand-over leaves the app's backup in place and is retried, never
  half-recorded (`backup_never_lost_test`).
- **Append-only proven:** the hub account cannot forget, prune or overwrite a snapshot (refused by `rest-server`);
  only `apsira-store`'s prune removes snapshots, and only outside the retention policy (`append_only_test`, on a
  scratch repository).
- **The hub reads nothing:** what reaches the store and the archive is ciphertext under the vault key; no hub path
  holds the sync or vault key (`hub_blind_test`).
- Retention (D-008, D-032): on a synthetic year, every snapshot within the last 30 days is kept, then one a week for a
  year, then one a month.
- The new phone in one go, against fakes: keys received, every shelf app reinstalled, each offered its latest snapshot
  and restored through its own path (D-034).
- Archive: an offloaded document reaches `secured` only once a snapshot holds it, and is fetched back identical by
  checksum.
- The "not independent" flag shows while the store is on the system disk.

### M3
- Each source honours its cadence on a fake clock; a failed fetch keeps the previous data and is shown with its
  error; a source's payload validates against its contract before it is offered; the phone collects only at home; a
  source edited on one device is read back by the other (D-033); two instances of one kind are served by the app's
  parameter.

### M4
- The policy function, over generated schedules and kinds: inside quiet hours only breakthroughs interrupt; digests
  collect what they should and nothing twice; with APSIRA missing or not answering within its budget,
  `apsira_notify` posts as before (`policy_fallback_test`).

### M5 — the v1 exit
- The sync core on settings: R10–R14 hold (both kept, badge, the newest shown everywhere, edit beats delete, merge
  suggestions never applied silently); the mailbox stores ciphertext only; a revoked device is refused at the
  mailbox (`sync_core_rules_test`).
- The one full check; the device session; the signed `v1.0.0`.

## After v1.0.0

- **v2** (D-021): the folios adopt sync, phone ↔ tablet (each app's change log, apply path, history screens and
  shared/device-only declarations, in its own adoption lane); pulling from Proton to rebuild the hub's copy.
- **Kept for after v2, unordered** (D-021): Proton upload automated; a photos copy at home; amb811's own data in the
  snapshots; the cross-app overview; the third-party notification inbox; on-device models through the gateway.
- **Anytime, operator:** the backup SSD fitted, encrypted, and mounted at `/var/lib/apsira-data`
  (`10-hub-runbook.md` §11), which clears the "not independent" flag.
- **Elsewhere:** the console (its own planning thread, D-020); real-time sources ruled per app (D-005).
