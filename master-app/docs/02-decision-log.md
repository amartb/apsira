# APSIRA (the master app) — Decision log

Status: **seeded by the APSIRA PLANNING thread, 2026-10-30** (living document)

Every significant decision is recorded here with its alternatives and consequences, so that later changes are
deliberate rather than accidental.

**Status values**

- **Decided:** chosen by Alejandro during planning (his multiple-choice rulings in the planning thread).
- **Proposed:** a call Claude made while writing the plan, from his rulings and the prior art. Overturnable;
  becomes *Decided* when accepted in review or confirmed by the phase that builds it.
- **Superseded:** replaced by a later entry (kept for history).

To change a decision, add a new entry that supersedes the old one; never silently edit history. Ecosystem
decisions are cited as `D-APK-nnn` (`apsira/docs/decisions.md`); the roadmap rulings as `M1`–`M7`
(`docs/roadmap/master-app.md`) and `R1`–`R14` (`docs/roadmap/sync-and-storage.md`); other apps' as `RELAY D-nnn`,
`RELAY K-nnn` (KAIROS), `ATRIUM D-nnn`, `ASTROLABE D-nnn`, `LYCEUM D-nnn`, `VIATICUM D-nnn`.

---

## Summary

| ID | Decision | Status |
|---|---|---|
| D-001 | APSIRA is the ecosystem's master app (the central app); one of two network-holding Apsira apps; not KEYSTONE | Decided |
| D-002 | Identity: APSIRA, `com.apsiralabs.apsira`, the Apsira symbol unchanged as its icon, a `dev` flavour, its own release key | Decided (key Proposed) |
| D-003 | Character: infrastructure first with a status screen; the hub grows on top in later versions | Decided |
| D-004 | Devices: phone and tablet in v1; amb811 is both the desk PC and the hub | Decided |
| D-005 | The network bar: three tiers (security and planned work at home only; real-time ruled per source) | Decided |
| D-006 | v1 is five slices, in order: pairing + shelf, backup home + archive, gateway, notification regime, sync core | Decided |
| D-007 | The build shelf: releases from private GitHub Releases, RCs from the builds folders, one tap with changelog | Decided (RC source Proposed) |
| D-008 | Backup home: per-app central or own schedule; an encrypted, deduplicating, append-only snapshot repository; thinned forever; Proton copy by hand in v1 | Decided (engine Proposed) |
| D-009 | Restore: a snapshot per app, and a new phone in one go; pulling from Proton in v2 | Decided |
| D-010 | The documents archive: a simple archive on amb811 for ATRIUM to offload to and fetch back from | Decided |
| D-011 | The gateway's v1 sources: KAIROS holidays, currency rates, GTFS timetables; each with its own cadence | Decided (cadences Proposed) |
| D-012 | The notification regime: quiet hours and focus, priority and digests, enforced by a policy check in `apsira_notify` | Decided (digest mechanism Proposed) |
| D-013 | Sync: the core in v1 with APSIRA's own settings as its only client; folios phone ↔ tablet in v2; mailbox only | Decided (mailbox-only and change capture Proposed) |
| D-014 | The hub on amb811: dedicated accounts, a Dart service, the operator reads through a group; system-disk fallback until the SSD | Decided (mechanism Proposed) |
| D-015 | Phone ↔ hub: QR pairing at home, mutual TLS, device keys in the Android Keystore, revocation | Proposed |
| D-016 | App ↔ APSIRA on the device: per-call certificate-fingerprint checks (the KAIROS pattern), not one shared key or `knownSigner` | Proposed |
| D-017 | The client side lives in the shared packages: a new `apsira_link` plus adapters on existing ports | Proposed |
| D-018 | APSIRA is always locked; sensitive acts re-confirm | Decided |
| D-019 | The v1 status screen: backup health, shelf updates, gateway freshness; an unreachable-hub banner | Decided (banner Proposed) |
| D-020 | The console stays a separate app with its own thread; this thread fixes the boundary only | Decided |
| D-021 | Later, and dropped | Decided |
| D-022 | The planning document set | Decided |
| D-023 | Stack: Flutter folio stack plus Kotlin for the on-device link; Dart on the hub | Proposed |
| D-024 | Android permissions, and "home" detected by reaching the hub, not by Wi-Fi name | Proposed |
| D-025 | Releases: 0.x per slice, v1.0.0 at the end of slice 5; the ASTROLABE release model | Proposed |
| D-026 | How the build runs: army units, package work in the apsira lane, app adoption in each app's own lane | Proposed |
| D-027 | The hub client is Kotlin behind a port; a dev APSIRA pairs only with a dev hub | Proposed |
| D-028 | Backups and archived documents are encrypted on the device; the hub never holds the key | Decided |
| D-029 | A camera for pairing only | Decided (decoder Proposed) |
| D-030 | Holidays from open data, built into KAIROS packs; needs RELAY's thread | Decided |
| D-031 | VIATICUM needs its own release key before APSIRA covers it | Decided |
| D-032 | Which document wins: the log; contracts for interfaces; the runbook for the host; 09 for threats | Proposed |
| D-033 | Operational settings are hub configuration; personal settings are the sync core's client | Proposed |
| D-034 | Restore is offered by APSIRA, performed by the app | Proposed |
| D-035 | RCs signed by the operator's script; APSIRA's milestones don't wait for other apps | Proposed |
| D-036 | Cross-app asks for ATRIUM, RELAY, VIATICUM and every folio | Proposed |

