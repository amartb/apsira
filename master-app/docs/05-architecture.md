# APSIRA — Architecture

Status: **design by the APSIRA PLANNING thread, 2026-10-30** (living document; each slice records its mechanisms as
built). The data is `04-data-model.md`; the wire forms are `contracts/`; threats and keys are `09-security-model.md`;
the hub's installation is `10-hub-runbook.md`. Where this document and a contract (interfaces) or the runbook (host
layout) disagree, they win (D-032).

## 1. Stack (D-023)

| Part | Stack |
|---|---|
| The app (phone, tablet) | Flutter 3.47.7, Drift, Riverpod, go_router, freezed; the `apsira_*` packages at the shared tag |
| The on-device link | Kotlin: a content provider in APSIRA called through `ContentResolver.call` (§4.2) |
| The hub client | Kotlin behind the `HubClient` port, so the device key never leaves the Keystore (D-027) |
| Installs | Kotlin: Android's `PackageInstaller` session API (§4.4) |
| The hub (amb811) | Dart (AOT-compiled executable) under systemd as `apsira`; `apsira_core` and the sync format's shared Dart code |
| The store | restic (client) and `rest-server --append-only` (as `apsira-store`), external binaries pinned by version and checksum |

## 2. Repository layout

`master-app/` in the `apsira` repository (D-001):

```
master-app/                    the Flutter app at the root, as every folio
  lib/app/                     bootstrap, router, theme, l10n, services/ ← the only write path
  lib/core/                    ports (§3)
  lib/domain/                  pure Dart: cadence rules, regime evaluation, retention view, version compare
  lib/data/                    db/ (Drift), hub/ (the channel to the Kotlin hub client), link/ (the channel to Kotlin), install/
  lib/features/                home, pairing, shelf, backups, archive, gateway, regime, devices, settings
  android/…/apsira/            link/ (LinkProvider, CallerCheck), hubclient/ (mutual TLS), installer/, keystore/, scanner/
  hub/                         the Dart hub service (its own pubspec)
    bin/apsira_hub.dart
    lib/{api,pairing,shelf,store,archive,gateway,mailbox,registry}/
  shared/                      a local Dart package used by the app and the hub: the hub protocol's types, the
                               sync envelope codec (Proposed; P0 decides whether it becomes an `apsira_*` package)
  tool/                        codegen, checks, build_apk, the hub's install script
  docs/
```

Layering as every folio (`apsira_tools:layering_lint`): a feature never imports `data/`, another feature or a
plugin; every platform touch is a port with a fake. `hub/` imports `shared/` and `apsira_core` only, never Flutter.

## 3. Ports and packages

### 3.1 APSIRA's own ports (`lib/core/`)

| Port | Adapter | Fake |
|---|---|---|
| `HubClient` — every call to the hub (`contracts/hub-protocol.md`) | Kotlin `MtlsHubClient` (OkHttp with a `KeyManager` over the Keystore key, §5.3; D-027), behind a method channel | in-memory hub |
| `DeviceKeys` — create, use, delete the device key | Kotlin, Android Keystore | software keys |
| `Installer` — install an APK, report the outcome | Kotlin, `PackageInstaller` | records calls |
| `InstalledApps` — version and signing certificate of installed packages | Kotlin, `PackageManager` | table |
| `AppLink` — requests arriving from apps (§4.2) | Kotlin → event channel | scripted calls |
| `QrScanner` — the pairing code, **the only camera use** (D-029) | CameraX preview + an on-device zxing-cpp-family decoder (verified in P1), no file written | fixed code |
| `HomeProbe` — "is the hub reachable now" (D-024) | a mutual-TLS handshake to the paired address | toggle |
| `Clock`, `IdGen` | `apsira_core` | `apsira_core` |
| `BackgroundJobs` | `apsira_jobs` (WorkManager) | `apsira_jobs` |
| `Notifier` | `apsira_notify` | `apsira_notify` |

### 3.2 Packages consumed

`apsira_core`, `apsira_ui`, `apsira_app`, `apsira_l10n`, `apsira_onboarding`, `apsira_db`, `apsira_jobs`,
`apsira_notify`, `apsira_lock`, `apsira_storage` (its `StorageSpace` for the queue), `apsira_exchange` (APSIRA's own
export); dev: `apsira_tools`, `apsira_test`.

