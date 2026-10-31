# The app link — APSIRA ⇄ Apsira apps on the device

Status: **1.0 draft.** Decisions: D-016 (trust), D-017 (the shared client), D-008 and D-028 (backups),
D-034 (restore), D-011, D-030 and D-033 (gateway), D-012 (notification policy), D-031 (who is trusted). Built in
slices 2–4 (D-006). At `apsira-v0.5.0` the app side's core exists in `apsira_link` (D-APK-026): `hello` with its
version choice (§9), the failures (every §8 code, as `unavailable` or a call error) and the trust core (§3: the
caller's check, the provider's caller check, the §3.3 dev selection; `F_APSIRA` still unset). At `apsira-v0.6.0`
`apsira_link` also carries the backup calls (§5.2), the app-side provider for `backup_now` and `restore_offer`
(§5.3, §5.4; each app declares it) and `ApsiraBackupTarget`, APSIRA's adapter of `apsira_storage`'s `BackupTarget`,
in `apsira_link` (§5.1; D-APK-026's T2 addendum), with the archive calls of `atrium-offload.md` §3. Still planned:
APSIRA itself with its provider, the policy and gateway calls (§6, §7; the policy check on `apsira_link`'s side of a
seam in `apsira_notify`), and each app's adoption. For every interface value here this file wins over `04` and `05` (D-032).

Clarified 2026-10-31 (§3.3): still version 1.0, with no change on the wire or for a peer.
Clarified 2026-10-31 (T2: §5.1 the adapter's home and reading an offer, §5.2 two wire forms): still version 1.0,
additive, with no change for a peer that already reads them so.

This is the contract between APSIRA and every Apsira app on the same phone or tablet: what crosses, how each side
proves who the other is, and how it is versioned. Both sides build to it. The app side is shared code
(`apsira_link`, the APSIRA adapter of `apsira_storage`'s `BackupTarget` (in `apsira_link`), the policy check in
`apsira_notify`; D-017), so an app adopts it through a package tag, not its own code. Every name marked *new* is
still planned: it is not in the packages at `apsira-v0.6.0`.

## 1. Overview

| Aspect | Value |
|---|---|
| Direction | Both ways, narrow. Apps call APSIRA (backups, policy, gateway, offload); APSIRA calls an app only to ask for a backup, to offer a restore, or to hint that gateway data changed. |
| Transport | On-device IPC only: a content provider in APSIRA and a small one in each app, called through `ContentResolver.call`; byte streams cross as `ParcelFileDescriptor` pipes in the returned `Bundle`. No bound service. No socket: a folio has no `INTERNET` (charter §1.2). |
| Trust | Per-call certificate-fingerprint checks both ways, the KAIROS pattern (§3). No permission, no shared key. |
| APSIRA absent | Every app works alone. The client answers `unavailable` and the app behaves as it does today: backups to its own folder, notifications posted unchanged, gateway data absent (§8). |
| Versioning | `MAJOR.MINOR`, negotiated by `hello` (§9). |

## 2. Authorities

| Side | Authority (release) | Authority (dev) |
|---|---|---|
| APSIRA | `com.apsiralabs.apsira.link` | `com.apsiralabs.apsira.dev.link` |
| Each app | `com.apsiralabs.<app>.apsira` | `com.apsiralabs.<app>.dev.apsira` |

Both providers are exported, declare no `permission`, `readPermission` or `writePermission`, set
`grantUriPermissions="false"`, and throw `UnsupportedOperationException` from `query`, `insert`, `update`,
`delete` and `openFile`: `call` is the only entry point, as KAIROS §3.1. Each app declares `<queries>` for
`com.apsiralabs.apsira` (dev: `….apsira.dev`); APSIRA declares `<queries>` for every app in its fingerprint table.

## 3. Trust

### 3.1 The fingerprints

- `F_APSIRA`: the SHA-256 of APSIRA's release certificate, recorded in APSIRA's `release-signing.md` §2 and held by
  `apsira_link` as build-time configuration (unset at `apsira-v0.6.0`). It reaches each app through the package tag
  that carries it.
- The **app table**: APSIRA holds `package → SHA-256` for every Apsira app signed with **its own release key**,
  copied from each app's `release-signing.md` (RELAY, LYCEUM, ATRIUM, ASTROLABE; STYLUS when released). An app
  without a recorded release digest is absent from the table and is refused. **VIATICUM is absent** until its own
  thread gives it a release key (D-031): it signs with the SDK debug key, which every dev build on amb811 shares.
- A release APSIRA **never trusts a debug certificate**, in the table or anywhere else (D-031).
- Fingerprints are public. A changed key on either side makes the link unavailable until the other side's release
  records it (KAIROS K-042). Until `F_APSIRA` is recorded, a release app trusts no APSIRA.

### 3.2 The checks, on every call

**The caller, before calling:** resolve the authority; its package must be exactly the expected one;
`PackageManager.hasSigningCertificate(package, F, CERT_INPUT_SHA256)` must be true; otherwise `unavailable`,
reason `not_trusted`, and nothing is called.

**The provider, on every call:** `getCallingPackage()` must be an expected package (APSIRA: any package in its
table; an app: exactly `com.apsiralabs.apsira`); `hasSigningCertificate` against the recorded digest must be true;
otherwise the call returns `error = not_authorised` and no data. Nothing about a refused caller is logged beyond the
code.

### 3.3 Development builds

As KAIROS §2.3: a dev build talks only to dev builds (`….dev` ↔ `….dev`), the fingerprint check becomes a
package-name check, the relaxed check lives in dev-flavour source only, and a release-manifest test proves it absent.
A release build never answers a dev package and never accepts a debug certificate. APSIRA dev shows "dev link:
unverified" on its status screen.

In the shared package `apsira_link`, which has no flavours, the relaxed check ships in every build and is selected only when the app's own id ends in `.dev` and its merged manifest carries the `com.apsiralabs.apsira_link.DEV_LINK` meta-data, declared in the app's dev source set only; each app's release-manifest test proves the switch absent (D-APK-026).

## 4. Common shape

Every call's `extras` carry `contract` = `apsira.app_link` and `version` = the `MAJOR.MINOR` the caller chose from
`hello`. Every response carries its fields or `error` (§7). Byte payloads cross as a `ParcelFileDescriptor`
(`fd`) the receiver reads or writes to the end; a payload's integrity is a SHA-256 the sender states and the receiver
checks. No call blocks the main thread; every call has a deadline (§7).

| Method (on APSIRA) | `extras` in | Bundle out |
|---|---|---|
| `hello` | — | `versions` (string array), `app_version`, `locked` (bool, whether the UI is locked; calls still work) |

## 5. Backups (D-008, D-009)

### 5.1 The adapter

The app keeps its backup code unchanged; it is given the APSIRA adapter of `BackupTarget` (in `apsira_link`, over
`apsira_storage`'s unchanged port; an app takes it by adopting `apsira_link`) instead of, or beside, its SAF
target. The adapter maps the port:

| `BackupTarget` | Through the link |
|---|---|
| `pickFolder()` | No picker: returns `BackupFolder(uri: 'apsira:<package>', displayName: 'APSIRA')` after a successful `hello`; null when APSIRA is unavailable |
| `hasAccess(folder)` | `hello` succeeds and the app is in APSIRA's table |
| `freeBytes(folder)` | `backup_space` (the queue's free bytes on the device) |
| `write(folder, name, bytes)` | `backup_begin` → write `fd` → `backup_commit` |
| `rename(folder, from, to)` | `backup_rename` within APSIRA's queue (the `.tmp`-then-rename discipline of D-APK-018) |
| `list(folder)` | `backup_list`: the app's backups APSIRA knows, queued and shipped |
| `read(folder, name)` | `restore_open` by `name` → read `fd`; an offered snapshot is read by its name (§5.4) |
| `delete(folder, name)` | `backup_delete`: removes a **queued** copy; a backup already shipped home is not deleted — hub retention governs it (D-008) — and the call succeeds |

So an app's own keep-limit prunes only what is still on the device; the append-only store is never reached by an
app. Failures reach the app as the port's: `storage_full` as a full folder, `not_found` on `rename` and `read` as a
missing file, every other failure as a folder that is gone, so an app falls back as it does today.

### 5.2 Methods on APSIRA

| Method | `extras` in | Bundle out |
|---|---|---|
| `backup_space` | — | `free_bytes` |
| `backup_begin` | `name`, `size` (if known) | `ticket`, `fd` (write end) |
| `backup_commit` | `ticket`, `sha256`, `size` | `state` = `queued` |
| `backup_rename` | `from`, `to` | — or `exists`/`missing` |
| `backup_list` | — | `entries`: name, size, made_utc, state (`queued` · `shipped`), snapshot id when shipped |
| `backup_delete` | `name` | — |
| `restore_open` | `name` or `snapshot` | `fd` (read end), `sha256`, `size`; needs the hub reachable for a shipped backup (`away` otherwise) |

On `backup_commit` APSIRA checks the stated `sha256` (of the app's plain backup), then **seals the backup with the
vault key** (D-028) before it is written to APSIRA's own storage (`queued`); it ships the sealed copy to the hub
when it is home (`hub-protocol.md` §5), so an app's backup completes away from home and never leaves the device in
plain form. `restore_open` opens the seal and streams the plain backup, with its original `sha256`. A queued backup
counts toward a per-app queue cap; when full, the oldest **shipped-or-superseded** copy goes first, never the only
copy of a day.

Two wire forms, as `apsira_link` reads them (clarified 2026-10-31, additive within 1.0; APSIRA's provider writes the
same): `made_utc` is an ISO 8601 UTC string ending in `Z` (`2026-10-31T09:30:00.000Z`), here and in `restore_offer`
(§5.4); `backup_rename`'s outcome is a boolean field set to true, `exists` (the target name is taken) or `missing`
(no backup named `from`), and a reply with neither is a rename done.

### 5.3 The central schedule

For an app on the central schedule (D-008), APSIRA calls the **app's** provider:

| Method (on the app) | `extras` in | Bundle out |
|---|---|---|
| `backup_now` | `reason` = `schedule` | `accepted` (bool): the app enqueued its own backup job through `apsira_jobs`; the bytes arrive through §5.2 |

An app on its own schedule never receives `backup_now`; it backs up as today into the adapter.

### 5.4 Restore offer (D-034)

APSIRA **offers**; the app **performs**:

| Method (on the app) | `extras` in | Bundle out |
|---|---|---|
| `restore_offer` | `name`, `snapshot`, `made_utc`, `size`, `reason` (`user` · `new_device`) | `accepted` (bool): the app will show its own confirmation |

The app shows **its own** restore confirmation; on yes it reads the backup through its `BackupTarget` and restores
through **its own** restore path, exactly as from its own folder. Through `ApsiraBackupTarget` the read is
`read(folder, name)` with the offer's `name`, which is `restore_open` by `name`: a name names one backup (the adapter
refuses a name `backup_list` already holds) and an offer's `name` and `snapshot` are one `backup_list` entry, so
APSIRA opens the offered snapshot. The `snapshot` is shown, not sent; an app holding `apsira_link`'s
`ApsiraBackupLink` may call `restore_open` with `snapshot` instead (clarified 2026-10-31, within 1.0). On no it answers
nothing further. The restored data brings back the app's settings, its backup target included. "New phone in one
go" (D-009) is: pair, receive the sealed keys (`sync-envelope.md` §6), install from the shelf, then one
`restore_offer` (`reason` = `new_device`) per app with its latest snapshot.

## 6. Notification policy (D-012)

### 6.1 The check

Before `Notifier.show`, `apsira_notify` (*new* hook inside the existing `Notifier` implementation) calls:

| Method | `extras` in | Bundle out |
|---|---|---|
| `notify_policy` | `channel_id`, `importance` (`low` · `defaultImportance` · `high`, the channel's), `category` (`reminder` · `event` · none), `breakthrough` (`none` · `urgent`) | `decision`: `interrupt` · `quiet` · `hold`; with `hold`, `digest_at` (UTC) |

- `interrupt`: posted as today.
- `quiet`: posted without sound or vibration (*new*: the package posts it on a silent companion of the channel).
- `hold`: not posted; the package hands it to APSIRA with `digest_add` (§6.2).
- **Breakthrough by construction:** ASTROLABE's alarm and timer channels are native and never pass through
  `apsira_notify` (ASTROLABE D-033), so alarms are never held. `breakthrough = urgent` (a reminder he marked
  urgent) is always answered `interrupt`. APSIRA's own critical alerts are its own notifications.
- **Deadline 300 ms.** No answer, `unavailable`, `busy` or any error ⇒ the package posts as today. The policy never
  makes a notification disappear.

### 6.2 Digests

| Method | `extras` in | Bundle out |
|---|---|---|
| `digest_add` | `channel_id`, `title`, `body`, `payload` (the app's own string), `digest_at` | `held_id` |
| `digest_withdraw` | `held_id` | — (the app cancelled it before the digest) |

APSIRA posts one digest notification per digest time listing the held entries; tapping an entry launches the app with
the extra `apsira.digest.payload`, which `apsira_notify`'s `launchResponse()` surfaces as the app's own payload
(*new*). Held entries are kept only until their digest is dismissed, never logged and never backed up: there is no
notification history (D-012). A digest under a locked app shows its public version (D-APK-021).

## 7. Gateway delivery (D-011, D-030, D-033)

A source has a **kind** and one or more **instances**, each with a stable id `<kind>.<slug>`. An app asks for a kind
with its own parameter; APSIRA answers with the instance that matches.

| Method | `extras` in | Bundle out |
|---|---|---|
| `gateway_status` | `kind`, `param` (optional: the app's own selector, e.g. RELAY's region `es-md`) | `source` (the instance id), `version` (the hub's data version string), `fetched_utc`, `sha256`, `size`, `format`; `not_found` when no instance matches |
| `gateway_open` | `source`, `version` | `fd` (read end) |

| Kind | Instance ids | `param` | Payload | Allowed caller |
|---|---|---|---|---|
| `kairos.holidays` | `kairos.holidays.<region>` (e.g. `kairos.holidays.es-md`) | the region | A pack file in **KAIROS's own pack format**, built by the hub from open holiday data (D-030). **Dark** until RELAY's thread accepts D-030: `not_found` | RELAY |
| `currency.rates` | `currency.rates.ecb` | — | JSON: `{"base":"EUR","date":"YYYY-MM-DD","rates":{"<ISO 4217>":"<decimal string>"}}` | ASTROLABE |
| `gtfs.static` | `gtfs.static.<feed>` (feeds he picks, nothing seeded) | the feed slug | The feed's zip as published | TRANSIT |

An app pulls on its own schedule or on open; APSIRA may call the app's `gateway_updated` (`source`, `version`) as a
hint, which the app may ignore. A caller is served only the kinds its package is allowed (the table above); others
get `not_allowed`.

## 8. Errors

| `error` | Meaning | The app does |
|---|---|---|
| `not_authorised` | §3.2 refused the caller | Treats APSIRA as unavailable |
| `unsupported_version` | No common major (§9) | Unavailable, naming both versions |
| `busy` | APSIRA is migrating or restoring | Retries later; notifications post as today |
| `away` | The call needs the hub and it is not reachable | Shows "at home"; retries later |
| `storage_full` | The device queue cannot take the backup | Reports a backup failure as today |
| `not_found` | Unknown name, snapshot, source or held id | Drops it |
| `not_allowed` | A gateway source the caller is not allowed | — |
| `checksum_mismatch` | A payload's SHA-256 did not match | The write is discarded; retried |

An unknown code is treated as `unavailable`. Deadlines: `notify_policy` 300 ms; other control calls 5 s; streams have
no deadline but end with the sender's stated size.

## 9. Versioning

This is version **1.0**. `version` is `MAJOR.MINOR`: within 1.x, changes are additions only (a method, an extra, an
error code, a source); a reader that ignores unknown extras keeps working. A breaking change is a new major, offered
beside the old one for at least one release of every consumer. Every change is an APSIRA decision and a `D-APK-nnn`
entry for the packages, made before any side builds against it.

## 10. What each side tests

| Side | Tests |
|---|---|
| APSIRA | Provider refuses an unknown package, a wrong certificate, a debug certificate and a dev caller in release (Robolectric); each method's happy path and every error; queue cap; a queued backup is sealed (no plaintext in APSIRA's storage); `backup_delete` never reaches a shipped backup; `notify_policy` answers within budget; gateway kind/param resolution and `not_allowed`; the release manifest holds no relaxed check |
| `apsira_link` / adapters | The adapter against a fake link: every `BackupTarget` method; `unavailable` on every failure mode; policy timeout ⇒ posts; `hold` ⇒ `digest_add`, not posted; `restore_offer` reaches the app's own confirmation |
| Each app (adoption lane) | Its backup and restore still pass through the adapter end to end, including a restore offered by APSIRA; its manifest `<queries>` and provider; nothing posts silently missing when APSIRA is absent |