---

## D-001 — APSIRA is the ecosystem's master app

- **Status:** Decided (2026-10-30; charter §2 and §4, D-APK-004, D-APK-005, M5).
- **Decision:** APSIRA is "the central app" of the charter: the one Apsira-branded app that ties the roster
  together and the only place sync, centralised backups and network access for the folios live. It is one of
  **two** network-holding Apsira apps (M5); the other is the console (D-020). It is not a KEYSTONE project
  (`keystone = false`), even though its hub runs on amb811 (R9). Its code lives in the `apsira` repository under
  `master-app/` (operator, 2026-10-30), beside the packages it builds on.
- **Rationale:** the folios keep the smallest attack surface (no `INTERNET`, no sync of their own) only if one app
  carries those jobs for all of them, through one audited path.
- **Consequences:** the charter is amended (`charter-amendments.md`): §1.1 for the hub on amb811, §1.2 and
  D-APK-005 for two network-holding apps, §2's class table and §8's roster.

## D-002 — Identity

- **Status:** Decided (2026-10-30); the release key Proposed (as every sibling, `release-signing.md`).
- **Decision:** the app is named **APSIRA**, application id `com.apsiralabs.apsira` (`.dev` for the `dev`
  flavour, "APSIRA dev"). Its icon is the **Apsira symbol itself, unchanged** (charter §3: copied, never
  recoloured, outlined, rotated or stretched); it is the brand's own app, so it draws no sub-mark. It is signed with
  its own release key, created by the operator outside any session.
- **Alternatives:** APSIRA with its own mark; a roster-style name with its own mark. Rejected by the operator.

## D-003 — Character: infrastructure first, the hub staged

- **Status:** Decided (2026-10-30).
- **Decision:** v1 is quiet infrastructure with a status screen opened now and then (D-019). The hub — a "today"
  view, cross-app search, inboxes — grows on top in later versions (D-021).
- **Alternatives:** quiet infrastructure forever; a daily hub from v1.

## D-004 — Devices

- **Status:** Decided (2026-10-30).
- **Decision:** v1 serves the **phone and the tablet**; both pair the same way. **amb811 is both the desk PC and the
  hub**: the Fedora tower where the operator works, where the `*-builds` folders live, and where the hub runs
  (D-014). The PC joins sync only when a desktop app shares data with a folio (D-013).
- **Consequences:** R3's "Fedora PC" and "amb811" are one machine; the design still keeps the hub's address and
  storage a configuration, so a separate hub or a NAS can replace it later (R4, `sync-and-storage.md` §5).

## D-005 — The network bar

- **Status:** Decided (2026-10-30; refines M4 and R1).
- **Decision:** network work is ranked in three tiers:
  1. **Security work** — pairing, sync, backups, restore, the archive, the shelf — happens **at home only**, between
     the device and the hub.
  2. **Planned work** — fetches that are not real-time (holiday packs, currency rates, timetables, release
     downloads) — happens **at home only** and is done **by amb811**, not the phone (D-011). The phone collects
     the results from the hub.
  3. **Real-time needs** (TRANSIT's live arrivals, PRISM's mail) are judged **per source** when the app that needs
     one is planned. The recorded direction: an approved real-time source is fetched **directly by the phone's
     APSIRA over the always-on Proton VPN**, restricted to that source's host with a pinned certificate; nothing
     ever opens a way into the house. No real-time source exists in v1.