### 3.3 Package changes APSIRA needs (D-017; each a `D-APK-nnn` when the apsira lane builds it)

| Package | Change (proposal) | Seam it uses |
|---|---|---|
| `apsira_link` (new) | The client every app uses: resolves APSIRA (`com.apsiralabs.apsira`, `.dev` for dev), checks its certificate against `F_APSIRA` (shipped in the package) on every call, makes the `ContentResolver.call` calls of `contracts/app-link.md`, answers APSIRA's calls on the app's own small provider, maps "not installed / not paired / away from home" to `Failure`s. Pure Dart API over a small Kotlin plugin. Its `example/` app is the consumer each milestone is proven with (D-035). It carries the APSIRA adapter of `apsira_storage`'s `BackupTarget`, mapped as `contracts/app-link.md` §5.1. | new |
| `apsira_storage` | none: APSIRA's adapter of its unchanged `BackupTarget` is in `apsira_link` (D-APK-026) | `BackupTarget` (unchanged interface) |
| `apsira_notify` | A policy check inside the `Notifier` implementation (`contracts/app-link.md` §6): before `show`, it asks `notify_policy` with the channel and `breakthrough` (`none` · `urgent`, the app passing `urgent` for a reminder he marked urgent, D-012); `interrupt` → `show`; `quiet` → a silent companion channel; `hold` → `digest_add`, nothing shown. Any failure or a missed deadline → `show` unchanged. The digest tap reaches the app through `launchResponse()`. | `Notifier`, `NotificationChannelSpec` |
| `apsira_lock` | A mandatory mode: `LockSettings` read through a store that pins `enabled: true`; the settings section hides the switch. | `LockSettingsStore` |
| `apsira_exchange` | none expected | — |

Nothing in this table is duplicated in an app; the packages carry the standard, the app supplies its parts.

## 4. Mechanisms

### 4.1 Pairing and the hub link (D-015, D-029)

1. On the hub, the operator runs `apsira-hub pair`: it makes a one-time code (10 minutes, stored hashed) and shows a QR
   holding the code, the hub's LAN address and port, and the SHA-256 of the hub's certificate
   (`contracts/hub-protocol.md` §2).
2. APSIRA reads it with the camera — the pairing screen is the only place the camera opens (D-029) — generates the
   device key in the Keystore (§5.3) and calls `POST /v1/pair` over TLS pinned to the QR's fingerprint, sending the
   code, a certificate signing request and the device name.
3. The hub checks the code, signs a client certificate for this `device_id` with its device CA (`hub/tls/device-ca.*`,
   made by `apsira-hub init`), records it, and
   returns it. From then on every call is mutual TLS: the device pins the hub's certificate, the hub accepts only
   registered, unrevoked client certificates.
4. **Keys:** the first device makes the sync and vault keys and shows the recovery sheet (`04` §3.10). A later device
   receives both sealed to its device key by an already-paired device (`POST /v1/keys/offer`, `GET /v1/keys/pending`;
   the hub deletes the sealed copy once fetched), or he types them from the sheet.
5. **Revocation:** from another device's Devices screen or `apsira-hub revoke <device>`; the hub refuses the
   certificate at once. A revoked device wipes its `hub` row and key on its next contact attempt.
6. **Home** (D-024): `HomeProbe` succeeds when `GET /v1/hello` completes the handshake. Proton VPN must allow LAN
   connections (`10-hub-runbook.md` §9); without it the probe fails and the banner says the hub is unreachable.

### 4.2 The on-device link (D-016, `contracts/app-link.md`)

- **Transport:** content providers only, called only through `ContentResolver.call`: APSIRA's
  `com.apsiralabs.apsira.link` and each app's `com.apsiralabs.<app>.apsira` (dev builds append `.dev` to the
  application id); byte streams cross as `ParcelFileDescriptor` pipes. No bound service.
- **Trust:** every call runs `CallerCheck` first: `getCallingPackage()` must be a package in APSIRA's table, and
  `PackageManager.hasSigningCertificate(pkg, F_<APP>, CERT_INPUT_SHA256)` must be true. Otherwise `not_authorised`,
  no data, nothing logged beyond the code. Apps check APSIRA the same way against `F_APSIRA`.
- **The fingerprint table** is build-time configuration (`src/prod/…/link/AppFingerprints.kt`), copied from each
  app's `release-signing.md`. Only apps signed with **their own release key** are in it (D-031): VIATICUM, signed with
  the SDK debug key (VIATICUM D-059), is absent until its thread gives it a release key. A release APSIRA never trusts
  a debug certificate. Adding an app is an APSIRA release.
