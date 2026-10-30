# APSIRA — Vision and scope

Status: **written by the APSIRA PLANNING thread, 2026-10-30** (living document)

## 1. What APSIRA is

APSIRA is the **master app** of the Apsira ecosystem (D-001): the one Apsira-branded app that does, for every other
Apsira app, the jobs those apps deliberately leave out — reaching the network, carrying backups home, bringing data
in from the internet, governing their notifications, and (from v2) syncing them between devices. Because APSIRA
carries those jobs through one audited path, every folio keeps its smallest attack surface: no `INTERNET`
permission, no sync of its own, no server.

It has two halves:

1. **The app**, `com.apsiralabs.apsira`, on the Android phone and tablet (D-002, D-004). Its icon is the Apsira
   symbol itself.
2. **The hub**, a small service on **amb811** — the Fedora tower that is both the operator's desk PC and the home
   hub — running under its own accounts, on its own storage area (D-014).

APSIRA starts as **quiet infrastructure with a status screen** (D-003, D-019); a daily hub (a "today" view,
cross-app search, inboxes) grows on top in later versions. It is one of two network-holding Apsira apps; the other,
the console (PC control and the army companion), is a separate app with its own planning (D-020).

## 2. Principles

1. **Need decides the network, not convenience** (D-005). Security work (pairing, backups, restore, the archive,
   the shelf, sync) happens at home only. Planned fetches happen at home only and are done by amb811, never the
   phone. Real-time sources are ruled one at a time when an app needs one, and then go direct over the always-on
   Proton VPN to one pinned host. In v1 the phone's APSIRA talks to exactly one host: the paired hub.
2. **The apps stay standalone.** Every app works with APSIRA missing: backups go to its own folder, notifications
   post as today, gateway data simply does not arrive (D-012, D-016). APSIRA adds; it never becomes a dependency
   an app cannot start without.
3. **Never lose what is kept.** Backups land in an append-only, deduplicating store that the routine writer cannot
   erase; pruning is a separate account's job (D-008, D-014). Sync never discards an edit (D-APK-023, D-013).
4. **The hub never reads content.** Backups and offloaded documents are encrypted on the device with a key the hub
   never holds; the recovery sheet is the fallback (D-028).
5. **One standard, in the packages.** Everything an app needs to talk to APSIRA lives in the `apsira_*` packages
   on their public seams — a new `apsira_link`, an adapter of `BackupTarget`, the policy check in `apsira_notify`
   — never as per-app code (D-017).
6. **Trust is checked on every call.** Device ↔ hub by mutual TLS from a QR pairing at home (D-015); app ↔ APSIRA
   by the KAIROS fingerprint check, each app keeping its own release key (D-016); an app signed with a debug key is
   not trusted (D-031).
7. **Always locked.** APSIRA holds pairing keys, installs apps and restores data, so its lock cannot be turned off,
   and sensitive acts re-confirm (D-018).
8. **No friction for the operator.** He copies the store to Proton from his own login, through a read-only group;
   no second account, no logout (D-008, D-014).
9. **Customisation first.** Gateway sources, cadences, quiet-hours schedules, digest times and the networks whose
   timetables are fetched are his; nothing organisational is seeded.

## 3. Scope

### 3.1 v1: five slices (D-006)

Each slice ends in a signed release so the shelf is usable from the first (D-025): `v0.1.0`–`v0.4.0`, then
`v1.0.0` after slice 5.

| Slice | In v1 |
|---|---|
| 1. Pairing + build shelf | The hub on amb811 (dedicated accounts, the HTTPS endpoint, D-014); QR pairing at home with the camera used for that only (D-029), mutual TLS, keys in the Android Keystore, revocation (D-015); the recovery sheet (D-028); the mandatory lock (D-018); the shelf: releases from private GitHub Releases fetched by the hub, RCs signed by each app's release script and read from amb811's builds folders, clearly marked (D-035), each APK checked by SHA-256 and signing certificate, one-tap updates with the changelog (D-007); only apps with their own release key (D-031) |
| 2. Backup home + archive | Every covered app's backups from phone and tablet through a `BackupTarget` adapter, encrypted on the device (D-028), on the central schedule or the app's own, per app (D-008); the append-only, deduplicating snapshot repository, thinned forever; restore a snapshot per app, offered by APSIRA and performed by the app, and a new phone in one go (D-009, D-034); the archive ATRIUM offloads old kept documents to and fetches them back from (D-010); the system-disk fallback flagged "not independent" until the SSD (D-014) |
| 3. Gateway | Holiday packs in KAIROS's format built from open holiday data (dark until RELAY accepts, D-030), ECB currency rates and GTFS timetables for the networks he picks; sources are hub configuration both devices share (D-033); fetched by amb811 on per-source cadences, collected at home, pulled by the apps over the on-device link (D-011) |
| 4. Notification regime | Quiet hours and focus modes, per-kind priority and digests for Apsira apps, enforced by a policy check in `apsira_notify`; alarms, urgent reminders and APSIRA's critical alerts break through; APSIRA posts the digests (D-012) |
| 5. Sync core | The documented sync format, end-to-end encryption, the mailbox on the hub and the device registry, with APSIRA's own personal settings as the only client (D-013, D-033) |
| Throughout | The status screen: backup health, shelf updates, gateway freshness, an unreachable-hub banner (D-019); English and Spanish (charter §1.7) |