- **Context:** the operator has a paid Proton plan and keeps Proton VPN **always on** on the phone, at home too.
- **Consequences:**
  - In tier 1 and 2 the phone's APSIRA talks to one host only: the paired hub on the home network. Proton VPN's
    "allow LAN connections" must be on for that (an operator setting, `10-hub-runbook.md`).
  - Android runs **one VPN at a time**: M4's "self-run VPN later" would collide with an always-on Proton VPN. Kept
    as a recorded tension for the console's and PRISM's planning, not solved here.
  - PRISM's mail through Proton Bridge on amb811 needs a way home, which tier 3's direction does not give; ruled in
    PRISM's planning.
- **Alternatives:** "fetch anywhere" for every source; home only for everything; a per-source switch the operator
  sets. The operator set the bar instead: the need, not convenience, decides.

## D-006 — v1: five slices, in order

- **Status:** Decided (2026-10-30).
- **Decision:** v1 is, in this order:
  1. **Pairing + build shelf** (D-007, D-015): proves the hub, pairing, the lock and installs, and helps the
     operator's own release flow at once.
  2. **Backup home + archive** (D-008–D-010).
  3. **Gateway** (D-011).
  4. **Notification regime** (D-012).
  5. **Sync core** with APSIRA's own settings as its only client (D-013).
- **Alternatives:** backups first; the notification regime first.

## D-007 — The build shelf

- **Status:** Decided (2026-10-30); the RC source Proposed.
- **Decision:**
  - **Releases** come from each app's **private GitHub Releases** (`amartb/<app>`, assets `<app>-<version>.apk` and
    `<app>-<version>.apk.sha256`, as every release script uploads them). amb811 fetches them (tier 2, D-005) with
    a **read-only, fine-grained GitHub token** held by the hub account; the phone never talks to GitHub.
  - **RCs** come from amb811's `~/projects/<app>-builds/` folders (`<app>-v<x.y>-rc-<sha>.apk` with its
    `.sha256`), which the hub reads through a read-only group. They are offered, clearly marked, so device checks
    install from the shelf instead of over `adb`. Development builds (`.dev` flavour) are never offered.
  - Each APK is checked twice before it is offered: its SHA-256 against the `.sha256` file, and its signing
    certificate against that app's recorded release fingerprint (D-016's table). A mismatch is shown, never
    installed.
  - Updates are **one tap per app, with the changelog** (the release's notes; the app's `CHANGELOG.md` section for
    an RC). No silent auto-update.
- **Rationale:** the operator, 2026-10-30: the builds folders hold the development builds; official private
  releases are done on GitHub. RCs stay on the shelf because the operator chose "releases + RCs" and an RC exists
  only in the builds folder.
- **Alternatives:** releases only; everything including dev builds; silent auto-update; per-app choice.

## D-008 — Backup home

- **Status:** Decided (2026-10-30); the engine and the account split Proposed.
- **Decision:**
  - **What:** every Apsira app's backups from the phone and the tablet, and the documents archive (D-010).
  - **When:** per app, either **the central schedule** (APSIRA asks the app for a backup, by default nightly at
    home while charging) **or the app's own schedule** (APSIRA ships whatever the app writes). Every app keeps its
    manual "back up now".
  - **How it reaches APSIRA:** a `BackupTarget` adapter (`apsira_storage`'s port, unchanged) that hands the app's
    backup stream to APSIRA over the on-device link (D-016, D-017). An app needs no new backup code.
  - **The store:** an **encrypted, deduplicating, append-only snapshot repository** on amb811. *Proposed engine:*
    restic, served by `rest-server --append-only` under a store account the hub service cannot impersonate (D-014),
    so the routine writer can add snapshots but never delete them.
  - **Retention, thinned forever:** every snapshot for 30 days, one a week for a year, one a month forever. Pruning
    is a separate scheduled step run by the store account only.
  - **Offsite in v1:** the operator copies the repository folder (ciphertext) to Proton Drive himself, from his own
    login, which reads the store through a read-only group (D-014). No logout, no second account.
- **Alternatives:** plain dated folders of zips; both; keep everything forever; retention per app; APSIRA uploading
  to Proton in v1.

## D-009 — Restore

- **Status:** Decided (2026-10-30).
- **Decision:** v1 offers (1) **a snapshot per app**: browse an app's history on the hub, pick a date, hand it to
  that app's own restore; (2) **a new phone in one go**: install APSIRA, pair at home, and it reinstalls every Apsira
  app from the shelf and restores each one's latest backup. **Pulling from Proton** (rebuilding the hub's copy if
  amb811 is lost) is v2.
- **Dropped:** restore drills (D-021).

## D-010 — The documents archive