- **Dev builds** talk only to dev builds, by package name, with the relaxed check in dev-flavour source only and a
  release-manifest test proving it absent (KAIROS §2.3, `contracts/app-link.md` §3.3).
- Requests that need the hub (a restore of a shipped backup) answer `away` when it is not reachable; a backup is
  accepted into the queue anywhere and shipped at home.

### 4.3 The hub service (D-014)

One process, `apsira-hub`, as `apsira`, listening on `8443` on the LAN (HTTPS, mutual TLS); `rest-server` as
`apsira-store` on loopback. Units, paths, hardening and restic flags are `10-hub-runbook.md` §8 (D-032):

| Unit | Runs | As |
|---|---|---|
| `apsira-hub.service` | the API (`contracts/hub-protocol.md`) **and its own schedule**: each gateway source at its cadence, the shelf's release check, the daily snapshot of `archive/` and `hub.db`; it catches up after downtime | `apsira` |
| `apsira-store.service` | `rest-server --append-only` on `127.0.0.1:8100` | `apsira-store` |
| `apsira-prune.timer` | the weekly `restic forget … --prune` with D-008's thinning (`10` §8.1) | `apsira-store` |

The API never shells out to arbitrary commands; restic is invoked with a fixed argument list. The service holds no
credential that can delete a snapshot, and no key that can read one: content arrives encrypted (D-028).

### 4.4 Slice 1 — the shelf (D-007)

1. **Scan (hub):** for each `apps` row, `GET /repos/amartb/<app>/releases` with the read-only token; for each
   release, download `<app>-<version>.apk` and its `.sha256` into `hub/shelf/`. Then list the RC bind mount
   `/var/lib/apsira-data/rc/<app>/`: an RC is an APK with `rc` in its version and a `.sha256` beside it; its notes are
   a `.notes.md` sidecar the release script writes, else "no notes" (D-035). Drafts and pre-releases on GitHub are
   ignored. RCs are built and signed by the app's own release script in candidate mode, outside any session; a
   `dev`-flavour APK fails the certificate check and is never offered.
2. **Verify (hub):** SHA-256 of the file against the `.sha256`; then `apksigner verify --print-certs` against the
   app's `cert_sha256`; `versionCode` and package name read from the APK. A failure keeps the row with
   `verify_error`, never offered for install.
