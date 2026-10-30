# APSIRA — Data model

Status: **design by the APSIRA PLANNING thread, 2026-10-30**; each task records its tables as built (living
document). Column lists are the design's minimum; the task that builds a table may add the columns it needs and
records them here.

APSIRA keeps data in two places: the **app's database** on each paired device (phone, tablet; D-004) and the **hub's
area** on amb811 (D-014). The hub never holds another app's content in the clear: backups and offloaded documents
are encrypted **on the device** with the vault key before they leave it (D-028), and the mailbox holds ciphertext only
(D-013, R1–R14). Where this document and a contract or `10-hub-runbook.md` disagree, they win (D-032).

## 1. Principles

1. **Sync-ready rows** (charter §1.4): every table that holds his choices has `id` (UUIDv7 text from `IdGen`),
   `created_at`, `updated_at` (UTC epoch milliseconds from `Clock`) and `deleted_at` (soft delete). Caches and
   transient tables (marked *cache* or *transient*) carry `id` and `updated_at` only and are never backed up.
2. **Shared or device-only** (D-APK-023, `sync-and-storage.md` §2.4 #16): every table is declared one or the other in
   `lib/data/db/sync_scope.dart`; a table without a declaration fails `sync_scope_test`. In v1 only the **shared**
   tables travel, through the sync core (D-013).
3. **Never loses data** (charter §1.5): one writer (`lib/app/services/`), one transaction per action; every schema
   change ships with a Drift migration, a `drift_schemas/` dump and the migration-chain test.
4. **Nothing seeded:** no source, mode, schedule, priority or network is created for him. The gateway's three source
   *kinds* (D-011) are code; the sources he turns on are rows.
5. **No secrets in the database.** The device key lives in the Android Keystore; the sync key and the vault key are
   kept wrapped by a Keystore key (§3.10). The hub's GitHub token and its repository passwords live in `/etc/apsira`
   (`10-hub-runbook.md` §6–§7). The hub keeps **no copy of the sync or vault key** in any form (D-028). The databases
   hold only fingerprints and key aliases.
6. **No content in logs or tables beyond what is needed:** a held digest entry keeps the title and body only until
   its digest is dismissed or the app withdraws it (§3.6).
7. **Hub configuration or personal setting** (D-033): what the hub must act on (gateway sources and cadences, the
   shelf's sources) is **hub configuration** (`GET`/`PUT /v1/config`, `contracts/hub-protocol.md`), sent to the hub over
   mutual TLS and read back by every device, so phone
   and tablet share it from M1. His personal settings (the regime, the per-app backup choices, device names) are the
   **sync core's client** from M5; before M5 they are kept per device.

## 2. Identifiers that cross boundaries

| Name | Form | Where it comes from |
|---|---|---|
| `device_id` | UUIDv7 | made by the device at pairing; the hub's registry key |
| `app_key` | the app's base id, `relay`, `atrium`, … | the fingerprint table (D-016) |
| `snapshot_id` | restic's snapshot id (hex) | the store; shown shortened |
| `archive_id` | SHA-256 of the document's bytes (hex) | content-addressed (D-010) |
| `source_id` | `<kind>.<param>`, stable: `kairos.holidays.<region>`, `currency.rates.ecb`, `gtfs.static.<feed>` | a gateway source he turned on (D-033; `contracts/hub-protocol.md` §7) |
| `change_id` | UUIDv7 | the sync core's change log (`contracts/sync-envelope.md`) |

## 3. The app's database (phone and tablet)

`apsira.db`, opened by `apsira_db`'s opener with its pre-migration snapshot and safe mode (D-APK-018).

### 3.1 Pairing and the hub — *device-only*

| Table | Columns (beyond §1.1) | Notes |
|---|---|---|
| `hub` | `lan_address`, `port`, `hub_cert_sha256`, `paired_at`, `key_alias`, `state` (`paired` · `revoked`) | One live row. `key_alias` names the Keystore entry (D-015). |
| `devices` | `device_id`, `name`, `kind` (`phone` · `tablet`), `is_self`, `paired_at`, `revoked_at` | The registry as last read from the hub; this device's row has `is_self`. *Cache* of the hub's registry, except `is_self`. |
| `hub_contact` | `last_reached_at`, `last_error` | *Transient*; feeds the banner (D-019). |

### 3.2 The shelf — *device-only* (D-007)

| Table | Columns | Notes |
|---|---|---|
| `shelf_apps` | `app_key`, `package_name`, `display_name`, `cert_sha256` | *Cache* of the hub's catalogue; the fingerprint is the hub's copy of D-016's table. |
| `shelf_builds` | `app_key`, `version`, `version_code`, `channel` (`release` · `rc`), `apk_sha256`, `size_bytes`, `notes_md`, `published_at`, `verified` (bool), `verify_error` | *Cache*. One row per build the hub offers; `verified` is the hub's double check (§4.4). |
| `shelf_installs` | `app_key`, `installed_version_code`, `installed_from` (`shelf` · `other`), `installed_at` | Read from `PackageManager` at each open; never trusted for verification. *Cache*. |

### 3.3 Backups — choices *personal*, history *cache* (D-008, D-009, D-033)

| Table | Columns | Notes |
|---|---|---|
| `backup_apps` | `app_key`, `mode` (`central` · `own`), `enabled` | **Shared** (personal setting): the sync core carries it from M5; per device before. Created when an app first hands a backup over. |
| `backup_schedule` | `window_start` (local `HH:MM`), `window_end`, `requires_charging`, `requires_home` (always true, D-005) | **Shared** (personal setting), one row: the central schedule. |
| `backup_runs` | `app_key`, `device_id`, `started_at`, `finished_at`, `outcome` (`ok` · `failed` · `queued`), `failure_code`, `bytes`, `snapshot_id` | **Device-only**. A backup made away from home waits as `queued` in APSIRA's queue (§3.8, `contracts/app-link.md` §5.2) until the hub is reached. |
| `snapshots` | `app_key`, `device_id`, `snapshot_id`, `taken_at`, `bytes` | *Cache* of the store's list, refreshed on the backup screens. |

### 3.4 The archive — *cache* (D-010)

| Table | Columns | Notes |
|---|---|---|
| `archive_items` | `archive_id`, `app_key` (`atrium`), `name`, `mime`, `bytes`, `state` (`stored` · `secured`), `offloaded_at`, `fetched_back_at` | Index of what the hub's archive holds, for the archive screen; names are decrypted on the device, never stored on the hub in the clear. ATRIUM keeps its own record of what it offloaded (`contracts/atrium-offload.md`). |

### 3.5 The gateway — sources *hub configuration*, data *device-only* (D-011, D-033)

| Table | Columns | Notes |
|---|---|---|
| `gateway_sources` | `source_id`, `kind` (`kairos.holidays` · `currency.rates` · `gtfs.static`), `param` (region, `ecb`, the feed picked from the National Access Point), `cadence` (`yearly` · `half_yearly` · `daily_workdays` · `weekly` · `custom`), `custom_days`, `enabled`, `state` (`live` · `dark`; holidays stay `dark` until RELAY agrees, D-030) | *Cache* of the **hub configuration** (`config_revision` kept beside it): edits are `PUT /v1/config` with the revision read, a `409` re-reads and re-applies, so both devices see the same rows (`contracts/hub-protocol.md`), so both devices see the same rows. Nothing seeded. Several instances of one kind may exist (two holiday regions); an app asks for a kind with its own parameter, and that picks the instance. |
| `gateway_items` | `source_id`, `data_version`, `fetched_at` (on the hub), `collected_at` (by this device), `valid_until`, `sha256`, `bytes`, `file_name` | **Device-only**. The payload file lives in `gateway/<source_id>/<sha256>` (§3.8). |
| `gateway_deliveries` | `source_id`, `app_key`, `data_version`, `delivered_at` | **Device-only**: which app has taken which version (apps pull, §5 of `05`). |
| `gateway_status` | `source_id`, `next_fetch_at`, `last_error`, `last_error_at` | *Cache* of the hub's view, for freshness tiles (D-019). |

### 3.6 The notification regime — rules *personal*, holds *transient* (D-012, D-033)

The rule tables below are **shared** personal settings: the sync core carries them from M5; before M5 each device
keeps its own.

| Table | Columns | Notes |
|---|---|---|
| `regime_modes` | `name`, `kind` (`quiet` · `focus`), `position` | **Shared**. His modes; none seeded. |
| `regime_schedules` | `mode_id`, `days` (ISO weekday set), `start` (`HH:MM`), `end`, `position` | **Shared**. A mode is on while any of its schedules covers now, or while he switches it on by hand (`regime_manual`). |
| `regime_manual` | `mode_id`, `until` (instant or null) | **Device-only**: a manual switch on this device. Proposed: device-only, since he holds one device in hand. |
| `regime_kinds` | `app_key`, `channel_id`, `label` (as the app declares it), `first_seen_at` | *Cache*: the channels each app announced through the policy check. |
| `regime_priorities` | `app_key`, `channel_id`, `mode_id` (null = outside every mode), `level` (`interrupt` · `quiet` · `digest`) | **Shared**. Missing row = `interrupt` outside modes, `digest` inside a quiet mode (Proposed default). |
| `regime_digest_times` | `days`, `time` (`HH:MM`), `position` | **Shared**. |
| `digest_holds` | `held_id`, `app_key`, `channel_id`, `title`, `body`, `payload`, `held_at`, `digest_at` | **Transient**, never backed up, never synced. Rows are deleted when their digest is dismissed or the app withdraws them (`digest_withdraw`, `contracts/app-link.md` §6.2). |

Breakthrough is never a row. Alarms never reach the policy (ASTROLABE's alarm and timer channels are native, ASTROLABE
D-033); a reminder he marked urgent arrives with `breakthrough = urgent` on the call; APSIRA's own critical alerts are
its own notifications (`05` §4.7).

### 3.7 The sync core — *device-only machinery* (D-013)

| Table | Columns | Notes |
|---|---|---|
| `sync_log` | `change_id`, `table_name`, `row_id`, `field_group`, `value_json`, `base_version`, `device_id`, `hlc`, `origin` (`local` · `remote` · `migration`) | Every change to a **shared** table, written in the same transaction as the change (D-013 Proposed). The log and each row's version history are one record (`sync-and-storage.md` §2.3). |
| `sync_heads` | `table_name`, `row_id`, `field_group`, `head_change_ids` (JSON list) | More than one head = an open clash ("2 versions", R12). |
| `sync_cursor` | `device_id`, `last_change_seen` | What this device has taken from each other device's outbox. |
| `sync_tombstones` | `table_name`, `row_id`, `deleted_change_id` | Delete markers, kept indefinitely (§2.4 #8–#9). |

The envelope that carries a batch of `sync_log` rows is `contracts/sync-envelope.md`.

### 3.8 Settings and files

- `settings` — **shared** key/value rows for APSIRA's own personal options (language, theme). The lock row
  (`apsira_lock`'s `LockSettingsStore`) is **device-only** (§2.4 #16) and its `enabled` is ignored: APSIRA is
  always locked (D-018).
- Per-install state (`apsira_app`'s `InstallFlag`): first open, pairing-tour seen. Never backed up.
- Files under the app's private files directory:
  - `queue/<app_key>/<run_id>.part` → `.ready`: a backup waiting for the hub, **already encrypted with the vault
    key** as it is written (temp then rename).
  - `gateway/<source_id>/<sha256>`: collected payloads; superseded versions removed once every consumer took the new.
  - `shelf/<app_key>-<version_code>.apk`: a verified download, deleted after the install or after 7 days.
  - `restore/<snapshot_id>/`: a snapshot being handed to its app, decrypted on the device, deleted afterwards.

### 3.9 Backup and export of APSIRA itself

APSIRA backs up its **shared** tables and `hub` (without key material) to the hub like any app (`app_key` `apsira`),
encrypted with the vault key.
After a reinstall, pairing creates a new device and a new key (§2.4 #24); the shared tables come back through the
sync core or from the latest snapshot. Its export is an `apsira_exchange` envelope of the shared tables.

### 3.10 Keys on the device (D-015, D-028)

| Key | Form | Use |
|---|---|---|
| Device key | EC P-256 in the Android Keystore (StrongBox when present), non-exportable, **usable in the background without a fresh unlock** (D-015 addendum) | Mutual TLS to the hub, through the Kotlin `HubClient` (D-027) |
| Sync key | Symmetric, wrapped by a Keystore key | Seals and opens sync envelopes (`contracts/sync-envelope.md`) |
| Vault key | Symmetric, wrapped by a Keystore key | Encrypts backups and offloaded documents before they leave the device; decrypts restores and fetch-backs (D-028) |

The sync and vault keys are made once, at the first device's setup, and shown once as the **recovery sheet**
(printed, R26) that carries both. A newly paired device receives them **sealed to its device key** by an already-paired
device through the hub (`contracts/hub-protocol.md` §8, `contracts/sync-envelope.md` §6); with no other device left,
he types them from the sheet. Losing both every device and the sheet makes every backup unreadable; that is the cost of
the hub never holding them.

## 4. The hub's area on amb811

The host layout is `10-hub-runbook.md`'s (D-032); this section summarises it.

### 4.1 Accounts and groups (D-014)

| Name | Kind | Owns | Can |
|---|---|---|---|
| `apsira` | system user | `/var/lib/apsira-data/{hub,archive}` | run the hub service; append snapshots through `rest-server`; read the RC bind mounts |
| `apsira-store` | system user | `/var/lib/apsira-data/store` | run `rest-server --append-only` and the prune timer |
| `apsira-read` | group | — | read `store/` and `archive/` (the operator's login, for the manual Proton copy) |
| `apsira-keys` | group | — | read the repository password (`apsira`, `apsira-store`) |

The builds folders need no group: each `~/projects/<app>-builds/` is a **read-only bind mount** under
`/var/lib/apsira-data/rc/<app>`, so `apsira` never traverses the operator's home (`10` §4.3).

### 4.2 Layout

`/var/lib/apsira-data` is on the system disk **until the backup SSD is fitted**, then the SSD is mounted at the same
path, so no configuration changes (`10` §11). Until then `GET /v1/status` answers `store_independent: false`, which
the status screen shows (D-014).

```
/var/lib/apsira-data/
  hub/                     apsira, 0700
    hub.db                 SQLite: device registry, catalogue, gateway configuration and schedule, archive index (§4.3)
    tls/                   the hub's certificate and key; device-ca.{key,crt}, made by `apsira-hub init`
    mailbox/               sealed sync batches (ciphertext only)
    shelf/                 release APKs + .sha256 + notes, downloaded from GitHub
    gateway/<source_id>/<data_version>/   payload + meta.json (fetched_at, sha256, valid_until)
    logs/                  the service's log, no content (§1.6)
  archive/                 apsira, group apsira-read: offloaded documents, ciphertext (vault key, D-028)
  store/                   apsira-store, group apsira-read: the restic repository
  rc/<app>/                read-only bind mounts of ~/projects/<app>-builds/
/etc/apsira/               root:apsira 0750: hub.toml, github-token, restic-password, rest-password, rest.htpasswd

The sync and vault keys pass through the hub only sealed (`POST /v1/keys/offer`) and are deleted once the new device
fetches them; the hub keeps no copy.
```

The hub snapshots `archive/` and `hub/hub.db` into `store/` daily on its own schedule (D-010, `10` §8.1). The operator
copies `store/` and `archive/`, both ciphertext, to Proton (`10` §10).

### 4.3 `hub.db`

| Table | Columns |
|---|---|
| `devices` | `device_id`, `name`, `kind`, `client_cert_sha256`, `paired_at`, `revoked_at`, `last_seen_at` |
| `pairing_codes` | `code_hash`, `expires_at`, `used_at` (one live code at a time, 10 minutes) |
| `apps` | `app_key`, `package_name`, `github_repo`, `cert_sha256` (D-016's table, the hub's copy) |
| `builds` | `app_key`, `version`, `version_code`, `channel`, `apk_sha256`, `source_path`, `verified`, `verify_error`, `found_at` |
| `sources` | the gateway configuration (D-033): `source_id`, `kind`, `params_json`, `cadence`, `enabled`, `next_fetch_at` — the authority both devices read |
| `fetches` | `source_id`, `started_at`, `finished_at`, `outcome`, `data_version`, `error` |
| `archive_index` | `archive_id`, `owner`, `size`, `sha256` (of the sealed bytes), `kept_utc`, `state`, `stored_at`, `released_at` — display name and type travel inside the seal, never in the clear |
| `backup_log` | `app_key`, `device_id`, `snapshot_id`, `received_at`, `bytes` |

Device-supplied names and file names are content: stored, never logged.

## 5. What crosses which boundary

| Data | Device ↔ hub | App ↔ APSIRA |
|---|---|---|
| A backup | encrypted on the device (vault key), streamed to the hub, stored in `store/` | the app's own bundle through the `BackupTarget` adapter |
| A restore | streamed back from a snapshot, decrypted on the device | offered to the app, which restores through its own path (D-034) |
| An offloaded document | up to `archive/`, back on demand | `contracts/atrium-offload.md` |
| Gateway data | collected from `gateway/` | pulled by the app (`contracts/app-link.md`) |
| Gateway configuration | hub configuration, read back by every device (D-033) | — |
| Regime | personal rows through the sync core from M5 | the policy answer only, never the rules |
| Shelf builds | downloaded APK after both checks | — (installed by APSIRA) |
| Sync | sealed envelopes through `mailbox/` | v2 |

The wire forms are `contracts/hub-protocol.md`, `contracts/app-link.md` and `contracts/sync-envelope.md`.