- **Status:** Decided (2026-10-30).
- **Decision:** v1 builds a **simple archive on the hub** whose one job is **offload**: ATRIUM can move old kept
  documents to the archive, remove them from the phone, and fetch any of them back on demand at home. The archive is
  part of the backup snapshots. A future **ATRIUM tome** (desktop) builds on the same archive for PC-born documents
  and reading at the desk.
- **Rationale:** ATRIUM already backs up every kept and standing document (ATRIUM D-022), so a second copy is not a
  job; freeing the phone is. The operator, 2026-10-30: "PC-born docs and readable on the PC sound like jobs for a
  future Atrium Tome… first build a simple archive".
- **Consequences:** offloaded documents live only on the hub, its snapshots and the operator's manual Proton copy
  until Proton upload is automated (D-021). ATRIUM needs an offload contract; it is one of the "central-app hooks"
  ATRIUM D-040 left unnamed, written in `contracts/atrium-offload.md` for ATRIUM's thread to take up.

## D-011 — The gateway's v1 sources

- **Status:** Decided (2026-10-30); the cadences and the rate source Proposed.
- **Decision:** amb811 fetches on a schedule, the phone collects at home, and the app receives the data over the
  on-device link (D-016). v1's sources:
  - **KAIROS holiday packs** for RELAY's calendar (RELAY K-046: "a pack file plus a bundled baseline"; the
    fetcher K-046 kept the door open for). Cadence: **yearly**, after the coming year's calendars are published,
    with a re-check six months later.
  - **Currency rates** for ASTROLABE's converter (ASTROLABE D-017). Source: the ECB's euro reference rates.
    Cadence: daily on working days.
  - **GTFS static timetables** from Spain's National Access Point, for the networks he picks (nothing seeded), ahead
    of TRANSIT. Cadence: weekly check, and before a feed's validity ends.
  Each cadence is a setting per source (the operator, 2026-10-30: periodicity follows how often the data changes).
- **Alternatives:** the phone fetching on home Wi-Fi; both; on-device models in v1 (kept for later, D-021).

## D-012 — The notification regime

- **Status:** Decided (2026-10-30); the digest mechanism Proposed.
- **Decision:**
  - For **Apsira apps**, APSIRA holds one regime: **quiet hours and focus modes** (schedules every Apsira app obeys)
    and **priority and digests** (each app's notification kinds set to interrupt, quiet, or batch into a digest at
    set times).
  - **Enforcement is a policy check**: apps keep posting through `apsira_notify`, which first asks APSIRA's policy
    over the on-device link. Without APSIRA installed, apps behave as today.
  - **Breaking through quiet hours:** alarms he sets (ASTROLABE), reminders he marks urgent, and APSIRA's own
    critical alerts (a backup failing for days, the store nearly full).
  - *Proposed:* a notification held for a digest is handed to APSIRA, which posts one digest notification per
    digest time; tapping an entry opens its app. Held items are transient: there is **no notification history**.
  - **Non-Apsira apps:** nothing in v1. No notification listener, so APSIRA holds no permission to read other apps'
    notifications.
- **Rationale:** the operator: notifications are "not just reading, it is also enforcing that notification regime
  for all apsira apps". Android lets no app change or block another app's notifications, so enforcement lives
  where Apsira apps post: the shared package.
- **Alternatives:** APSIRA posting every Apsira notification (every app would depend on it); settings pushed into
  each app (no live arbitration); a single history; uniform shape checks.

## D-013 — Sync

- **Status:** Decided (2026-10-30); mailbox-only and the change capture Proposed.
- **Decision:**
  - D-APK-023 and R1–R14 stand unchanged: home-network only, a transport-agnostic change log carried by APSIRA,
    per-field additive merge, no edit ever discarded, no CRDT.
  - **v1 builds the sync core** — the documented format, end-to-end encryption, the mailbox on the hub, the device
    registry — with **APSIRA's own settings** (regime, schedules, sources) as its **only client**.
  - **v2:** the folios adopt it, **phone ↔ tablet**. The PC joins when a desktop app shares data with a folio.
  - *Proposed:* **mailbox only**; no device-to-device fallback (the hub is always on at home; R1 makes the fallback
    buy little). *Proposed for v2:* each app writes its change log in the **same transaction** as the change.
- **Rationale:** the operator asked to bring sync back into v1; the costly part of sync is in every app, the core is
  cheap and rides on v1's hub and pairing. Settings are the smallest client and remove a stopgap that v2 would throw
  away.
- **Alternatives:** core plus one pilot folio; full sync in v1; no sync in v1 with settings held on the hub.