3. **Offer (device):** at home, APSIRA syncs `shelf_builds`; the shelf compares with `InstalledApps`.
4. **Install (device):** on his tap (and the lock's re-confirmation, D-018), APSIRA downloads the APK into
   `shelf/`, **re-checks** the SHA-256 and the certificate on the device, then opens a `PackageInstaller` session.
   Android shows its own confirmation; Android itself refuses an update signed by another key. APSIRA records the
   outcome; it never sets `USER_ACTION_NOT_REQUIRED` (no silent update).
5. RCs are labelled by channel; installing an RC over a release is allowed (same key), and the shelf says so.

### 4.5 Slice 2 — backups, restore, archive (D-008–D-010, D-028, D-034)

**Handover.** An app configured for APSIRA writes its backup through the adapter exactly as it writes to a SAF folder
today (the zip or bundle is the app's own). The adapter opens a pipe through the link (`backup_begin`); on
`backup_commit` APSIRA checks the **plain** SHA-256 the app states, then **seals the backup with the vault key** into
`queue/<app>/<run>.ready` and records `backup_runs` (`queued` until shipped).

**Central schedule.** A WorkManager job in APSIRA (inside `backup_schedule`'s window, charging, hub reachable) calls
each `central` app's `backup_now` over the link (`contracts/app-link.md`); the app runs its usual backup into the
adapter. `own` apps are never asked; APSIRA ships whatever they write.

**Upload.** A job drains `.ready` files: `POST /v1/backups/{package}` streams the sealed bytes with
`X-Apsira-Sha256` (of the sealed bytes), `X-Apsira-Name` and `X-Apsira-Made`; the hub verifies that hash and pipes it
into `restic backup --stdin` against the local `rest-server` with tags `app:<key>`,
`device:<id>` (`contracts/hub-protocol.md` §5). On success the queued file is deleted and `snapshot_id` recorded.

**Retention and prune** run only as `apsira-store` (§4.3). The writer cannot `forget`.

**Restore one app** (D-034). The backup screen lists `snapshots` for the app; on a pick (re-confirmed), APSIRA
**offers** it to the app: `restore_offer` on the app's provider with `name`, `snapshot`, `made_utc`, `size` and
`reason` (`user` · `new_device`), answered `accepted`. The app shows its own confirmation, then calls
`restore_open(snapshot)`; APSIRA fetches the sealed bytes (`GET /v1/backups/{package}/{snapshot}`), opens them with
the vault key and returns the **plain** stream; the app restores through **its own** path (`apsira_db`'s restore
swap). The restored data brings back the app's settings, its backup target included.

**New phone in one go** (D-009, D-034): pair, receive the sealed sync and vault keys (or type them from the recovery
sheet, §4.1); APSIRA lists the apps that have snapshots; for each chosen app it installs the latest release from the
shelf (§4.4), waits for the install, then offers that app its latest snapshot as above. Each app's restore still asks its own confirmation; APSIRA walks him
through them in order.

**Archive offload** (D-010, D-028, `contracts/atrium-offload.md`): at home only, with no queue on the phone, ATRIUM
hands a document through the link; APSIRA seals it, with its display name and type inside the seal, and `PUT`s the
sealed bytes to `/v1/archive/{item}` (`X-Apsira-Meta` carries only owner, size, the sealed SHA-256 and `kept_utc`); ATRIUM removes its local bytes only once the hub reports the item `secured` (a snapshot holds
it). Fetch-back is the reverse, on demand, decrypted on the device.

**Not independent.** While `/var/lib/apsira-data` is on the system disk, `GET /v1/status` answers
`store_independent: false` and the backup tile shows it.

### 4.6 Slice 3 — the gateway (D-011, D-030, D-033)

0. **Configuration:** sources are hub configuration (D-033): `GET`/`PUT /v1/config` with a revision, `409` on a
   conflict; ids `kairos.holidays.<region>`, `currency.rates.ecb`, `gtfs.static.<feed>`, several instances of a kind
   allowed; `GET /v1/gateway` lists each with its `kind`, `param` and `state` (`live` · `dark`).
1. **Schedule (hub):** each enabled source has `next_fetch_at` from its cadence: `yearly` (1 October for the next
   year, with a check on 1 April), `daily_workdays` (16:30 CET, after the ECB publishes), `weekly`, and for GTFS also
   30 days before a feed's `feed_end_date`. All Proposed defaults, editable per source.
2. **Fetch (hub):** HTTPS to the source's fixed host list (one per kind; `09` §network), size-capped, timeout-bound;
   the payload is parsed and validated before it is kept (rates as the ECB XML, GTFS as a zip with the required
   files). Rates are delivered as `{"base":"EUR","date":"YYYY-MM-DD","rates":{"<ISO>":"<decimal string>"}}`.
   **Holidays** (D-030): the hub fetches a public holiday dataset (candidate: the OpenHolidays API) and builds the pack
   **in KAIROS's own pack format**, validated against KAIROS's pack schema; the source stays `dark` (answering
   `not_found`) until RELAY's thread accepts it in place of K-094's hand curation (D-036). Invalid → `fetches.error`, the previous
   version stays.
3. **Collect (device):** at home, APSIRA fetches new `data_version`s into `gateway/`.
4. **Deliver (app):** apps **pull**: on open or in their own background job, an app asks `gateway_status` and
   `gateway_open` over the link (`contracts/app-link.md` §7): `gateway_status` takes the `kind` and the app's own
   `param`, which picks the instance (RELAY's region). APSIRA may hint with `gateway_updated`; it never pushes a payload into an app. GTFS is held until
   TRANSIT exists.

### 4.7 Slice 4 — the notification regime (D-012)

- **The question:** the policy check in `apsira_notify` calls `notify_policy` over the link with the channel and
  `breakthrough` (`none` · `urgent`, per call), with a **300 ms** deadline (`contracts/app-link.md` §6.1); the answer
  is `interrupt`, `quiet` or `hold` (with `digest_at`). A missed deadline or any error posts the notification as
  today.
- **The evaluation (APSIRA, pure Dart in `domain/regime/`):**
  1. `breakthrough = urgent` → `interrupt`. Alarms never reach the policy: ASTROLABE's alarm and timer channels are
     native (ASTROLABE D-033). APSIRA's own critical alerts are its own notifications, never held.
  2. Otherwise, the active modes now (schedules ∪ the device's manual switch); the priority row for (app, channel,
     mode), else the row for (app, channel, none), else the default (`interrupt` outside modes, `hold` for the digest
     inside a quiet mode).
- **Digests:** a `hold` answer is followed by `digest_add`, stored in `digest_holds`; at each digest time APSIRA posts
  one notification listing the held entries (title only on the lock screen); tapping an entry launches its app with
  the payload, surfaced by `launchResponse()`. Held entries are dropped when their digest is dismissed (or earlier, if
  the app withdraws one with `digest_withdraw`).
- **Fallback:** APSIRA not installed, not answering in time, or the caller check failing → the notification posts as
  today. The regime can delay a notification, never lose one.
- New channels are recorded in `regime_kinds` on first ask, so the priorities screen lists real channels.

### 4.8 Slice 5 — the sync core (D-013)

- **Capture:** every write to a shared table in `lib/app/services/` appends `sync_log` rows in the same transaction
  (field groups declared in `sync_scope.dart`).
- **Seal and post:** at home, a job seals unsent changes into a batch (`contracts/sync-envelope.md`: encrypted
  with the sync key, R26's recovery) and `PUT`s it to `/v1/mailbox/{batch_id}`.
- **Take and apply:** the job lists batches past its cursor (`GET /v1/mailbox?after=`), opens each, applies its
  changes in one transaction per envelope, idempotently (§2.4 #23); concurrent edits of one field group leave two
  heads (R10, R12); deletes vs edits per R11; unknown schema versions wait (§2.4 #18).
- **Client in v1:** APSIRA's personal settings only (D-033; `04` §1.7); hub configuration never travels through the
  mailbox. The folios adopt the same core in v2 through a package;
  its shape is ruled then.

## 5. Security and privacy

The threats and their answers are `09-security-model.md`; this section is the mechanism.

### 5.1 Android permissions (D-024)

| Permission | For |
|---|---|
| `INTERNET` | the hub only in v1 (tiers 1–2, D-005) |
| `REQUEST_INSTALL_PACKAGES` | the shelf |
| `POST_NOTIFICATIONS` | its own alerts and the digests |
| `USE_BIOMETRIC` | the lock |
| `CAMERA` | the pairing QR only, preview only, nothing written; no other screen opens the camera (D-029) |
| `RECEIVE_BOOT_COMPLETED`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` | WorkManager jobs for uploads and sync |

Not declared: any location permission, `ACCESS_WIFI_STATE`-based home detection, `BIND_NOTIFICATION_LISTENER_SERVICE`,
`QUERY_ALL_PACKAGES` (the `<queries>` element names the Apsira packages only), `READ_EXTERNAL_STORAGE`. The merged
release manifest is checked by `apsira_tools:manifest_check` against `tool/privacy/declared_permissions.txt`.

### 5.2 Network allowlist

A `network_security_config.xml` disallows cleartext; the Kotlin `HubClient` pins the hub's certificate. In v1 the
app opens connections to the paired hub's LAN address only; `hub_allowlist_test` fails any other host in `lib/` and
`android/`. The hub's outbound fetches go only to `api.github.com`, `github.com`'s release-asset hosts, the ECB, the
open holiday dataset's host (D-030) and the National Access Point (exact list in `09`).

### 5.3 Keys

- **Device key:** EC P-256 in the Android Keystore, StrongBox when present, non-exportable, and **usable in the
  background without a fresh authentication** (D-015 addendum), so nightly shipping, queue draining, gateway collection
  and sync run while APSIRA is locked. APSIRA's lock (D-018) gates the screens and the sensitive acts, not the key.
  The TLS client signs through it (Kotlin, D-027).
- **Sync key and vault key:** symmetric, each wrapped by a Keystore key on each device; recovery sheet, sealed hand-over
  to new devices (`04` §3.10, D-028). Never on the hub.
- **Hub secrets:** `/etc/apsira/` (`root:apsira 0750`): the GitHub token, the repository and `rest-server` passwords
  (`10-hub-runbook.md` §6–§7).

### 5.4 Logs

No content in any log: app names and codes yes; file names, notification text, device names, payloads no.
`apsira_core`'s log model with `stackHash` (D-APK-011).