Outside APSIRA's repository but part of v1's delivery: the package work (D-017) in the `apsira` lane, and each
app's adoption in its own repository (D-026). APSIRA's milestones do not wait for adoption: each is proven with
`apsira_link`'s example app (D-035). The asks to other threads are D-036 (`03-roadmap.md`).

### 3.2 After v1, recorded (D-021)

- **v2:** folio sync phone ↔ tablet (each app's change log, written in the same transaction, Proposed; version
  history and conflict screens; the Conflicts list); pulling from Proton to rebuild the hub's copy.
- **Kept for later, unordered:** Proton upload automated; a photos copy at home; amb811's own data in the
  snapshots; the cross-app overview (search and "today", reading the apps' export bundles); the third-party
  notification inbox (history, rules, digests, capture for a future Money); on-device models through the gateway.
- **When their apps are planned:** each real-time source (TRANSIT's live arrivals, PRISM's mail) under D-005's
  third tier; the PC as a sync device when a desktop app shares data with a folio; an ATRIUM tome on the archive.

### 3.3 Out of scope

- Restore drills, phone automation, export import as a feature of its own, accounts (dropped, D-021).
- Reading, dismissing or triaging other apps' notifications in v1; no notification listener (D-012).
- A notification history for Apsira apps (D-012).
- Any free-form command on amb811, SSH, PC health or the army companion: the console's (D-020).
- The phone fetching from the public internet in v1; any way into the house from outside (D-005).
- A device-to-device sync fallback (D-013, Proposed).
- Silent auto-updates and `.dev` builds on the shelf (D-007).
- Applying an app's data: how a backup restores, how gateway data is used, how a synced change applies stay each
  app's own logic.

## 4. Success criteria for v1

### 4.1 APSIRA's criteria (close with `v1.0.0`)

Each is proven on the device with `apsira_link`'s example app as the consumer, where an app is needed (D-035).

1. A new release published on GitHub appears on the shelf at home with its changelog and installs with one tap; an RC
   signed by the release script appears marked; an APK whose checksum or certificate does not match is shown and
   refused.
2. A fresh device pairs at home by QR, receives the keys from the other device or from the recovery sheet, and the
   example app is reinstalled from the shelf and offered its latest snapshot in one flow.
3. The example app's backups reach the hub encrypted on its schedule (central or its own) from both devices for a
   week; the status screen shows each one's last backup and flags an overdue one without his checking.
4. A snapshot restores into the example app through its own restore; the store's history cannot be deleted from the
   hub account and the hub cannot read a backup (proven on the hub, `08`); his own login copies the store to Proton
   without switching users.
5. The hub fetches rates and a picked network's timetable on their cadences, the example app pulls them over the link,
   and the phone's APSIRA talks only to the hub.
6. During a quiet mode the example app's notifications are held and arrive in the digest at its time; one sent as
   urgent interrupts; with APSIRA uninstalled they post as before.
7. A quiet-hours change made on the tablet reaches the phone at the next sync at home.

### 4.2 Ecosystem criteria (close as each app adopts, D-035, D-036)

1. A fresh phone becomes his phone in one go: every covered Apsira app reinstalled from the shelf and restored from
   its latest backup, with nothing kept missing.
2. For a month, every covered app's backup reaches the hub from both devices.
3. RELAY's calendar shows the coming year's holidays (once RELAY accepts D-030) and ASTROLABE's converter has this
   week's rates, neither app having `INTERNET`.
4. During quiet hours no Apsira notification interrupts him except an alarm, a reminder marked urgent or APSIRA's
   critical alert.
5. ATRIUM offloads an old kept document to the archive and fetches it back on demand at home (once ATRIUM takes up
   `contracts/atrium-offload.md`).
6. VIATICUM joins the shelf and the link once it has its own release key (D-031).