## D-014 — The hub on amb811

- **Status:** Decided (2026-10-30: a dedicated account, no friction for the Proton copy; no preference on the
  rest); the mechanism Proposed.
- **Decision:**
  - The hub runs as a **dedicated system account `apsira`** with its own systemd service: the HTTPS endpoint the
    devices talk to (D-015), the shelf's fetcher, the gateway's fetcher, the archive and the sync mailbox.
  - The snapshot repository belongs to a second account, **`apsira-store`**, which runs the append-only
    `rest-server` and the pruning timer. `apsira` can add snapshots, never remove them.
  - The operator's login is in a read-only group **`apsira-read`** over the store and the archive (for the manual
    Proton copy); the hub account is in a read-only group over `~/projects/*-builds/` (for RCs). Neither account
    can reach the operator's home or KEYSTONE.
  - The hub service is written in **Dart**, so it shares `apsira_core` and the sync format's implementation.
  - **Until the backup SSD is bought** (not yet, 2026-10-30) the hub's area is a folder on the system disk, and the
    status screen flags backups as **not independent** of the system disk. Moving to the SSD is a runbook step.
- **Consequences:** charter §1.1 is reworded: Apsira keeps its own area on amb811, independent of KEYSTONE
  (`charter-amendments.md`). `10-hub-runbook.md` holds the accounts, groups, paths, ports and firewall.
- **Alternatives:** a user service under the operator's login; a rootless container.

## D-015 — Phone ↔ hub: pairing and the link

- **Status:** Proposed.
- **Decision:** a device pairs **at home** by scanning a **QR code** the hub shows (a one-time code, the hub's
  certificate fingerprint, its LAN address). Each device then holds its own key pair in the **Android Keystore**
  (hardware-backed, unlockable only behind APSIRA's lock), and every connection is **mutual TLS** pinned to the
  hub's certificate. A device is **revoked** from another paired device or on the hub; the hub refuses it from then
  on. The sync key's recovery copy follows R26 (printed, or kept in Proton).

## D-016 — App ↔ APSIRA on the device

- **Status:** Proposed (resolves `sync-and-storage.md` §4 Q1 and §2.6).
- **Decision:** Apsira apps reach APSIRA through Android IPC (a bound service and a content provider, since a folio
  without `INTERNET` cannot open even a localhost socket). Trust is the **KAIROS pattern** (RELAY
  `docs/kairos/05-link-contract.md` §2; ATRIUM D-055): on **every** call each side checks the caller's package name
  and `hasSigningCertificate` against a **recorded SHA-256 fingerprint**. APSIRA holds a table of every Apsira app's
  release fingerprint (already recorded in each app's `release-signing.md`); each app holds APSIRA's. Every app
  keeps its own key.
- **Alternatives:** one signing key for every app (rewrites every release and puts all apps behind one secret);
  a `knownSigner` permission (dropped by ATRIUM D-055: the KAIROS check is the ecosystem's tested pattern).
- **Consequences:** `contracts/app-link.md` is the contract. A dev build is trusted only by dev builds, as KAIROS §2.3.

## D-017 — The client side lives in the shared packages

- **Status:** Proposed (each piece becomes a `D-APK-nnn` entry when the apsira lane builds it).
- **Decision:** what every app needs to talk to APSIRA is shared code, never per-app code:
  - a new package **`apsira_link`**: the client of the on-device link (the fingerprint check, the calls, APSIRA
    missing handled as "unavailable");
  - an **APSIRA adapter of `BackupTarget`** in `apsira_link`, over `apsira_storage`'s unchanged port (D-008;
    D-APK-026 T2 addendum);
  - the **policy check in `apsira_notify`**'s `Notifier` (D-012; on `apsira_link`'s side, `apsira_notify` gaining no
    dependency on it);
  - gateway delivery as `apsira_link` calls (D-011);
  - a **mandatory mode** in `apsira_lock` for APSIRA (D-018).
  The packages carry the standard; nothing is duplicated in an app (the operator's rule: add-on on the public
  seams, never a duplicate).
- **Consequences:** a new shared tag; each app adopts it in an adoption lane in its own repository (D-APK-009).

## D-018 — APSIRA is always locked

- **Status:** Decided (2026-10-30).
- **Decision:** biometric or PIN on every open, and a fresh confirmation for installing, restoring, pairing and
  revoking. Unlike the other apps the lock cannot be turned off. Built on `apsira_lock` with a mandatory mode
  (D-017).

## D-019 — The v1 status screen

- **Status:** Decided (2026-10-30); the banner Proposed.
- **Decision:** at a glance: **backup health** (per app: last backup home, central or own schedule, overdue),
  **shelf updates** (apps with a newer build, changelog peek) and **gateway freshness** (per source: data age, next
  fetch, last error). *Proposed:* when the hub cannot be reached, a banner says so, since every tile depends on it;
  disk space and the regime's current mode are not tiles.

## D-020 — The console's boundary

- **Status:** Decided (2026-10-30; M1–M5, M7).
- **Decision:** the console (PC control of amb811 and amb8, the army companion) is a separate app with its own
  planning thread after APSIRA. This thread fixes only the boundary. **Shared:** the signing practice, the
  fingerprint pattern (D-016), the `apsira_*` packages. **Never shared:** keys, stores, the hub's accounts. The
  console reaches amb811 through its own restricted SSH account with a forced-command allowlist (M2), never through
  APSIRA's hub, and APSIRA never runs commands on amb811.

## D-021 — Later, and dropped

- **Status:** Decided (2026-10-30).
- **v2:** folio sync phone ↔ tablet (D-013); pulling from Proton (D-009).
- **Kept for after v2 (unordered):** Proton upload automated; a photos copy at home (the route, R7, ruled then);
  amb811's own data in the snapshots; the cross-app overview (one search and a "today" view, reading the apps'
  `apsira_exchange` bundles); the third-party notification inbox (history, rules, digests, capture for a future
  Money); on-device models through the gateway.
- **Dropped:** restore drills; phone automation; export import as a feature of its own (the overview reads the
  bundles); accounts (LYCEUM D-018's "only if ever needed" never arose).

## D-022 — The planning document set

- **Status:** Decided (2026-10-30).
- **Decision:** the sibling set (`00`–`08`, agent rules, dependencies, building, release signing, `CLAUDE.md`)
  plus `09-security-model.md`, `10-hub-runbook.md`, `contracts/` (the app link, the hub protocol, the sync
  envelope, the ATRIUM offload) and `charter-amendments.md`.

## D-023 — Stack

- **Status:** Proposed.
- **Decision:** the app is a folio-shaped Flutter app on the standard stack (Drift, Riverpod, go_router, freezed,
  the `apsira_*` packages), with Kotlin for the bound service, the content provider and the package installer. The
  hub is a Dart program (D-014) with restic and `rest-server` as external binaries.

## D-024 — Android permissions; "home" by reaching the hub

- **Status:** Proposed.
- **Decision:** APSIRA declares `INTERNET`, `REQUEST_INSTALL_PACKAGES`, `POST_NOTIFICATIONS`, the
  biometric permission and the background-work permissions its jobs need; the exact list is `05` §security and is
  checked by `apsira_tools:manifest_check`. It declares **no location permission** and no notification listener.
  APSIRA is "at home" when the paired hub answers a mutual-TLS handshake at its LAN address, not by reading the
  Wi-Fi name (which would need location).

## D-025 — Releases

- **Status:** Proposed.
- **Decision:** each slice ends in a signed release so the shelf is usable from slice 1: `v0.1.0` … `v0.4.0`, and
  **`v1.0.0` after slice 5**. Releases follow the ASTROLABE model: one `~/projects/apsira-builds/v<N>-release.sh`
  style script, the password pasted once, idempotent steps, a private GitHub Release, no phone in any release step.
  Fixes go to the newest open release and a new RC.

## D-026 — How the build runs

- **Status:** Proposed.
- **Decision:** the build runs as army units, one slice per unit, with the master app's own lane. Package work
  (D-017) runs in the existing `apsira` lane under `docs/agent-rules.md` and lands as one shared tag before the slice
  that needs it. Each app's adoption runs in that app's own repository, branch and ledger (D-APK-009). Whether
  `master-app/` gets its own `.army.toml` or a lane in the repository's is settled in P0.

## D-027 — The hub client and development pairing

- **Status:** Proposed (2026-10-30, from writing `05` and `dependencies.md`).
- **Decision:** the device's HTTPS client to the hub is **Kotlin behind a `HubClient` port**, because `dart:io`
  cannot use a key that never leaves the Android Keystore. A **dev APSIRA pairs only with a dev hub**: during
  development the hub runs as the session user on a scratch area and the dev port `10-hub-runbook.md` names; it never
  touches the real accounts, store or firewall (`agent-rules.md`).

---

## Addenda (2026-10-30, from writing the set)

All Proposed; each refines the entry it names.

- **D-008 —** an app's delete or keep-limit prune removes only copies still queued on the device; once shipped, the
  hub's retention governs (`contracts/app-link.md`).
- **D-010 —** offload is **home only**, with no queue on the phone, so an offload never doubles the phone's
  storage. Whether standing and vault-guarded items may be offloaded is ATRIUM's thread's ruling
  (`contracts/atrium-offload.md` §6.2).
- **D-011 —** default cadences: holiday packs on 1 October with a re-check on 1 April; rates at 16:30 CET on working
  days; a GTFS feed checked weekly and 30 days before its validity ends (`05` §4.6). The holiday packs' upstream
  source is verified in slice 3 (`dependencies.md` §2).
- **D-012 —** the "urgent" mark is a field in `apsira_notify` (`breakthrough` on the channel or notification,
  `05` §3.3); each app's control for it lands in its adoption lane. With no priority row set, a kind **interrupts
  outside a quiet mode and goes to the digest inside one**. The manual mode switch is device-only (`04` §3.6).
- **D-014 —** the hub's data root is **`/var/lib/apsira-data`** (`/srv` holds KEYSTONE's directories); the SSD
  mounts there later. RCs are reached through **read-only bind mounts** under `/var/lib/apsira-data/rc/<app>`, not a
  group over the `0700` home. The device port is **8443, LAN-only** (a rich rule on the active zone);
  `rest-server` listens on `127.0.0.1:8100`. The hub schedules its own fetches from its synced settings; the one
  systemd timer is `apsira-prune` (as `apsira-store`). The probe found **amb811's system disk is not LUKS-encrypted**,
  contrary to `sync-and-storage.md` §3.2 (`09` §5.8).
- **D-013 —** the sync key reaches a new device sealed through the hub; attachment names hide the plain hash from
  the hub; each app declares a sync manifest (`contracts/sync-envelope.md`).
- **D-015 —** the device key is usable **in the background without a fresh unlock**, so nightly shipping works while
  APSIRA is locked; APSIRA's lock (D-018) gates the screens and the sensitive acts, not the background jobs. This
  replaces D-015's "unlockable only behind APSIRA's lock". The hub keeps its own device CA and a pairing command;
  amb811 gets a DHCP reservation (`contracts/hub-protocol.md`, `10` runbook).
- **D-017 —** the package work lands as three shared tags, before M1, M2 and M3–M4 (`03`, `07`). `master-app/shared/`
  is a local Dart package used by the app and the hub; P0 decides whether it becomes an `apsira_*` package. New
  package APIs are named in `contracts/app-link.md` (a silent companion channel for "quiet", the digest tap through
  `launchResponse()`, `F_APSIRA` shipped in `apsira_link`).
- **D-018 —** APSIRA's lock timeout choices are 0, 1 or 5 minutes, default 1 (`06` §3.1).
- **D-025 —** each milestone ends in an RC, one bundled device session on it, then the signed release (`03`, `08`).

---

## D-028 — Backups and archived documents are encrypted on the device

- **Status:** Decided (2026-10-30, the builder-check round).
- **Decision:** every backup and every offloaded document is **encrypted on the phone or tablet** with a key the hub
  never holds (the **vault key**), before it leaves the device. restic still stores and thins the snapshots
  (D-008); the archive (D-010) holds ciphertext only. A compromised hub account reveals no content, and the Proton
  copy is ciphertext throughout (R5). The vault key travels with the sync key: sealed to a new device through the
  hub by an already-paired device, or typed from the **printed recovery sheet** that carries both (R26). A future
  ATRIUM tome holds the vault key to read the archive.
- **Alternatives:** encryption on the hub (whoever controls the hub account reads everything); hub encryption with a
  plain archive until the SSD (amb811's system disk is not LUKS-encrypted).
- **Consequences:** the hub keeps **no copy of the sync or vault key** in any form; the recovery sheet is the only
  fallback. Little deduplication is lost: app backups are zips already.

## D-029 — A camera for pairing only

- **Status:** Decided (2026-10-30).
- **Decision:** APSIRA declares `CAMERA` and uses it **only on the pairing screen** to read the hub's QR code: no
  general scanner, nothing saved, no other screen opens the camera. A narrow, recorded exception to "scanning codes
  is ATRIUM's" (ASTROLABE D-012, ATRIUM D-045). *Proposed:* an on-device decoder of the zxing-cpp family, verified in
  P1. Amends D-024's permission list.
- **Alternatives:** a typed code with a fingerprint comparison; ATRIUM scanning and handing over.

## D-030 — Holidays from open data

- **Status:** Decided (2026-10-30); needs RELAY's thread to agree.
- **Decision:** the hub fetches a **public, machine-readable holiday dataset** (candidate: the OpenHolidays API,
  open data covering Spain's regions; verified in slice 3) and builds packs **in KAIROS's own pack format**. It
  replaces RELAY K-094's hand curation from the BOE only when RELAY's thread accepts; until then the gateway's holiday
  source stays dark. Supersedes D-011's "KAIROS pack host" wording.
- **Alternatives:** an operator drop folder (K-094 kept); a drop folder now and open data later.

## D-031 — VIATICUM needs a release key first

- **Status:** Decided (2026-10-30).
- **Decision:** an app is in APSIRA's fingerprint table (D-016), and on the shelf (D-007), only when it is signed with
  **its own release key**. VIATICUM signs with the SDK debug key (VIATICUM D-059), which every dev build on amb811
  shares, so it is **left out** until its own thread gives it a release key. A release APSIRA never trusts a debug
  certificate.

## D-032 — Which document wins

- **Status:** Proposed.
- **Decision:** the decision log wins over everything. For **interfaces** (calls, payloads, endpoints, timeouts,
  error codes) the **contracts** win over `04` and `05`; for the **hub's host layout** (accounts, paths, units,
  firewall, restic flags) **`10-hub-runbook.md`** wins; for threats and keys **`09`**. `04` and `05` describe the
  same things and follow them. Retention is D-008's: every snapshot within 30 days, then weekly for a year, then
  monthly.

## D-033 — Settings: what the hub reads, what syncs

- **Status:** Proposed (resolves how the hub acts on settings while sync is end-to-end encrypted).
- **Decision:** **operational settings** the hub must act on — gateway sources and their cadences, the shelf's
  sources — are **hub configuration**, sent over mutual TLS in plain form (they hold no personal content) and read
  back by both devices, so phone and tablet share them from M1. **Personal settings** — the regime, the per-app
  schedule choices, device names — are the sync core's client from M5, end-to-end encrypted; before M5 they are kept
  per device. Gateway sources have stable ids `<kind>.<slug>` (`kairos.holidays.es-md`); an app asks for a kind with
  its own parameter (RELAY's region picks the instance).

## D-034 — Restore is offered by APSIRA, performed by the app

- **Status:** Proposed.
- **Decision:** APSIRA **offers** a restore to an app through the link (`restore_offer`, `contracts/app-link.md`); the
  app shows **its own** confirmation and restores through **its own** restore path. The restored data brings back
  the app's settings, its backup target included. "New phone in one go" is: pair, receive the sealed keys, install
  from the shelf, offer each app its latest snapshot.

## D-035 — RCs are signed by the operator's script; APSIRA does not wait for other apps

- **Status:** Proposed.
- **Decision:**
  - An RC the shelf offers is built and signed by the app's own release script in candidate mode, **outside any
    session** (the ASTROLABE model, `release-signing.md`). The conductor builds only `dev`-flavour APKs, which the
    shelf never offers. The shelf recognises an RC by `rc` in its version and its `.sha256`; its notes come from a
    `.notes.md` sidecar the release script writes, or "no notes".
  - APSIRA's milestones are proven on the device with **`apsira_link`'s example app** as the consumer and do not
    wait for other apps' adoption lanes. The success criteria that need real apps are **ecosystem criteria**, closed
    as each app adopts (`01` §4, `03`).

## D-036 — Cross-app asks

- **Status:** Proposed; each is ruled in that app's own thread.
- **Decision:** APSIRA's plan needs, from other threads: **ATRIUM** — take up `contracts/atrium-offload.md`, and rule
  whether standing and vault-guarded items may be offloaded; **RELAY** — accept D-030's holiday source (amending
  K-094) and add the "urgent" mark to reminders (D-012); **VIATICUM** — a release key (D-031); **every folio** — adopt
  the shared tags in an adoption lane (D-017). `03-roadmap.md` lists them where they fall.

## Addenda (2026-10-30, from the reconciliation passes)

All Proposed.

- **D-016, D-023 —** the on-device link is **`ContentResolver.call` on content providers only; no bound service**.
  Authorities `com.apsiralabs.apsira.link` (APSIRA) and `com.apsiralabs.<app>.apsira` (each app), `.dev` appended
  for dev builds (`contracts/app-link.md`).
- **D-033 —** the source ids are `kairos.holidays.<region>` (for example `kairos.holidays.es-md`),
  `currency.rates.ecb` and `gtfs.static.<feed>`; an app asks by kind and parameter (`contracts/app-link.md` §7).
